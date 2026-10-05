create or replace function public.save_product_variant(
  p_product_id uuid,
  p_variant_id uuid,
  p_name text,
  p_sku text,
  p_barcode text,
  p_price_override numeric,
  p_weight_grams integer,
  p_stock integer,
  p_is_active boolean,
  p_option_value_ids uuid[] default '{}',
  p_stock_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_product public.products%rowtype;
  v_id uuid;
  v_old_stock integer:=0;
  v_inventory_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_product from public.products where id=p_product_id;
  if v_product.id is null or not public.is_store_staff(v_product.store_id) then raise exception 'Not authorized'; end if;
  if btrim(coalesce(p_name,''))='' then raise exception 'Variant name required'; end if;
  if p_price_override is not null and p_price_override<0 then raise exception 'Invalid variant price'; end if;
  if coalesce(p_weight_grams,0)<0 or coalesce(p_stock,0)<0 then raise exception 'Invalid variant stock or weight'; end if;
  if exists(
    select 1 from unnest(coalesce(p_option_value_ids,'{}'::uuid[])) x
    where not exists(
      select 1 from public.product_option_values pov
      join public.product_options po on po.id=pov.option_id
      where pov.id=x and po.product_id=p_product_id
    )
  ) then raise exception 'Invalid option value'; end if;
  if exists(
    select pov.option_id from public.product_option_values pov
    where pov.id=any(coalesce(p_option_value_ids,'{}'::uuid[]))
    group by pov.option_id having count(*)>1
  ) then raise exception 'Only one value per option is allowed'; end if;

  if p_variant_id is null then
    insert into public.product_variants(product_id,name,sku,barcode,price_override,weight_grams,is_active,sort_order)
    values(p_product_id,btrim(p_name),nullif(btrim(coalesce(p_sku,'')),''),nullif(btrim(coalesce(p_barcode,'')),''),p_price_override,coalesce(p_weight_grams,0),coalesce(p_is_active,true),
      coalesce((select max(sort_order)+1 from public.product_variants where product_id=p_product_id),0))
    returning id into v_id;
    insert into public.inventory(product_id,variant_id,available_qty,reserved_qty)
    values(p_product_id,v_id,p_stock,0) returning id into v_inventory_id;
    if p_stock<>0 then
      insert into public.inventory_movements(store_id,product_id,variant_id,movement_type,quantity,note,actor_id)
      values(v_product.store_id,p_product_id,v_id,'adjustment',p_stock,coalesce(nullif(btrim(coalesce(p_stock_reason,'')),''),'Initial variant stock'),auth.uid());
    end if;
  else
    v_id:=p_variant_id;
    if not exists(select 1 from public.product_variants where id=v_id and product_id=p_product_id) then raise exception 'Variant not found'; end if;
    update public.product_variants set
      name=btrim(p_name),sku=nullif(btrim(coalesce(p_sku,'')),''),barcode=nullif(btrim(coalesce(p_barcode,'')),''),
      price_override=p_price_override,weight_grams=coalesce(p_weight_grams,0),is_active=coalesce(p_is_active,true)
    where id=v_id;
    select id,available_qty into v_inventory_id,v_old_stock from public.inventory where product_id=p_product_id and variant_id=v_id for update;
    if v_inventory_id is null then
      insert into public.inventory(product_id,variant_id,available_qty,reserved_qty) values(p_product_id,v_id,p_stock,0) returning id into v_inventory_id;
      v_old_stock:=0;
    else
      if p_stock<v_old_stock and (select reserved_qty from public.inventory where id=v_inventory_id)>p_stock then raise exception 'Stock cannot be lower than reserved quantity'; end if;
      update public.inventory set available_qty=p_stock,updated_at=now() where id=v_inventory_id;
    end if;
    if coalesce(v_old_stock,0)<>p_stock then
      if btrim(coalesce(p_stock_reason,''))='' then raise exception 'Stock adjustment reason required'; end if;
      insert into public.inventory_movements(store_id,product_id,variant_id,movement_type,quantity,note,actor_id)
      values(v_product.store_id,p_product_id,v_id,'adjustment',p_stock-coalesce(v_old_stock,0),btrim(p_stock_reason),auth.uid());
    end if;
  end if;
  delete from public.variant_option_values where variant_id=v_id;
  if coalesce(array_length(p_option_value_ids,1),0)>0 then
    insert into public.variant_option_values(variant_id,option_value_id)
    select v_id,x from unnest(p_option_value_ids) x on conflict do nothing;
  end if;
  insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
  values(v_product.store_id,auth.uid(),'variant_saved','product_variant',v_id::text,jsonb_build_object('product_id',p_product_id,'name',p_name,'stock',p_stock,'active',p_is_active));
  return v_id;
end;
$$;
revoke all on function public.save_product_variant(uuid,uuid,text,text,text,numeric,integer,integer,boolean,uuid[],text) from public,anon;
grant execute on function public.save_product_variant(uuid,uuid,text,text,text,numeric,integer,integer,boolean,uuid[],text) to authenticated,service_role;

create or replace function public.archive_product_variant(p_variant_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v public.product_variants%rowtype; v_store uuid;
begin
  select * into v from public.product_variants where id=p_variant_id for update;
  if v.id is null then raise exception 'Variant not found'; end if;
  select store_id into v_store from public.products where id=v.product_id;
  if not public.is_store_staff(v_store) then raise exception 'Not authorized'; end if;
  update public.product_variants set is_active=false where id=v.id;
  insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
  values(v_store,auth.uid(),'variant_archived','product_variant',v.id::text,jsonb_build_object('product_id',v.product_id));
end; $$;
revoke all on function public.archive_product_variant(uuid) from public,anon;
grant execute on function public.archive_product_variant(uuid) to authenticated,service_role;

create or replace function public.add_purchase_order_item(
  p_purchase_order_id uuid,p_product_id uuid,p_variant_id uuid,p_quantity integer,p_unit_cost numeric
)
returns uuid language plpgsql security definer set search_path=public as $$
declare po public.purchase_orders%rowtype; v_id uuid;
begin
  select * into po from public.purchase_orders where id=p_purchase_order_id for update;
  if po.id is null or not public.is_store_staff(po.store_id) then raise exception 'Not authorized'; end if;
  if po.status not in ('draft','ordered','partial') then raise exception 'Purchase order cannot be edited'; end if;
  if p_quantity<1 or p_unit_cost<0 then raise exception 'Invalid purchase order item'; end if;
  if not exists(select 1 from public.products where id=p_product_id and store_id=po.store_id) then raise exception 'Invalid product'; end if;
  if p_variant_id is not null and not exists(select 1 from public.product_variants where id=p_variant_id and product_id=p_product_id) then raise exception 'Invalid variant'; end if;
  insert into public.purchase_order_items(purchase_order_id,product_id,variant_id,quantity,unit_cost)
  values(po.id,p_product_id,p_variant_id,p_quantity,p_unit_cost) returning id into v_id;
  update public.purchase_orders set total_cost=(select coalesce(sum(quantity*unit_cost),0) from public.purchase_order_items where purchase_order_id=po.id),updated_at=now() where id=po.id;
  return v_id;
end; $$;
revoke all on function public.add_purchase_order_item(uuid,uuid,uuid,integer,numeric) from public,anon;
grant execute on function public.add_purchase_order_item(uuid,uuid,uuid,integer,numeric) to authenticated,service_role;

create or replace function public.receive_purchase_order(p_purchase_order_id uuid,p_receipts jsonb)
returns void language plpgsql security definer set search_path=public as $$
declare po public.purchase_orders%rowtype; x jsonb; item public.purchase_order_items%rowtype; v_qty integer; v_inv public.inventory%rowtype; v_all_received boolean;
begin
  select * into po from public.purchase_orders where id=p_purchase_order_id for update;
  if po.id is null or not public.is_store_staff(po.store_id) then raise exception 'Not authorized'; end if;
  if po.status not in ('ordered','partial','draft') then raise exception 'Purchase order cannot be received'; end if;
  if p_receipts is null or jsonb_array_length(p_receipts)=0 then raise exception 'No receipt quantities'; end if;
  for x in select * from jsonb_array_elements(p_receipts) loop
    select * into item from public.purchase_order_items where id=(x->>'item_id')::uuid and purchase_order_id=po.id for update;
    if item.id is null then raise exception 'Invalid purchase order item'; end if;
    v_qty:=(x->>'quantity')::integer;
    if v_qty<1 or item.received_quantity+v_qty>item.quantity then raise exception 'Invalid received quantity'; end if;
    select * into v_inv from public.inventory where product_id=item.product_id and ((item.variant_id is null and variant_id is null) or variant_id=item.variant_id) for update;
    if v_inv.id is null then insert into public.inventory(product_id,variant_id,available_qty,reserved_qty) values(item.product_id,item.variant_id,0,0) returning * into v_inv; end if;
    update public.inventory set available_qty=available_qty+v_qty,updated_at=now() where id=v_inv.id;
    update public.purchase_order_items set received_quantity=received_quantity+v_qty where id=item.id;
    insert into public.inventory_movements(store_id,product_id,variant_id,movement_type,quantity,note,reference_id,actor_id)
    values(po.store_id,item.product_id,item.variant_id,'restock',v_qty,'Purchase order receipt',po.id,auth.uid());
  end loop;
  select not exists(select 1 from public.purchase_order_items where purchase_order_id=po.id and received_quantity<quantity) into v_all_received;
  update public.purchase_orders set status=case when v_all_received then 'received' else 'partial' end,updated_at=now() where id=po.id;
  insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
  values(po.store_id,auth.uid(),'purchase_order_received','purchase_order',po.id::text,jsonb_build_object('completed',v_all_received));
end; $$;
revoke all on function public.receive_purchase_order(uuid,jsonb) from public,anon;
grant execute on function public.receive_purchase_order(uuid,jsonb) to authenticated,service_role;

create or replace function public.set_conversation_state(p_conversation_id uuid,p_status text,p_priority text default null,p_assigned_to uuid default null)
returns void language plpgsql security definer set search_path=public as $$
declare c public.conversations%rowtype;
begin
 select * into c from public.conversations where id=p_conversation_id;
 if c.id is null or not public.is_store_staff(c.store_id) then raise exception 'Not authorized'; end if;
 if p_status not in ('open','pending','resolved','closed') then raise exception 'Invalid conversation status'; end if;
 if p_priority is not null and p_priority not in ('low','normal','high','urgent') then raise exception 'Invalid conversation priority'; end if;
 if p_assigned_to is not null and not exists(select 1 from public.store_members where store_id=c.store_id and user_id=p_assigned_to) and not public.is_platform_super_admin() then raise exception 'Assignee is not store staff'; end if;
 update public.conversations set status=p_status,priority=coalesce(p_priority,priority),assigned_to=p_assigned_to,updated_at=now() where id=c.id;
end; $$;
revoke all on function public.set_conversation_state(uuid,text,text,uuid) from public,anon;
grant execute on function public.set_conversation_state(uuid,text,text,uuid) to authenticated,service_role;

create or replace function public.touch_conversation_after_message()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 update public.conversations set last_message_at=new.created_at,updated_at=new.created_at,status=case when status='closed' then 'open' else status end where id=new.conversation_id;
 return new;
end; $$;
drop trigger if exists trg_touch_conversation_after_message on public.messages;
create trigger trg_touch_conversation_after_message after insert on public.messages for each row execute function public.touch_conversation_after_message();
