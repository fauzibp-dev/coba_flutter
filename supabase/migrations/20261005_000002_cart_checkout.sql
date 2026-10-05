begin;

create or replace function public.add_to_cart(
  p_product_id uuid,
  p_variant_id uuid,
  p_quantity integer default 1
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cart uuid;
  v_stock integer;
  v_existing integer := 0;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_quantity < 1 or p_quantity > 99 then raise exception 'Invalid quantity'; end if;
  if not exists(select 1 from public.products where id=p_product_id and status='active') then
    raise exception 'Product unavailable';
  end if;
  if p_variant_id is not null and not exists(
    select 1 from public.product_variants
    where id=p_variant_id and product_id=p_product_id and is_active
  ) then raise exception 'Variant unavailable'; end if;

  select available_qty into v_stock
  from public.inventory
  where product_id=p_product_id
    and ((p_variant_id is null and variant_id is null) or variant_id=p_variant_id)
  for update;

  if coalesce(v_stock,0) < p_quantity then raise exception 'Stock not enough'; end if;

  insert into public.carts(user_id)
  values(auth.uid())
  on conflict(user_id) do update set updated_at=now()
  returning id into v_cart;

  select quantity into v_existing
  from public.cart_items
  where cart_id=v_cart and product_id=p_product_id
    and ((p_variant_id is null and variant_id is null) or variant_id=p_variant_id)
  for update;

  v_existing := coalesce(v_existing,0);
  if v_existing + p_quantity > 99 or v_existing + p_quantity > coalesce(v_stock,0) then
    raise exception 'Stock not enough';
  end if;

  if p_variant_id is null then
    insert into public.cart_items(cart_id,product_id,variant_id,quantity)
    values(v_cart,p_product_id,null,p_quantity)
    on conflict (cart_id,product_id) where variant_id is null
    do update set quantity=public.cart_items.quantity + excluded.quantity, updated_at=now();
  else
    insert into public.cart_items(cart_id,product_id,variant_id,quantity)
    values(v_cart,p_product_id,p_variant_id,p_quantity)
    on conflict (cart_id,variant_id) where variant_id is not null
    do update set quantity=public.cart_items.quantity + excluded.quantity, updated_at=now();
  end if;
end;
$$;

revoke all on function public.add_to_cart(uuid,uuid,integer) from public, anon;
grant execute on function public.add_to_cart(uuid,uuid,integer) to authenticated;

create or replace function public.set_cart_quantity(p_item_id uuid,p_quantity integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.cart_items%rowtype;
  v_stock integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select ci.* into v_item
  from public.cart_items ci
  join public.carts c on c.id=ci.cart_id
  where ci.id=p_item_id and c.user_id=auth.uid()
  for update of ci;

  if v_item.id is null then raise exception 'Cart item not found'; end if;
  if p_quantity <= 0 then
    delete from public.cart_items where id=v_item.id;
    return;
  end if;
  if p_quantity > 99 then raise exception 'Invalid quantity'; end if;

  select available_qty into v_stock
  from public.inventory
  where product_id=v_item.product_id
    and ((v_item.variant_id is null and variant_id is null) or variant_id=v_item.variant_id)
  for update;

  if coalesce(v_stock,0) < p_quantity then raise exception 'Stock not enough'; end if;
  update public.cart_items set quantity=p_quantity, updated_at=now() where id=v_item.id;
end;
$$;

revoke all on function public.set_cart_quantity(uuid,integer) from public, anon;
grant execute on function public.set_cart_quantity(uuid,integer) to authenticated;

create or replace function public.remove_cart_item(p_item_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  delete from public.cart_items ci
  using public.carts c
  where ci.id=p_item_id and c.id=ci.cart_id and c.user_id=auth.uid();
end;
$$;

revoke all on function public.remove_cart_item(uuid) from public, anon;
grant execute on function public.remove_cart_item(uuid) to authenticated;

drop function if exists public.create_checkout(uuid,text,text,text,text);

create function public.create_checkout(
  p_address_id uuid,
  p_payment_method text,
  p_shipping_method text,
  p_voucher_code text default null,
  p_notes text default null,
  p_client_request_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cart uuid;
  v_store uuid;
  v_order uuid;
  v_existing uuid;
  v_order_number text;
  v_subtotal numeric(14,2):=0;
  v_discount numeric(14,2):=0;
  v_shipping numeric(14,2):=0;
  v_total numeric(14,2);
  v_address jsonb;
  v_voucher public.vouchers%rowtype;
  v_usage integer;
  r record;
  v_price numeric(14,2);
  v_inventory_id uuid;
  v_available integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_payment_method not in ('cod','manual_transfer') then raise exception 'Unsupported payment method'; end if;
  if p_shipping_method not in ('pickup','local_delivery') then raise exception 'Unsupported shipping method'; end if;

  if p_client_request_id is not null then
    perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text || ':' || p_client_request_id::text,0));
    select id into v_existing from public.orders
    where user_id=auth.uid() and client_request_id=p_client_request_id;
    if v_existing is not null then return v_existing; end if;
  end if;

  select id into v_cart from public.carts where user_id=auth.uid();
  if v_cart is null or not exists(select 1 from public.cart_items where cart_id=v_cart) then
    raise exception 'Cart is empty';
  end if;

  if p_address_id is not null then
    select to_jsonb(a.*) into v_address from public.addresses a
    where a.id=p_address_id and a.user_id=auth.uid();
  end if;
  if p_shipping_method='local_delivery' and v_address is null then
    raise exception 'Delivery address required';
  end if;

  select p.store_id into v_store
  from public.cart_items ci
  join public.products p on p.id=ci.product_id
  where ci.cart_id=v_cart limit 1;
  if v_store is null then raise exception 'Cart store not found'; end if;
  if exists(
    select 1 from public.cart_items ci
    join public.products p on p.id=ci.product_id
    where ci.cart_id=v_cart and p.store_id<>v_store
  ) then raise exception 'Multi-store checkout is not enabled yet'; end if;

  for r in
    select ci.*, p.name product_name, p.sku product_sku, p.price base_price,
           p.status product_status, pv.name variant_name, pv.price_override,
           pv.is_active variant_active
    from public.cart_items ci
    join public.products p on p.id=ci.product_id
    left join public.product_variants pv on pv.id=ci.variant_id
    where ci.cart_id=v_cart
  loop
    if r.product_status<>'active' then raise exception 'A product is unavailable'; end if;
    if r.variant_id is not null and coalesce(r.variant_active,false)=false then
      raise exception 'A variant is unavailable';
    end if;
    select i.id,i.available_qty into v_inventory_id,v_available
    from public.inventory i
    where i.product_id=r.product_id
      and ((r.variant_id is null and i.variant_id is null) or i.variant_id=r.variant_id)
    for update;
    if v_inventory_id is null or v_available < r.quantity then
      raise exception 'Stock not enough for %',r.product_name;
    end if;
    v_price:=coalesce(r.price_override,r.base_price);
    v_subtotal:=v_subtotal+(v_price*r.quantity);
  end loop;

  if p_voucher_code is not null and btrim(p_voucher_code)<>'' then
    select * into v_voucher from public.vouchers
    where store_id=v_store and upper(code)=upper(btrim(p_voucher_code))
      and is_active and starts_at<=now() and (ends_at is null or ends_at>=now())
    limit 1;
    if v_voucher.id is null then raise exception 'Voucher invalid or expired'; end if;
    if v_subtotal < v_voucher.minimum_purchase then raise exception 'Minimum purchase not reached'; end if;
    if v_voucher.usage_limit is not null and
      (select count(*) from public.voucher_usages where voucher_id=v_voucher.id)>=v_voucher.usage_limit then
      raise exception 'Voucher quota exhausted';
    end if;
    select count(*) into v_usage from public.voucher_usages
    where voucher_id=v_voucher.id and user_id=auth.uid();
    if v_usage>=v_voucher.usage_per_user then raise exception 'Voucher usage limit reached'; end if;
    if v_voucher.discount_type='fixed' then
      v_discount:=least(v_subtotal,v_voucher.discount_value);
    else
      v_discount:=v_subtotal*(v_voucher.discount_value/100);
    end if;
    if v_voucher.maximum_discount is not null then
      v_discount:=least(v_discount,v_voucher.maximum_discount);
    end if;
  end if;

  v_shipping:=case when p_shipping_method='pickup' then 0 else 5000 end;
  v_total:=greatest(0,v_subtotal-v_discount+v_shipping);
  v_order_number:='SM-'||to_char(now(),'YYYYMMDD')||'-'||lpad(nextval('public.order_number_seq')::text,6,'0');

  insert into public.orders(
    order_number,user_id,store_id,status,payment_status,payment_method,shipping_method,
    subtotal,discount_amount,shipping_cost,total_amount,voucher_id,address_snapshot,
    customer_notes,client_request_id
  ) values(
    v_order_number,auth.uid(),v_store,'pending_payment','pending',p_payment_method,p_shipping_method,
    v_subtotal,v_discount,v_shipping,v_total,v_voucher.id,v_address,p_notes,p_client_request_id
  ) returning id into v_order;

  for r in
    select ci.*, p.name product_name, p.sku product_sku, p.price base_price,
           pv.name variant_name, pv.price_override
    from public.cart_items ci
    join public.products p on p.id=ci.product_id
    left join public.product_variants pv on pv.id=ci.variant_id
    where ci.cart_id=v_cart
  loop
    v_price:=coalesce(r.price_override,r.base_price);
    insert into public.order_items(
      order_id,product_id,variant_id,product_name,variant_name,sku,unit_price,quantity,subtotal
    ) values(
      v_order,r.product_id,r.variant_id,r.product_name,r.variant_name,r.product_sku,
      v_price,r.quantity,v_price*r.quantity
    );
    update public.inventory
    set available_qty=available_qty-r.quantity,reserved_qty=reserved_qty+r.quantity
    where product_id=r.product_id
      and ((r.variant_id is null and variant_id is null) or variant_id=r.variant_id);
    insert into public.inventory_movements(
      store_id,product_id,variant_id,movement_type,quantity,note,reference_id,actor_id
    ) values(
      v_store,r.product_id,r.variant_id,'reservation',-r.quantity,
      'Checkout reservation',v_order,auth.uid()
    );
  end loop;

  insert into public.payments(order_id,method,status,amount)
  values(v_order,p_payment_method,'pending',v_total);
  insert into public.order_status_history(order_id,status,note,actor_id)
  values(v_order,'pending_payment','Order created',auth.uid());
  if v_voucher.id is not null then
    insert into public.voucher_usages(voucher_id,user_id,order_id,discount_amount)
    values(v_voucher.id,auth.uid(),v_order,v_discount);
  end if;

  delete from public.cart_items where cart_id=v_cart;

  if p_payment_method='cod' then
    update public.orders set status='confirmed' where id=v_order;
    update public.inventory i
    set reserved_qty=greatest(0,i.reserved_qty-oi.quantity)
    from public.order_items oi
    where oi.order_id=v_order and i.product_id=oi.product_id
      and ((oi.variant_id is null and i.variant_id is null) or i.variant_id=oi.variant_id);
    insert into public.inventory_movements(
      store_id,product_id,variant_id,movement_type,quantity,note,reference_id,actor_id
    ) select v_store,product_id,variant_id,'sale',-quantity,'COD order confirmed',v_order,auth.uid()
      from public.order_items where order_id=v_order;
    insert into public.order_status_history(order_id,status,note,actor_id)
    values(v_order,'confirmed','COD order confirmed',auth.uid());
  end if;

  insert into public.notifications(user_id,type,title,body,data)
  values(auth.uid(),'order_created','Pesanan dibuat',
    'Pesanan '||v_order_number||' berhasil dibuat.',
    jsonb_build_object('order_id',v_order,'order_number',v_order_number));

  return v_order;
end;
$$;

revoke all on function public.create_checkout(uuid,text,text,text,text,uuid) from public, anon;
grant execute on function public.create_checkout(uuid,text,text,text,text,uuid) to authenticated;

commit;
