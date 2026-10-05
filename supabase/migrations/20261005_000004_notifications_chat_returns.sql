begin;

-- Server-authored notifications.
drop policy if exists notifications_owner on public.notifications;
create policy notifications_owner_read on public.notifications
for select to authenticated
using (user_id = (select auth.uid()));

revoke insert, update, delete, truncate on table public.notifications from anon, authenticated;
grant select on table public.notifications to authenticated;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  update public.notifications set is_read=true
  where id=p_notification_id and user_id=auth.uid();
end;
$$;
revoke all on function public.mark_notification_read(uuid) from public, anon;
grant execute on function public.mark_notification_read(uuid) to authenticated;

-- One customer conversation per store.
create or replace function public.get_or_create_conversation(p_store_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.stores where id=p_store_id and is_active) then
    raise exception 'Store unavailable';
  end if;
  insert into public.conversations(store_id,customer_id)
  values(p_store_id,auth.uid())
  on conflict(store_id,customer_id) do update set updated_at=now()
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.get_or_create_conversation(uuid) from public, anon;
grant execute on function public.get_or_create_conversation(uuid) to authenticated;

-- Return requests go through a checked RPC. Admin status changes also use RPC.
create or replace function public.request_return(
  p_order_id uuid,
  p_reason text,
  p_description text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_return uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_order from public.orders
  where id=p_order_id and user_id=auth.uid() for update;
  if v_order.id is null then raise exception 'Order not found'; end if;
  if v_order.status not in ('delivered','completed') then
    raise exception 'Return is not available for this order';
  end if;
  if length(btrim(p_reason)) < 3 then raise exception 'Return reason is required'; end if;
  if exists(select 1 from public.returns where order_id=p_order_id and status not in ('rejected','closed')) then
    raise exception 'Return request already exists';
  end if;

  insert into public.returns(order_id,user_id,reason,description,status)
  values(p_order_id,auth.uid(),btrim(p_reason),nullif(btrim(p_description),''),'requested')
  returning id into v_return;

  insert into public.notifications(user_id,type,title,body,data)
  values(auth.uid(),'return_requested','Retur diajukan',
    'Pengajuan retur untuk '||v_order.order_number||' sudah diterima.',
    jsonb_build_object('order_id',p_order_id,'return_id',v_return));
  return v_return;
end;
$$;
revoke all on function public.request_return(uuid,text,text) from public, anon;
grant execute on function public.request_return(uuid,text,text) to authenticated;

revoke update, delete, truncate on table public.returns from authenticated;

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
begin
  if p_status not in ('approved','rejected','received','closed') then
    raise exception 'Invalid return status';
  end if;
  select * into v_return from public.returns where id=p_return_id for update;
  if v_return.id is null then raise exception 'Return not found'; end if;
  select * into v_order from public.orders where id=v_return.order_id;
  if v_order.id is null or not public.is_store_staff(v_order.store_id) then
    raise exception 'Not authorized';
  end if;
  update public.returns set status=p_status where id=p_return_id;
  insert into public.notifications(user_id,type,title,body,data)
  values(v_return.user_id,'return_status','Status retur diperbarui',
    'Pengajuan retur '||v_order.order_number||' sekarang '||p_status||'.',
    jsonb_build_object('order_id',v_order.id,'return_id',p_return_id,'status',p_status));
end;
$$;
revoke all on function public.admin_update_return_status(uuid,text) from public, anon;
grant execute on function public.admin_update_return_status(uuid,text) to authenticated;

-- Restrict product image mutations to the store_id folder already used by Flutter.
drop policy if exists product_images_storage_insert on storage.objects;
drop policy if exists product_images_storage_update on storage.objects;
drop policy if exists product_images_storage_delete on storage.objects;

create policy product_images_storage_insert on storage.objects
for insert to authenticated
with check (
  bucket_id='product-images'
  and exists(
    select 1 from public.store_members sm
    where sm.user_id=(select auth.uid())
      and sm.store_id::text=(storage.foldername(name))[1]
  )
);

create policy product_images_storage_update on storage.objects
for update to authenticated
using (
  bucket_id='product-images'
  and exists(
    select 1 from public.store_members sm
    where sm.user_id=(select auth.uid())
      and sm.store_id::text=(storage.foldername(name))[1]
  )
)
with check (
  bucket_id='product-images'
  and exists(
    select 1 from public.store_members sm
    where sm.user_id=(select auth.uid())
      and sm.store_id::text=(storage.foldername(name))[1]
  )
);

create policy product_images_storage_delete on storage.objects
for delete to authenticated
using (
  bucket_id='product-images'
  and exists(
    select 1 from public.store_members sm
    where sm.user_id=(select auth.uid())
      and sm.store_id::text=(storage.foldername(name))[1]
  )
);

commit;
