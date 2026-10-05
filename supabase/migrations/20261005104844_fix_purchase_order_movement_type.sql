create or replace function public.receive_purchase_order(p_purchase_order_id uuid, p_receipts jsonb)
 returns void
 language plpgsql
 security definer
 set search_path='public'
as $$
declare
  po public.purchase_orders%rowtype;
  x jsonb;
  item public.purchase_order_items%rowtype;
  v_qty integer;
  v_inv public.inventory%rowtype;
  v_all_received boolean;
begin
  select * into po from public.purchase_orders where id=p_purchase_order_id for update;
  if po.id is null or not public.is_store_staff(po.store_id) then raise exception 'Not authorized'; end if;
  if po.status not in ('ordered','partial','draft') then raise exception 'Purchase order cannot be received'; end if;
  if p_receipts is null or jsonb_array_length(p_receipts)=0 then raise exception 'No receipt quantities'; end if;

  for x in select * from jsonb_array_elements(p_receipts) loop
    select * into item
      from public.purchase_order_items
      where id=(x->>'item_id')::uuid and purchase_order_id=po.id
      for update;
    if item.id is null then raise exception 'Invalid purchase order item'; end if;

    v_qty:=(x->>'quantity')::integer;
    if v_qty<1 or item.received_quantity+v_qty>item.quantity then raise exception 'Invalid received quantity'; end if;

    select * into v_inv
      from public.inventory
      where product_id=item.product_id
        and ((item.variant_id is null and variant_id is null) or variant_id=item.variant_id)
      for update;
    if v_inv.id is null then
      insert into public.inventory(product_id,variant_id,available_qty,reserved_qty)
      values(item.product_id,item.variant_id,0,0)
      returning * into v_inv;
    end if;

    update public.inventory
      set available_qty=available_qty+v_qty,updated_at=now()
      where id=v_inv.id;
    update public.purchase_order_items
      set received_quantity=received_quantity+v_qty
      where id=item.id;

    insert into public.inventory_movements(
      store_id,product_id,variant_id,movement_type,quantity,note,reference_id,actor_id
    ) values(
      po.store_id,item.product_id,item.variant_id,'purchase',v_qty,
      'Purchase order receipt',po.id,auth.uid()
    );
  end loop;

  select not exists(
    select 1 from public.purchase_order_items
    where purchase_order_id=po.id and received_quantity<quantity
  ) into v_all_received;

  update public.purchase_orders
    set status=case when v_all_received then 'received' else 'partial' end,
        updated_at=now()
    where id=po.id;

  insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
  values(po.store_id,auth.uid(),'purchase_order_received','purchase_order',po.id::text,
         jsonb_build_object('completed',v_all_received));
end;
$$;

grant execute on function public.receive_purchase_order(uuid,jsonb) to authenticated;
