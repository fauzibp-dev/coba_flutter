begin;

create or replace function public.save_product_admin(
  p_store_id uuid,
  p_product_id uuid,
  p_name text,
  p_description text,
  p_price numeric,
  p_compare_at_price numeric,
  p_category_id uuid,
  p_sku text,
  p_stock integer,
  p_active boolean,
  p_featured boolean,
  p_stock_reason text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_slug text;
  v_inventory_id uuid;
  v_old_stock integer := 0;
  v_delta integer := 0;
begin
  if auth.uid() is null or not public.is_store_staff(p_store_id) then raise exception 'Not authorized'; end if;
  if length(btrim(p_name)) < 2 then raise exception 'Product name is required'; end if;
  if p_price <= 0 then raise exception 'Price must be greater than zero'; end if;
  if p_stock < 0 then raise exception 'Stock cannot be negative'; end if;
  if p_compare_at_price is not null and p_compare_at_price < 0 then raise exception 'Invalid compare price'; end if;
  if not exists(select 1 from public.categories where id=p_category_id and store_id=p_store_id) then
    raise exception 'Invalid category';
  end if;

  if p_product_id is null then
    v_slug := trim(both '-' from regexp_replace(lower(btrim(p_name)), '[^a-z0-9]+', '-', 'g'))
              || '-' || substr(gen_random_uuid()::text,1,8);
    insert into public.products(
      store_id,category_id,name,slug,description,price,compare_at_price,sku,status,is_featured
    ) values(
      p_store_id,p_category_id,btrim(p_name),v_slug,btrim(p_description),p_price,p_compare_at_price,
      nullif(btrim(p_sku),''),case when p_active then 'active' else 'draft' end,p_featured
    ) returning id into v_id;

    insert into public.inventory(product_id,available_qty,reserved_qty)
    values(v_id,p_stock,0);
    if p_stock <> 0 then
      insert into public.inventory_movements(store_id,product_id,movement_type,quantity,note,actor_id)
      values(p_store_id,v_id,'adjustment',p_stock,
        coalesce(nullif(btrim(p_stock_reason),''),'Initial stock'),auth.uid());
    end if;
  else
    select id into v_id from public.products
    where id=p_product_id and store_id=p_store_id for update;
    if v_id is null then raise exception 'Product not found'; end if;

    update public.products
    set category_id=p_category_id,name=btrim(p_name),description=btrim(p_description),price=p_price,
        compare_at_price=p_compare_at_price,sku=nullif(btrim(p_sku),''),
        status=case when p_active then 'active' else 'draft' end,is_featured=p_featured
    where id=v_id;

    select id,available_qty into v_inventory_id,v_old_stock
    from public.inventory
    where product_id=v_id and variant_id is null for update;

    if v_inventory_id is null then
      insert into public.inventory(product_id,available_qty,reserved_qty)
      values(v_id,p_stock,0) returning id into v_inventory_id;
      v_old_stock:=0;
    else
      update public.inventory set available_qty=p_stock where id=v_inventory_id;
    end if;

    v_delta:=p_stock-coalesce(v_old_stock,0);
    if v_delta <> 0 then
      if nullif(btrim(p_stock_reason),'') is null then raise exception 'Stock adjustment reason is required'; end if;
      insert into public.inventory_movements(store_id,product_id,movement_type,quantity,note,actor_id)
      values(p_store_id,v_id,'adjustment',v_delta,btrim(p_stock_reason),auth.uid());
    end if;
  end if;
  return v_id;
end;
$$;

revoke all on function public.save_product_admin(uuid,uuid,text,text,numeric,numeric,uuid,text,integer,boolean,boolean,text) from public, anon;
grant execute on function public.save_product_admin(uuid,uuid,text,text,numeric,numeric,uuid,text,integer,boolean,boolean,text) to authenticated;

create or replace function public.admin_update_order_status(
  p_order_id uuid,
  p_status text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  r record;
  v_allowed boolean:=false;
begin
  select * into v_order from public.orders where id=p_order_id for update;
  if v_order.id is null or not public.is_store_staff(v_order.store_id) then raise exception 'Not authorized'; end if;

  v_allowed := case v_order.status
    when 'pending_payment' then p_status in ('paid','cancelled')
    when 'paid' then p_status in ('confirmed','refund_pending')
    when 'confirmed' then p_status in ('processing','cancelled','refund_pending')
    when 'processing' then p_status in ('ready_to_ship','cancelled','refund_pending')
    when 'ready_to_ship' then p_status in ('shipped','cancelled','refund_pending')
    when 'shipped' then p_status in ('delivered','refund_pending')
    when 'delivered' then p_status in ('completed','refund_pending')
    when 'completed' then p_status in ('refund_pending')
    when 'refund_pending' then p_status in ('refunded')
    else false end;
  if not v_allowed then raise exception 'Invalid order transition from % to %',v_order.status,p_status; end if;
  if p_status='cancelled' and v_order.payment_status='paid' then
    raise exception 'Paid order must enter refund_pending instead of cancelled';
  end if;

  if p_status='confirmed' and v_order.status='paid' then
    update public.inventory i set reserved_qty=greatest(0,i.reserved_qty-oi.quantity)
    from public.order_items oi
    where oi.order_id=p_order_id and i.product_id=oi.product_id
      and ((oi.variant_id is null and i.variant_id is null) or i.variant_id=oi.variant_id);
    insert into public.inventory_movements(store_id,product_id,variant_id,movement_type,quantity,note,reference_id,actor_id)
    select v_order.store_id,product_id,variant_id,'sale',-quantity,'Order confirmed after payment',p_order_id,auth.uid()
    from public.order_items where order_id=p_order_id;
  end if;

  if p_status='cancelled' then
    for r in select * from public.order_items where order_id=p_order_id loop
      if v_order.status='pending_payment' then
        update public.inventory set available_qty=available_qty+r.quantity,
          reserved_qty=greatest(0,reserved_qty-r.quantity)
        where product_id=r.product_id
          and ((r.variant_id is null and variant_id is null) or variant_id=r.variant_id);
      else
        update public.inventory set available_qty=available_qty+r.quantity
        where product_id=r.product_id
          and ((r.variant_id is null and variant_id is null) or variant_id=r.variant_id);
      end if;
      insert into public.inventory_movements(store_id,product_id,variant_id,movement_type,quantity,note,reference_id,actor_id)
      values(v_order.store_id,r.product_id,r.variant_id,'cancellation',r.quantity,
        coalesce(p_note,'Admin cancellation'),p_order_id,auth.uid());
    end loop;
  end if;

  if p_status='refund_pending' and v_order.status='paid' then
    update public.inventory i set available_qty=available_qty+oi.quantity,
      reserved_qty=greatest(0,i.reserved_qty-oi.quantity)
    from public.order_items oi
    where oi.order_id=p_order_id and i.product_id=oi.product_id
      and ((oi.variant_id is null and i.variant_id is null) or i.variant_id=oi.variant_id);
    insert into public.inventory_movements(store_id,product_id,variant_id,movement_type,quantity,note,reference_id,actor_id)
    select v_order.store_id,product_id,variant_id,'refund',quantity,'Refund before fulfillment',p_order_id,auth.uid()
    from public.order_items where order_id=p_order_id;
  end if;

  update public.orders
  set status=p_status,
      payment_status=case
        when p_status='paid' then 'paid'
        when p_status='refunded' then 'refunded'
        when p_status='cancelled' then 'cancelled'
        when p_status='completed' and payment_method='cod' then 'paid'
        else payment_status end
  where id=p_order_id;

  if p_status='paid' then
    update public.payments set status='paid',paid_at=now() where order_id=p_order_id;
  elsif p_status='refunded' then
    update public.payments set status='refunded' where order_id=p_order_id;
  elsif p_status='cancelled' then
    update public.payments set status='cancelled' where order_id=p_order_id;
  elsif p_status='completed' and v_order.payment_method='cod' then
    update public.payments set status='paid',paid_at=coalesce(paid_at,now()) where order_id=p_order_id;
  end if;

  if p_status='completed' then
    update public.products p set sold_count=sold_count+x.qty
    from (select product_id,sum(quantity)::integer qty from public.order_items
      where order_id=p_order_id and product_id is not null group by product_id) x
    where p.id=x.product_id;
  elsif p_status='refunded' and exists(
    select 1 from public.order_status_history where order_id=p_order_id and status='completed'
  ) then
    update public.products p set sold_count=greatest(0,sold_count-x.qty)
    from (select product_id,sum(quantity)::integer qty from public.order_items
      where order_id=p_order_id and product_id is not null group by product_id) x
    where p.id=x.product_id;
  end if;

  insert into public.order_status_history(order_id,status,note,actor_id)
  values(p_order_id,p_status,p_note,auth.uid());
  insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
  values(v_order.store_id,auth.uid(),'order_status_changed','order',p_order_id::text,
    jsonb_build_object('from',v_order.status,'to',p_status,'note',p_note));
  insert into public.notifications(user_id,type,title,body,data)
  values(v_order.user_id,'order_status','Status pesanan diperbarui',
    'Pesanan '||v_order.order_number||' sekarang '||replace(p_status,'_',' ')||'.',
    jsonb_build_object('order_id',p_order_id,'status',p_status,'order_number',v_order.order_number));
end;
$$;

revoke all on function public.admin_update_order_status(uuid,text,text) from public, anon;
grant execute on function public.admin_update_order_status(uuid,text,text) to authenticated;

create or replace function public.cancel_my_order(p_order_id uuid,p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  r record;
begin
  select * into v_order from public.orders where id=p_order_id and user_id=auth.uid() for update;
  if v_order.id is null then raise exception 'Order not found'; end if;
  if v_order.payment_status='paid' then raise exception 'Paid orders require admin cancellation/refund handling'; end if;
  if v_order.status not in ('pending_payment','confirmed') then raise exception 'Order can no longer be cancelled'; end if;

  for r in select * from public.order_items where order_id=p_order_id loop
    if v_order.status='pending_payment' then
      update public.inventory set available_qty=available_qty+r.quantity,
        reserved_qty=greatest(0,reserved_qty-r.quantity)
      where product_id=r.product_id
        and ((r.variant_id is null and variant_id is null) or variant_id=r.variant_id);
    else
      update public.inventory set available_qty=available_qty+r.quantity
      where product_id=r.product_id
        and ((r.variant_id is null and variant_id is null) or variant_id=r.variant_id);
    end if;
    insert into public.inventory_movements(store_id,product_id,variant_id,movement_type,quantity,note,reference_id,actor_id)
    values(v_order.store_id,r.product_id,r.variant_id,'cancellation',r.quantity,
      coalesce(p_reason,'Customer cancellation'),p_order_id,auth.uid());
  end loop;

  update public.orders set status='cancelled',payment_status='cancelled' where id=p_order_id;
  update public.payments set status='cancelled' where order_id=p_order_id;
  insert into public.order_status_history(order_id,status,note,actor_id)
  values(p_order_id,'cancelled',p_reason,auth.uid());
  insert into public.notifications(user_id,type,title,body,data)
  values(auth.uid(),'order_cancelled','Pesanan dibatalkan',
    'Pesanan '||v_order.order_number||' berhasil dibatalkan.',
    jsonb_build_object('order_id',p_order_id,'order_number',v_order.order_number));
end;
$$;

revoke all on function public.cancel_my_order(uuid,text) from public, anon;
grant execute on function public.cancel_my_order(uuid,text) to authenticated;

commit;
