-- Shop Mart v1.1 security/data-integrity hardening.
-- Applied to production as Supabase migration 20261005070659.

alter table public.orders add column if not exists client_request_id uuid;
create unique index if not exists orders_user_client_request_uidx
  on public.orders(user_id, client_request_id)
  where client_request_id is not null;

drop policy if exists orders_staff_update on public.orders;
revoke insert, update, delete on public.orders from authenticated;

drop policy if exists inventory_manage on public.inventory;
revoke insert, update, delete on public.inventory from authenticated;

drop policy if exists cart_items_owner on public.cart_items;
drop policy if exists cart_items_owner_select on public.cart_items;
create policy cart_items_owner_select on public.cart_items
  for select to authenticated
  using (exists (
    select 1 from public.carts c
    where c.id = cart_items.cart_id and c.user_id = (select auth.uid())
  ));
revoke insert, update, delete on public.cart_items from authenticated;

drop policy if exists products_staff_manage on public.products;
revoke insert, update, delete on public.products from authenticated;

drop policy if exists reviews_owner_insert on public.reviews;
create policy reviews_owner_insert on public.reviews
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.order_items oi
      join public.orders o on o.id = oi.order_id
      where oi.id = reviews.order_item_id
        and oi.product_id = reviews.product_id
        and o.user_id = (select auth.uid())
        and o.status = 'completed'
    )
  );

revoke all on function public.claim_initial_owner() from public, anon, authenticated;

create or replace function public.add_to_cart(
  p_product_id uuid,
  p_variant_id uuid,
  p_quantity integer default 1
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cart uuid;
  v_stock int;
  v_existing int := 0;
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
  if v_stock is null then raise exception 'Stock not found'; end if;

  insert into public.carts(user_id)
  values(auth.uid())
  on conflict(user_id) do update set updated_at=now()
  returning id into v_cart;

  select quantity into v_existing
  from public.cart_items
  where cart_id=v_cart and product_id=p_product_id
    and ((p_variant_id is null and variant_id is null) or variant_id=p_variant_id)
  limit 1;
  v_existing := coalesce(v_existing,0);
  if v_existing + p_quantity > v_stock then raise exception 'Stock not enough'; end if;

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

create or replace function public.set_cart_quantity(
  p_item_id uuid,
  p_quantity integer
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.cart_items%rowtype;
  v_stock int;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_quantity < 0 or p_quantity > 99 then raise exception 'Invalid quantity'; end if;

  select ci.* into v_item
  from public.cart_items ci
  join public.carts c on c.id=ci.cart_id
  where ci.id=p_item_id and c.user_id=auth.uid()
  for update of ci;
  if v_item.id is null then raise exception 'Cart item not found'; end if;

  if p_quantity = 0 then
    delete from public.cart_items where id=v_item.id;
    return;
  end if;

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

create or replace function public.save_product_core(
  p_product_id uuid,
  p_name text,
  p_slug text,
  p_description text,
  p_price numeric,
  p_compare_at_price numeric,
  p_category_id uuid,
  p_sku text,
  p_stock integer,
  p_active boolean,
  p_featured boolean,
  p_stock_reason text default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member public.store_members%rowtype;
  v_id uuid;
  v_old_stock int := 0;
  v_inventory uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_name is null or btrim(p_name)='' then raise exception 'Product name required'; end if;
  if p_price <= 0 then raise exception 'Price must be greater than zero'; end if;
  if p_stock < 0 then raise exception 'Invalid stock'; end if;

  select * into v_member from public.store_members
  where user_id=auth.uid() and role in ('owner','admin','staff')
  order by created_at limit 1;
  if v_member.id is null then raise exception 'Not authorized'; end if;
  if p_category_id is not null and not exists(
    select 1 from public.categories where id=p_category_id and store_id=v_member.store_id
  ) then raise exception 'Invalid category'; end if;

  if p_product_id is null then
    insert into public.products(
      store_id,category_id,name,slug,description,price,compare_at_price,sku,status,is_featured
    ) values(
      v_member.store_id,p_category_id,btrim(p_name),p_slug,btrim(coalesce(p_description,'')),p_price,p_compare_at_price,
      nullif(btrim(coalesce(p_sku,'')),''),case when p_active then 'active' else 'draft' end,p_featured
    ) returning id into v_id;

    insert into public.inventory(product_id,available_qty,reserved_qty)
    values(v_id,p_stock,0)
    returning id into v_inventory;

    if p_stock <> 0 then
      insert into public.inventory_movements(store_id,product_id,movement_type,quantity,note,actor_id)
      values(v_member.store_id,v_id,'adjustment',p_stock,coalesce(nullif(btrim(p_stock_reason),''),'Initial stock'),auth.uid());
    end if;
  else
    v_id := p_product_id;
    if not exists(select 1 from public.products where id=v_id and store_id=v_member.store_id) then
      raise exception 'Product not found or not authorized';
    end if;

    update public.products set
      category_id=p_category_id,
      name=btrim(p_name),
      description=btrim(coalesce(p_description,'')),
      price=p_price,
      compare_at_price=p_compare_at_price,
      sku=nullif(btrim(coalesce(p_sku,'')),''),
      status=case when p_active then 'active' else 'draft' end,
      is_featured=p_featured
    where id=v_id;

    select id,available_qty into v_inventory,v_old_stock
    from public.inventory
    where product_id=v_id and variant_id is null
    for update;

    if v_inventory is null then
      insert into public.inventory(product_id,available_qty,reserved_qty)
      values(v_id,p_stock,0) returning id into v_inventory;
      v_old_stock := 0;
    else
      update public.inventory set available_qty=p_stock where id=v_inventory;
    end if;

    if coalesce(v_old_stock,0) <> p_stock then
      if p_stock_reason is null or btrim(p_stock_reason)='' then raise exception 'Stock adjustment reason required'; end if;
      insert into public.inventory_movements(store_id,product_id,movement_type,quantity,note,actor_id)
      values(v_member.store_id,v_id,'adjustment',p_stock-coalesce(v_old_stock,0),btrim(p_stock_reason),auth.uid());
    end if;
  end if;
  return v_id;
end;
$$;
revoke all on function public.save_product_core(uuid,text,text,text,numeric,numeric,uuid,text,integer,boolean,boolean,text) from public, anon;
grant execute on function public.save_product_core(uuid,text,text,text,numeric,numeric,uuid,text,integer,boolean,boolean,text) to authenticated;

create or replace function public.archive_product(p_product_id uuid) returns void
language plpgsql
security definer
set search_path=public
as $$
declare v_store uuid;
begin
  select store_id into v_store from public.products where id=p_product_id;
  if v_store is null or not public.is_store_staff(v_store) then raise exception 'Not authorized'; end if;
  update public.products set status='archived' where id=p_product_id;
  insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
  values(v_store,auth.uid(),'product_archived','product',p_product_id::text,jsonb_build_object('status','archived'));
end;
$$;
revoke all on function public.archive_product(uuid) from public, anon;
grant execute on function public.archive_product(uuid) to authenticated;

drop function if exists public.create_checkout(uuid,text,text,text,text);
create function public.create_checkout(
  p_address_id uuid,
  p_payment_method text,
  p_shipping_method text,
  p_voucher_code text default null,
  p_notes text default null,
  p_client_request_id uuid default null
) returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_cart uuid; v_store uuid; v_order uuid; v_order_number text;
  v_subtotal numeric(14,2):=0; v_discount numeric(14,2):=0; v_shipping numeric(14,2):=0; v_total numeric(14,2);
  v_address jsonb; v_voucher public.vouchers%rowtype; v_usage int; r record;
  v_price numeric(14,2); v_inventory_id uuid; v_available int;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  if p_client_request_id is not null then
    perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text || ':' || p_client_request_id::text, 0));
    select id into v_order from public.orders
    where user_id=auth.uid() and client_request_id=p_client_request_id;
    if v_order is not null then return v_order; end if;
  end if;

  if p_payment_method not in ('cod','manual_transfer') then raise exception 'Unsupported payment method'; end if;
  if p_shipping_method not in ('pickup','local_delivery') then raise exception 'Unsupported shipping method'; end if;
  select id into v_cart from public.carts where user_id=auth.uid();
  if v_cart is null or not exists(select 1 from public.cart_items where cart_id=v_cart) then raise exception 'Cart is empty'; end if;
  select to_jsonb(a.*) into v_address from public.addresses a where a.id=p_address_id and a.user_id=auth.uid();
  if p_shipping_method='local_delivery' and v_address is null then raise exception 'Delivery address required'; end if;

  select p.store_id into v_store
  from public.cart_items ci join public.products p on p.id=ci.product_id
  where ci.cart_id=v_cart limit 1;
  if v_store is null then raise exception 'Cart store not found'; end if;
  if exists(select 1 from public.cart_items ci join public.products p on p.id=ci.product_id where ci.cart_id=v_cart and p.store_id<>v_store) then
    raise exception 'Multi-store checkout is not enabled yet';
  end if;

  for r in
    select ci.*, p.name product_name, p.sku product_sku, p.price base_price, p.status product_status,
           pv.name variant_name, pv.price_override, pv.is_active variant_active
    from public.cart_items ci
    join public.products p on p.id=ci.product_id
    left join public.product_variants pv on pv.id=ci.variant_id
    where ci.cart_id=v_cart
  loop
    if r.product_status<>'active' then raise exception 'A product is unavailable'; end if;
    if r.variant_id is not null and coalesce(r.variant_active,false)=false then raise exception 'A variant is unavailable'; end if;
    select i.id,i.available_qty into v_inventory_id,v_available
    from public.inventory i
    where i.product_id=r.product_id and ((r.variant_id is null and i.variant_id is null) or i.variant_id=r.variant_id)
    for update;
    if v_inventory_id is null or v_available < r.quantity then raise exception 'Stock not enough for %',r.product_name; end if;
    v_price := coalesce(r.price_override,r.base_price);
    v_subtotal := v_subtotal + (v_price*r.quantity);
  end loop;

  if p_voucher_code is not null and btrim(p_voucher_code)<>'' then
    select * into v_voucher from public.vouchers
    where store_id=v_store and upper(code)=upper(btrim(p_voucher_code)) and is_active
      and starts_at<=now() and (ends_at is null or ends_at>=now()) limit 1;
    if v_voucher.id is null then raise exception 'Voucher invalid or expired'; end if;
    if v_subtotal < v_voucher.minimum_purchase then raise exception 'Minimum purchase not reached'; end if;
    if v_voucher.usage_limit is not null and (select count(*) from public.voucher_usages where voucher_id=v_voucher.id)>=v_voucher.usage_limit then raise exception 'Voucher quota exhausted'; end if;
    select count(*) into v_usage from public.voucher_usages where voucher_id=v_voucher.id and user_id=auth.uid();
    if v_usage>=v_voucher.usage_per_user then raise exception 'Voucher usage limit reached'; end if;
    if v_voucher.discount_type='fixed' then v_discount:=least(v_subtotal,v_voucher.discount_value); else v_discount:=v_subtotal*(v_voucher.discount_value/100); end if;
    if v_voucher.maximum_discount is not null then v_discount:=least(v_discount,v_voucher.maximum_discount); end if;
  end if;

  v_shipping := case when p_shipping_method='pickup' then 0 else 5000 end;
  v_total := greatest(0,v_subtotal-v_discount+v_shipping);
  v_order_number := 'SM-'||to_char(now(),'YYYYMMDD')||'-'||lpad(nextval('public.order_number_seq')::text,6,'0');

  insert into public.orders(order_number,user_id,store_id,status,payment_status,payment_method,shipping_method,subtotal,discount_amount,shipping_cost,total_amount,voucher_id,address_snapshot,customer_notes,client_request_id)
  values(v_order_number,auth.uid(),v_store,'pending_payment','pending',p_payment_method,p_shipping_method,v_subtotal,v_discount,v_shipping,v_total,v_voucher.id,v_address,p_notes,p_client_request_id)
  returning id into v_order;

  for r in
    select ci.*, p.name product_name, p.sku product_sku, p.price base_price, pv.name variant_name, pv.price_override
    from public.cart_items ci join public.products p on p.id=ci.product_id left join public.product_variants pv on pv.id=ci.variant_id
    where ci.cart_id=v_cart
  loop
    v_price:=coalesce(r.price_override,r.base_price);
    insert into public.order_items(order_id,product_id,variant_id,product_name,variant_name,sku,unit_price,quantity,subtotal)
    values(v_order,r.product_id,r.variant_id,r.product_name,r.variant_name,r.product_sku,v_price,r.quantity,v_price*r.quantity);
    update public.inventory set available_qty=available_qty-r.quantity,reserved_qty=reserved_qty+r.quantity
    where product_id=r.product_id and ((r.variant_id is null and variant_id is null) or variant_id=r.variant_id);
    insert into public.inventory_movements(store_id,product_id,variant_id,movement_type,quantity,note,reference_id,actor_id)
    values(v_store,r.product_id,r.variant_id,'reservation',-r.quantity,'Checkout reservation',v_order,auth.uid());
  end loop;

  insert into public.payments(order_id,method,status,amount) values(v_order,p_payment_method,'pending',v_total);
  insert into public.order_status_history(order_id,status,note,actor_id) values(v_order,'pending_payment','Order created',auth.uid());
  if v_voucher.id is not null then insert into public.voucher_usages(voucher_id,user_id,order_id,discount_amount) values(v_voucher.id,auth.uid(),v_order,v_discount); end if;
  delete from public.cart_items where cart_id=v_cart;

  if p_payment_method='cod' then
    update public.orders set status='confirmed' where id=v_order;
    update public.inventory i set reserved_qty=greatest(0,i.reserved_qty-oi.quantity)
    from public.order_items oi where oi.order_id=v_order and i.product_id=oi.product_id and ((oi.variant_id is null and i.variant_id is null) or i.variant_id=oi.variant_id);
    insert into public.inventory_movements(store_id,product_id,variant_id,movement_type,quantity,note,reference_id,actor_id)
    select v_store,product_id,variant_id,'sale',-quantity,'COD order confirmed',v_order,auth.uid() from public.order_items where order_id=v_order;
    insert into public.order_status_history(order_id,status,note,actor_id) values(v_order,'confirmed','COD order confirmed',auth.uid());
  end if;
  return v_order;
end;
$$;
revoke all on function public.create_checkout(uuid,text,text,text,text,uuid) from public, anon;
grant execute on function public.create_checkout(uuid,text,text,text,text,uuid) to authenticated;

create or replace function public.notify_order_status_change() returns trigger
language plpgsql security definer set search_path=public
as $$
declare v_user uuid; v_number text;
begin
  select user_id,order_number into v_user,v_number from public.orders where id=new.order_id;
  if v_user is not null then
    insert into public.notifications(user_id,type,title,body,data)
    values(v_user,'order_status','Update pesanan '||coalesce(v_number,''),
      'Status pesanan: '||replace(new.status,'_',' '),
      jsonb_build_object('order_id',new.order_id,'status',new.status));
  end if;
  return new;
end;
$$;
drop trigger if exists order_status_notify on public.order_status_history;
create trigger order_status_notify after insert on public.order_status_history
for each row execute function public.notify_order_status_change();
revoke all on function public.notify_order_status_change() from public, anon, authenticated;

create or replace function public.refresh_product_rating() returns trigger
language plpgsql security definer set search_path=public
as $$
declare v_product uuid;
begin
  v_product := coalesce(new.product_id,old.product_id);
  update public.products p set
    rating_average=coalesce((select round(avg(rating)::numeric,2) from public.reviews where product_id=v_product and is_approved),0),
    rating_count=(select count(*) from public.reviews where product_id=v_product and is_approved)
  where p.id=v_product;
  return coalesce(new,old);
end;
$$;
drop trigger if exists reviews_refresh_product_rating on public.reviews;
create trigger reviews_refresh_product_rating after insert or update or delete on public.reviews
for each row execute function public.refresh_product_rating();
revoke all on function public.refresh_product_rating() from public, anon, authenticated;

drop policy if exists product_images_storage_insert on storage.objects;
drop policy if exists product_images_storage_update on storage.objects;
drop policy if exists product_images_storage_delete on storage.objects;
create policy product_images_storage_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id='product-images' and exists (
      select 1 from public.store_members sm
      where sm.user_id=(select auth.uid())
        and (storage.foldername(name))[1]=sm.store_id::text
    )
  );
create policy product_images_storage_update on storage.objects
  for update to authenticated
  using (
    bucket_id='product-images' and exists (
      select 1 from public.store_members sm
      where sm.user_id=(select auth.uid())
        and (storage.foldername(name))[1]=sm.store_id::text
    )
  )
  with check (
    bucket_id='product-images' and exists (
      select 1 from public.store_members sm
      where sm.user_id=(select auth.uid())
        and (storage.foldername(name))[1]=sm.store_id::text
    )
  );
create policy product_images_storage_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id='product-images' and exists (
      select 1 from public.store_members sm
      where sm.user_id=(select auth.uid())
        and (storage.foldername(name))[1]=sm.store_id::text
    )
  );
