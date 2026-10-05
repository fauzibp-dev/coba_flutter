create or replace function public.superadmin_set_store_member(
  p_user_id uuid,
  p_store_id uuid,
  p_role text,
  p_enabled boolean
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_existing text;
  v_old_owner uuid;
begin
  if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
  if not exists(select 1 from auth.users where id=p_user_id) then raise exception 'User not found'; end if;
  if not exists(select 1 from public.stores where id=p_store_id) then raise exception 'Store not found'; end if;
  if p_role not in ('owner','admin','staff') then raise exception 'Invalid role'; end if;

  select role into v_existing from public.store_members where user_id=p_user_id and store_id=p_store_id;

  if coalesce(p_enabled,false) then
    if p_role='owner' then
      select user_id into v_old_owner
      from public.store_members
      where store_id=p_store_id and role='owner' and user_id<>p_user_id
      limit 1
      for update;

      if v_old_owner is not null then
        update public.store_members set role='admin'
        where store_id=p_store_id and user_id=v_old_owner;
        insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
        values(p_store_id,auth.uid(),'superadmin_owner_transferred_from','store_member',v_old_owner::text,jsonb_build_object('new_role','admin','new_owner',p_user_id));
      end if;
    elsif v_existing='owner' then
      raise exception 'Transfer ownership to another user before changing the current owner role';
    end if;

    insert into public.store_members(store_id,user_id,role)
    values(p_store_id,p_user_id,p_role)
    on conflict (store_id,user_id) do update set role=excluded.role;

    insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
    values(p_store_id,auth.uid(),case when p_role='owner' then 'superadmin_owner_assigned' else 'superadmin_member_upserted' end,'store_member',p_user_id::text,jsonb_build_object('role',p_role));
  else
    if v_existing='owner' then
      raise exception 'Cannot remove the store owner. Transfer ownership first';
    end if;
    delete from public.store_members where user_id=p_user_id and store_id=p_store_id;
    insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
    values(p_store_id,auth.uid(),'superadmin_member_removed','store_member',p_user_id::text,jsonb_build_object('previous_role',v_existing));
  end if;
end;
$$;
revoke all on function public.superadmin_set_store_member(uuid,uuid,text,boolean) from public, anon;
grant execute on function public.superadmin_set_store_member(uuid,uuid,text,boolean) to authenticated, service_role;

create or replace function public.superadmin_list_categories(p_store_id uuid default null)
returns table(
  id uuid,
  store_id uuid,
  store_name text,
  parent_id uuid,
  parent_name text,
  name text,
  slug text,
  icon_name text,
  sort_order integer,
  is_active boolean,
  product_count bigint,
  created_at timestamptz
)
language plpgsql
security definer
set search_path=public
as $$
begin
  if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
  return query
  select c.id,c.store_id,s.name,c.parent_id,pc.name,c.name,c.slug,c.icon_name,c.sort_order,c.is_active,
    (select count(*) from public.products p where p.category_id=c.id),c.created_at
  from public.categories c
  join public.stores s on s.id=c.store_id
  left join public.categories pc on pc.id=c.parent_id
  where p_store_id is null or c.store_id=p_store_id
  order by s.name,c.sort_order,c.name;
end;
$$;
revoke all on function public.superadmin_list_categories(uuid) from public, anon;
grant execute on function public.superadmin_list_categories(uuid) to authenticated, service_role;

create or replace function public.superadmin_save_category(
  p_category_id uuid,
  p_store_id uuid,
  p_parent_id uuid,
  p_name text,
  p_slug text,
  p_icon_name text,
  p_sort_order integer,
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
  if btrim(coalesce(p_name,''))='' then raise exception 'Category name required'; end if;
  if btrim(coalesce(p_slug,''))='' then raise exception 'Category slug required'; end if;
  if p_parent_id is not null and not exists(select 1 from public.categories where id=p_parent_id and store_id=p_store_id) then
    raise exception 'Parent category must belong to the same store';
  end if;
  if p_parent_id is not null and p_parent_id=p_category_id then raise exception 'Category cannot be its own parent'; end if;

  if p_category_id is null then
    insert into public.categories(store_id,parent_id,name,slug,icon_name,sort_order,is_active)
    values(p_store_id,p_parent_id,btrim(p_name),lower(btrim(p_slug)),nullif(btrim(coalesce(p_icon_name,'')),''),coalesce(p_sort_order,0),coalesce(p_is_active,true))
    returning id into v_id;
  else
    update public.categories set
      parent_id=p_parent_id,
      name=btrim(p_name),
      slug=lower(btrim(p_slug)),
      icon_name=nullif(btrim(coalesce(p_icon_name,'')),''),
      sort_order=coalesce(p_sort_order,0),
      is_active=coalesce(p_is_active,true)
    where id=p_category_id and store_id=p_store_id
    returning id into v_id;
    if v_id is null then raise exception 'Category not found'; end if;
  end if;

  insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
  values(p_store_id,auth.uid(),'superadmin_category_saved','category',v_id::text,
    jsonb_build_object('name',p_name,'slug',p_slug,'active',p_is_active,'parent_id',p_parent_id));
  return v_id;
end;
$$;
revoke all on function public.superadmin_save_category(uuid,uuid,uuid,text,text,text,integer,boolean) from public, anon;
grant execute on function public.superadmin_save_category(uuid,uuid,uuid,text,text,text,integer,boolean) to authenticated, service_role;
