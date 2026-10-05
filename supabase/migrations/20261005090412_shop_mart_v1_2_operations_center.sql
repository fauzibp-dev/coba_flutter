create unique index if not exists refunds_return_unique_idx on public.refunds(return_id) where return_id is not null;

create or replace function public.superadmin_update_return_status(p_return_id uuid,p_status text,p_note text default null)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  v public.returns%rowtype;
  v_order public.orders%rowtype;
  v_allowed boolean := false;
  r record;
begin
  if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
  select * into v from public.returns where id=p_return_id for update;
  if v.id is null then raise exception 'Return not found'; end if;
  select * into v_order from public.orders where id=v.order_id for update;

  v_allowed := case v.status
    when 'requested' then p_status in ('reviewing','approved','rejected')
    when 'reviewing' then p_status in ('approved','rejected')
    when 'approved' then p_status in ('item_returning','item_received','refunded')
    when 'item_returning' then p_status in ('item_received')
    when 'item_received' then p_status in ('refunded')
    when 'refunded' then p_status in ('closed')
    else false
  end;
  if not v_allowed then raise exception 'Invalid return transition from % to %',v.status,p_status; end if;

  if p_status='approved' and v_order.status not in ('refund_pending','refunded') then
    update public.orders set status='refund_pending' where id=v_order.id;
    insert into public.order_status_history(order_id,status,note,actor_id)
    values(v_order.id,'refund_pending',coalesce(p_note,'Return approved'),auth.uid());
  end if;

  if p_status='item_received' then
    for r in select product_id,variant_id,quantity from public.order_items where order_id=v_order.id loop
      update public.inventory
      set available_qty=available_qty+r.quantity,updated_at=now()
      where product_id=r.product_id and ((r.variant_id is null and variant_id is null) or variant_id=r.variant_id);
      insert into public.inventory_movements(store_id,product_id,variant_id,movement_type,quantity,note,reference_id,actor_id)
      values(v_order.store_id,r.product_id,r.variant_id,'return',r.quantity,coalesce(p_note,'Returned item received'),p_return_id,auth.uid());
    end loop;
  end if;

  if p_status='refunded' then
    insert into public.refunds(return_id,order_id,amount,status,note,completed_at)
    values(p_return_id,v_order.id,v_order.total_amount,'completed',coalesce(p_note,'Refund completed by Super Admin'),now())
    on conflict (return_id) where return_id is not null
    do update set amount=excluded.amount,status='completed',note=excluded.note,completed_at=now();

    update public.orders set status='refunded',payment_status='refunded' where id=v_order.id;
    update public.payments set status='refunded',updated_at=now() where order_id=v_order.id;
    insert into public.order_status_history(order_id,status,note,actor_id)
    values(v_order.id,'refunded',coalesce(p_note,'Return refunded'),auth.uid());
  end if;

  update public.returns set status=p_status,updated_at=now() where id=p_return_id;
  insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
  values(v_order.store_id,auth.uid(),'superadmin_return_status_changed','return',p_return_id::text,
    jsonb_build_object('from',v.status,'to',p_status,'note',p_note));
end;
$$;
revoke all on function public.superadmin_update_return_status(uuid,text,text) from public, anon;
grant execute on function public.superadmin_update_return_status(uuid,text,text) to authenticated, service_role;

create or replace function public.superadmin_list_conversations(p_store_id uuid default null)
returns table(
  id uuid,
  store_id uuid,
  store_name text,
  customer_id uuid,
  customer_email text,
  customer_name text,
  updated_at timestamptz,
  last_message text,
  last_message_at timestamptz,
  unread_count bigint
)
language plpgsql
security definer
set search_path=public,auth
as $$
begin
  if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
  return query
  select c.id,c.store_id,s.name,c.customer_id,u.email,p.full_name,c.updated_at,
    (select m.body from public.messages m where m.conversation_id=c.id order by m.created_at desc limit 1),
    (select m.created_at from public.messages m where m.conversation_id=c.id order by m.created_at desc limit 1),
    (select count(*) from public.messages m where m.conversation_id=c.id and m.sender_id=c.customer_id and not m.is_read)
  from public.conversations c
  join public.stores s on s.id=c.store_id
  left join auth.users u on u.id=c.customer_id
  left join public.profiles p on p.id=c.customer_id
  where p_store_id is null or c.store_id=p_store_id
  order by coalesce((select max(m.created_at) from public.messages m where m.conversation_id=c.id),c.updated_at) desc;
end;
$$;
revoke all on function public.superadmin_list_conversations(uuid) from public, anon;
grant execute on function public.superadmin_list_conversations(uuid) to authenticated, service_role;

create or replace function public.superadmin_mark_conversation_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare v_customer uuid;
begin
  if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
  select customer_id into v_customer from public.conversations where id=p_conversation_id;
  if v_customer is null then raise exception 'Conversation not found'; end if;
  update public.messages set is_read=true where conversation_id=p_conversation_id and sender_id=v_customer and not is_read;
end;
$$;
revoke all on function public.superadmin_mark_conversation_read(uuid) from public, anon;
grant execute on function public.superadmin_mark_conversation_read(uuid) to authenticated, service_role;

create or replace function public.superadmin_send_notification(
  p_user_id uuid,
  p_store_id uuid,
  p_title text,
  p_body text,
  p_type text default 'announcement'
)
returns integer
language plpgsql
security definer
set search_path=public,auth
as $$
declare v_count integer:=0;
begin
  if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
  if btrim(coalesce(p_title,''))='' or btrim(coalesce(p_body,''))='' then raise exception 'Title and body required'; end if;
  if p_user_id is not null then
    if not exists(select 1 from auth.users where id=p_user_id) then raise exception 'User not found'; end if;
    insert into public.notifications(user_id,type,title,body,data)
    values(p_user_id,coalesce(nullif(btrim(p_type),''),'announcement'),btrim(p_title),btrim(p_body),jsonb_build_object('store_id',p_store_id));
    v_count:=1;
  elsif p_store_id is not null then
    with recipients as (
      select distinct user_id from public.orders where store_id=p_store_id
      union
      select distinct user_id from public.store_members where store_id=p_store_id
    ), ins as (
      insert into public.notifications(user_id,type,title,body,data)
      select r.user_id,coalesce(nullif(btrim(p_type),''),'announcement'),btrim(p_title),btrim(p_body),jsonb_build_object('store_id',p_store_id)
      from recipients r
      returning 1
    ) select count(*) into v_count from ins;
  else
    with ins as (
      insert into public.notifications(user_id,type,title,body,data)
      select id,coalesce(nullif(btrim(p_type),''),'announcement'),btrim(p_title),btrim(p_body),'{}'::jsonb from auth.users
      returning 1
    ) select count(*) into v_count from ins;
  end if;
  insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
  values(p_store_id,auth.uid(),'superadmin_notification_sent','notification',coalesce(p_user_id::text,'broadcast'),jsonb_build_object('title',p_title,'recipients',v_count));
  return v_count;
end;
$$;
revoke all on function public.superadmin_send_notification(uuid,uuid,text,text,text) from public, anon;
grant execute on function public.superadmin_send_notification(uuid,uuid,text,text,text) to authenticated, service_role;

create or replace function public.superadmin_list_integrations(p_store_id uuid default null)
returns table(
  id uuid,
  store_id uuid,
  store_name text,
  name text,
  source_type text,
  base_url text,
  is_active boolean,
  created_at timestamptz,
  mapping_count bigint,
  sync_count bigint,
  last_sync_status text,
  last_sync_at timestamptz
)
language plpgsql
security definer
set search_path=public
as $$
begin
  if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
  return query
  select i.id,i.store_id,s.name,i.name,i.source_type,i.base_url,i.is_active,i.created_at,
    (select count(*) from public.external_mappings em where em.source_id=i.id),
    (select count(*) from public.sync_logs sl where sl.source_id=i.id),
    (select sl.status from public.sync_logs sl where sl.source_id=i.id order by sl.created_at desc limit 1),
    (select sl.created_at from public.sync_logs sl where sl.source_id=i.id order by sl.created_at desc limit 1)
  from public.integration_sources i join public.stores s on s.id=i.store_id
  where p_store_id is null or i.store_id=p_store_id
  order by i.created_at desc;
end;
$$;
revoke all on function public.superadmin_list_integrations(uuid) from public, anon;
grant execute on function public.superadmin_list_integrations(uuid) to authenticated, service_role;

create or replace function public.superadmin_save_integration(
  p_source_id uuid,
  p_store_id uuid,
  p_name text,
  p_source_type text,
  p_base_url text,
  p_is_active boolean
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare v_id uuid;
begin
  if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
  if not exists(select 1 from public.stores where id=p_store_id) then raise exception 'Store not found'; end if;
  if btrim(coalesce(p_name,''))='' or btrim(coalesce(p_source_type,''))='' then raise exception 'Name and source type required'; end if;
  if p_source_id is null then
    insert into public.integration_sources(store_id,name,source_type,base_url,is_active)
    values(p_store_id,btrim(p_name),btrim(p_source_type),nullif(btrim(coalesce(p_base_url,'')),''),coalesce(p_is_active,false))
    returning id into v_id;
  else
    update public.integration_sources set name=btrim(p_name),source_type=btrim(p_source_type),base_url=nullif(btrim(coalesce(p_base_url,'')),''),is_active=coalesce(p_is_active,false)
    where id=p_source_id and store_id=p_store_id returning id into v_id;
    if v_id is null then raise exception 'Integration source not found'; end if;
  end if;
  insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
  values(p_store_id,auth.uid(),'superadmin_integration_saved','integration_source',v_id::text,jsonb_build_object('name',p_name,'type',p_source_type,'active',p_is_active));
  return v_id;
end;
$$;
revoke all on function public.superadmin_save_integration(uuid,uuid,text,text,text,boolean) from public, anon;
grant execute on function public.superadmin_save_integration(uuid,uuid,text,text,text,boolean) to authenticated, service_role;

create or replace function public.superadmin_list_sync_logs(p_source_id uuid default null,p_limit integer default 200)
returns table(id bigint,source_id uuid,source_name text,direction text,entity_type text,status text,detail jsonb,created_at timestamptz)
language plpgsql
security definer
set search_path=public
as $$
begin
  if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
  return query select sl.id,sl.source_id,i.name,sl.direction,sl.entity_type,sl.status,sl.detail,sl.created_at
  from public.sync_logs sl left join public.integration_sources i on i.id=sl.source_id
  where p_source_id is null or sl.source_id=p_source_id
  order by sl.created_at desc limit greatest(1,least(coalesce(p_limit,200),500));
end;
$$;
revoke all on function public.superadmin_list_sync_logs(uuid,integer) from public, anon;
grant execute on function public.superadmin_list_sync_logs(uuid,integer) to authenticated, service_role;
