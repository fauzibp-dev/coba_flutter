begin;

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
    select v_order.store_id,product_id,variant_id,'release',quantity,'Refund before fulfillment',p_order_id,auth.uid()
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

create or replace function public.admin_update_return_status(
  p_return_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_return public.returns%rowtype;
  v_order public.orders%rowtype;
  v_allowed boolean:=false;
  r record;
begin
  select * into v_return from public.returns where id=p_return_id for update;
  if v_return.id is null then raise exception 'Return not found'; end if;
  select * into v_order from public.orders where id=v_return.order_id for update;
  if v_order.id is null or not public.is_store_staff(v_order.store_id) then raise exception 'Not authorized'; end if;

  v_allowed := case v_return.status
    when 'requested' then p_status in ('reviewing','approved','rejected')
    when 'reviewing' then p_status in ('approved','rejected')
    when 'approved' then p_status in ('item_returning','closed')
    when 'item_returning' then p_status in ('item_received')
    when 'item_received' then p_status in ('refunded','closed')
    else false end;
  if not v_allowed then raise exception 'Invalid return transition from % to %',v_return.status,p_status; end if;

  if p_status='refunded' then
    if v_order.payment_status <> 'paid' then raise exception 'Only a paid order can be refunded'; end if;

    for r in select * from public.order_items where order_id=v_order.id loop
      update public.inventory
      set available_qty=available_qty+r.quantity
      where product_id=r.product_id
        and ((r.variant_id is null and variant_id is null) or variant_id=r.variant_id);
      insert into public.inventory_movements(store_id,product_id,variant_id,movement_type,quantity,note,reference_id,actor_id)
      values(v_order.store_id,r.product_id,r.variant_id,'return',r.quantity,'Customer return received',v_order.id,auth.uid());
    end loop;

    insert into public.refunds(return_id,order_id,amount,status,note,completed_at)
    values(v_return.id,v_order.id,v_order.total_amount,'completed','Full order refund after return',now());

    update public.orders set status='refunded',payment_status='refunded' where id=v_order.id;
    update public.payments set status='refunded' where order_id=v_order.id;
    if exists(select 1 from public.order_status_history where order_id=v_order.id and status='completed') then
      update public.products p set sold_count=greatest(0,sold_count-x.qty)
      from (select product_id,sum(quantity)::integer qty from public.order_items
        where order_id=v_order.id and product_id is not null group by product_id) x
      where p.id=x.product_id;
    end if;
    insert into public.order_status_history(order_id,status,note,actor_id)
    values(v_order.id,'refunded','Refund completed after returned item received',auth.uid());
  end if;

  update public.returns set status=p_status where id=p_return_id;
  insert into public.notifications(user_id,type,title,body,data)
  values(v_return.user_id,'return_status','Status retur diperbarui',
    'Pengajuan retur '||v_order.order_number||' sekarang '||replace(p_status,'_',' ')||'.',
    jsonb_build_object('order_id',v_order.id,'return_id',p_return_id,'status',p_status));
end;
$$;

revoke all on function public.admin_update_return_status(uuid,text) from public, anon;
grant execute on function public.admin_update_return_status(uuid,text) to authenticated;

commit;
