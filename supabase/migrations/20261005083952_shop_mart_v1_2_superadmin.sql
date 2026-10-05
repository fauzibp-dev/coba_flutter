create table if not exists public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'super_admin' check (role in ('super_admin')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid null references auth.users(id)
);

alter table public.platform_admins enable row level security;
revoke all on public.platform_admins from anon, authenticated;

drop function if exists public.is_platform_super_admin();
create function public.is_platform_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null and exists (
    select 1 from public.platform_admins pa
    where pa.user_id = auth.uid() and pa.is_active = true and pa.role = 'super_admin'
  );
$$;
revoke all on function public.is_platform_super_admin() from public, anon;
grant execute on function public.is_platform_super_admin() to authenticated, service_role;

create or replace function public.is_store_staff(p_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_platform_super_admin() or exists(
    select 1 from public.store_members sm
    where sm.store_id=p_store_id and sm.user_id=auth.uid() and sm.role in ('owner','admin','staff')
  );
$$;

create or replace function public.is_store_admin(p_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_platform_super_admin() or exists(
    select 1 from public.store_members sm
    where sm.store_id=p_store_id and sm.user_id=auth.uid() and sm.role in ('owner','admin')
  );
$$;

create or replace function public.superadmin_dashboard()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare v jsonb;
begin
  if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
  select jsonb_build_object(
    'stores', (select count(*) from public.stores),
    'active_stores', (select count(*) from public.stores where is_active),
    'users', (select count(*) from auth.users),
    'store_members', (select count(*) from public.store_members),
    'products', (select count(*) from public.products),
    'active_products', (select count(*) from public.products where status='active'),
    'orders', (select count(*) from public.orders),
    'pending_orders', (select count(*) from public.orders where status in ('pending_payment','paid','confirmed','processing','ready_to_ship')),
    'paid_revenue', coalesce((select sum(total_amount) from public.orders where payment_status='paid'),0),
    'open_returns', (select count(*) from public.returns where status not in ('refunded','closed','rejected')),
    'low_stock', (select count(*) from public.inventory where available_qty <= low_stock_threshold),
    'conversations', (select count(*) from public.conversations),
    'unread_messages', (select count(*) from public.messages where is_read=false)
  ) into v;
  return v;
end;
$$;
revoke all on function public.superadmin_dashboard() from public, anon;
grant execute on function public.superadmin_dashboard() to authenticated, service_role;

create or replace function public.superadmin_list_stores()
returns table(
  id uuid,
  name text,
  slug text,
  description text,
  address text,
  phone text,
  is_active boolean,
  created_at timestamptz,
  product_count bigint,
  order_count bigint,
  member_count bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
  return query
  select s.id,s.name,s.slug,s.description,s.address,s.phone,s.is_active,s.created_at,
    (select count(*) from public.products p where p.store_id=s.id),
    (select count(*) from public.orders o where o.store_id=s.id),
    (select count(*) from public.store_members sm where sm.store_id=s.id)
  from public.stores s
  order by s.created_at desc;
end;
$$;
revoke all on function public.superadmin_list_stores() from public, anon;
grant execute on function public.superadmin_list_stores() to authenticated, service_role;

create or replace function public.superadmin_save_store(
  p_store_id uuid,
  p_name text,
  p_slug text,
  p_description text,
  p_address text,
  p_phone text,
  p_is_active boolean
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare v_id uuid;
begin
  if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
  if btrim(coalesce(p_name,''))='' then raise exception 'Store name required'; end if;
  if btrim(coalesce(p_slug,''))='' then raise exception 'Store slug required'; end if;
  if p_store_id is null then
    insert into public.stores(name,slug,description,address,phone,is_active)
    values(btrim(p_name),lower(btrim(p_slug)),nullif(btrim(coalesce(p_description,'')),''),nullif(btrim(coalesce(p_address,'')),''),nullif(btrim(coalesce(p_phone,'')),''),coalesce(p_is_active,true))
    returning id into v_id;
    insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
    values(v_id,auth.uid(),'superadmin_store_created','store',v_id::text,jsonb_build_object('name',p_name,'slug',p_slug));
  else
    update public.stores set
      name=btrim(p_name), slug=lower(btrim(p_slug)), description=nullif(btrim(coalesce(p_description,'')),''),
      address=nullif(btrim(coalesce(p_address,'')),''), phone=nullif(btrim(coalesce(p_phone,'')),''),
      is_active=coalesce(p_is_active,true), updated_at=now()
    where id=p_store_id returning id into v_id;
    if v_id is null then raise exception 'Store not found'; end if;
    insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
    values(v_id,auth.uid(),'superadmin_store_updated','store',v_id::text,jsonb_build_object('name',p_name,'slug',p_slug,'is_active',p_is_active));
  end if;
  return v_id;
end;
$$;
revoke all on function public.superadmin_save_store(uuid,text,text,text,text,text,boolean) from public, anon;
grant execute on function public.superadmin_save_store(uuid,text,text,text,text,text,boolean) to authenticated, service_role;

create or replace function public.superadmin_list_users(p_search text default null)
returns table(
  user_id uuid,
  email text,
  full_name text,
  phone text,
  created_at timestamptz,
  is_super_admin boolean,
  memberships jsonb
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
  return query
  select u.id,u.email,p.full_name,p.phone,u.created_at,
    exists(select 1 from public.platform_admins pa where pa.user_id=u.id and pa.is_active),
    coalesce((select jsonb_agg(jsonb_build_object('id',sm.id,'store_id',sm.store_id,'store_name',s.name,'role',sm.role) order by s.name)
      from public.store_members sm join public.stores s on s.id=sm.store_id where sm.user_id=u.id),'[]'::jsonb)
  from auth.users u
  left join public.profiles p on p.id=u.id
  where p_search is null or btrim(p_search)='' or coalesce(u.email,'') ilike '%'||btrim(p_search)||'%' or coalesce(p.full_name,'') ilike '%'||btrim(p_search)||'%'
  order by u.created_at desc
  limit 200;
end;
$$;
revoke all on function public.superadmin_list_users(text) from public, anon;
grant execute on function public.superadmin_list_users(text) to authenticated, service_role;

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
declare v_existing text;
begin
  if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
  if not exists(select 1 from auth.users where id=p_user_id) then raise exception 'User not found'; end if;
  if not exists(select 1 from public.stores where id=p_store_id) then raise exception 'Store not found'; end if;
  if p_role not in ('owner','admin','staff') then raise exception 'Invalid role'; end if;
  select role into v_existing from public.store_members where user_id=p_user_id and store_id=p_store_id;
  if coalesce(p_enabled,false) then
    insert into public.store_members(store_id,user_id,role) values(p_store_id,p_user_id,p_role)
    on conflict (store_id,user_id) do update set role=excluded.role;
    insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
    values(p_store_id,auth.uid(),'superadmin_member_upserted','store_member',p_user_id::text,jsonb_build_object('role',p_role));
  else
    if v_existing='owner' and (select count(*) from public.store_members where store_id=p_store_id and role='owner' and user_id<>p_user_id)=0 then
      raise exception 'Cannot remove the last store owner';
    end if;
    delete from public.store_members where user_id=p_user_id and store_id=p_store_id;
    insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
    values(p_store_id,auth.uid(),'superadmin_member_removed','store_member',p_user_id::text,jsonb_build_object('previous_role',v_existing));
  end if;
end;
$$;
revoke all on function public.superadmin_set_store_member(uuid,uuid,text,boolean) from public, anon;
grant execute on function public.superadmin_set_store_member(uuid,uuid,text,boolean) to authenticated, service_role;

create or replace function public.superadmin_set_platform_admin(p_user_id uuid,p_enabled boolean)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
  if not exists(select 1 from auth.users where id=p_user_id) then raise exception 'User not found'; end if;
  if coalesce(p_enabled,false) then
    insert into public.platform_admins(user_id,role,is_active,created_by)
    values(p_user_id,'super_admin',true,auth.uid())
    on conflict (user_id) do update set is_active=true,role='super_admin';
  else
    if p_user_id=auth.uid() then raise exception 'Cannot revoke your own super admin access'; end if;
    if (select count(*) from public.platform_admins where is_active and user_id<>p_user_id)=0 then raise exception 'Cannot revoke the last super admin'; end if;
    update public.platform_admins set is_active=false where user_id=p_user_id;
  end if;
  insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
  values(null,auth.uid(),'superadmin_access_changed','platform_admin',p_user_id::text,jsonb_build_object('enabled',p_enabled));
end;
$$;
revoke all on function public.superadmin_set_platform_admin(uuid,boolean) from public, anon;
grant execute on function public.superadmin_set_platform_admin(uuid,boolean) to authenticated, service_role;

create or replace function public.superadmin_list_products(p_store_id uuid default null,p_search text default null)
returns table(
  id uuid,
  store_id uuid,
  store_name text,
  category_id uuid,
  category_name text,
  name text,
  sku text,
  price numeric,
  compare_at_price numeric,
  status text,
  is_featured boolean,
  stock bigint,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
  return query
  select p.id,p.store_id,s.name,p.category_id,c.name,p.name,p.sku,p.price,p.compare_at_price,p.status,p.is_featured,
    coalesce((select sum(i.available_qty)::bigint from public.inventory i where i.product_id=p.id),0::bigint),p.created_at
  from public.products p
  join public.stores s on s.id=p.store_id
  left join public.categories c on c.id=p.category_id
  where (p_store_id is null or p.store_id=p_store_id)
    and (p_search is null or btrim(p_search)='' or p.name ilike '%'||btrim(p_search)||'%' or coalesce(p.sku,'') ilike '%'||btrim(p_search)||'%')
  order by p.created_at desc
  limit 300;
end;
$$;
revoke all on function public.superadmin_list_products(uuid,text) from public, anon;
grant execute on function public.superadmin_list_products(uuid,text) to authenticated, service_role;

create or replace function public.superadmin_save_product(
  p_product_id uuid,
  p_store_id uuid,
  p_name text,
  p_description text,
  p_price numeric,
  p_compare_at_price numeric,
  p_category_id uuid,
  p_sku text,
  p_stock integer,
  p_status text,
  p_featured boolean,
  p_stock_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare v_id uuid; v_inventory uuid; v_old_stock int:=0; v_slug text;
begin
  if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
  if not exists(select 1 from public.stores where id=p_store_id) then raise exception 'Store not found'; end if;
  if btrim(coalesce(p_name,''))='' then raise exception 'Product name required'; end if;
  if p_price<=0 then raise exception 'Price must be greater than zero'; end if;
  if p_stock<0 then raise exception 'Invalid stock'; end if;
  if p_status not in ('draft','active','inactive','archived') then raise exception 'Invalid status'; end if;
  if p_category_id is not null and not exists(select 1 from public.categories where id=p_category_id and store_id=p_store_id) then raise exception 'Invalid category'; end if;
  v_slug := regexp_replace(lower(btrim(p_name)),'[^a-z0-9]+','-','g')||'-'||floor(extract(epoch from clock_timestamp())*1000)::bigint;
  if p_product_id is null then
    insert into public.products(store_id,category_id,name,slug,description,price,compare_at_price,sku,status,is_featured)
    values(p_store_id,p_category_id,btrim(p_name),v_slug,btrim(coalesce(p_description,'')),p_price,p_compare_at_price,nullif(btrim(coalesce(p_sku,'')),''),p_status,coalesce(p_featured,false))
    returning id into v_id;
    insert into public.inventory(product_id,available_qty,reserved_qty) values(v_id,p_stock,0) returning id into v_inventory;
    if p_stock<>0 then
      insert into public.inventory_movements(store_id,product_id,movement_type,quantity,note,actor_id)
      values(p_store_id,v_id,'adjustment',p_stock,coalesce(nullif(btrim(p_stock_reason),''),'Initial stock by super admin'),auth.uid());
    end if;
  else
    v_id:=p_product_id;
    if not exists(select 1 from public.products where id=v_id and store_id=p_store_id) then raise exception 'Product not found in store'; end if;
    update public.products set category_id=p_category_id,name=btrim(p_name),description=btrim(coalesce(p_description,'')),price=p_price,
      compare_at_price=p_compare_at_price,sku=nullif(btrim(coalesce(p_sku,'')),''),status=p_status,is_featured=coalesce(p_featured,false),updated_at=now()
    where id=v_id;
    select id,available_qty into v_inventory,v_old_stock from public.inventory where product_id=v_id and variant_id is null for update;
    if v_inventory is null then
      insert into public.inventory(product_id,available_qty,reserved_qty) values(v_id,p_stock,0) returning id into v_inventory;
      v_old_stock:=0;
    elsif v_old_stock<>p_stock then
      if btrim(coalesce(p_stock_reason,''))='' then raise exception 'Stock adjustment reason required'; end if;
      update public.inventory set available_qty=p_stock,updated_at=now() where id=v_inventory;
    end if;
    if coalesce(v_old_stock,0)<>p_stock then
      insert into public.inventory_movements(store_id,product_id,movement_type,quantity,note,actor_id)
      values(p_store_id,v_id,'adjustment',p_stock-coalesce(v_old_stock,0),coalesce(nullif(btrim(p_stock_reason),''),'Super admin stock adjustment'),auth.uid());
    end if;
  end if;
  insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
  values(p_store_id,auth.uid(),'superadmin_product_saved','product',v_id::text,jsonb_build_object('name',p_name,'price',p_price,'stock',p_stock,'status',p_status));
  return v_id;
end;
$$;
revoke all on function public.superadmin_save_product(uuid,uuid,text,text,numeric,numeric,uuid,text,integer,text,boolean,text) from public, anon;
grant execute on function public.superadmin_save_product(uuid,uuid,text,text,numeric,numeric,uuid,text,integer,text,boolean,text) to authenticated, service_role;

create or replace function public.superadmin_list_orders(p_store_id uuid default null,p_status text default null)
returns table(
  id uuid,
  order_number text,
  store_id uuid,
  store_name text,
  customer_email text,
  status text,
  payment_status text,
  payment_method text,
  shipping_method text,
  total_amount numeric,
  created_at timestamptz,
  item_count bigint
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
  return query
  select o.id,o.order_number,o.store_id,s.name,u.email,o.status,o.payment_status,o.payment_method,o.shipping_method,o.total_amount,o.created_at,
    (select count(*) from public.order_items oi where oi.order_id=o.id)
  from public.orders o
  join public.stores s on s.id=o.store_id
  left join auth.users u on u.id=o.user_id
  where (p_store_id is null or o.store_id=p_store_id) and (p_status is null or p_status='' or o.status=p_status)
  order by o.created_at desc
  limit 300;
end;
$$;
revoke all on function public.superadmin_list_orders(uuid,text) from public, anon;
grant execute on function public.superadmin_list_orders(uuid,text) to authenticated, service_role;

create or replace function public.superadmin_list_vouchers(p_store_id uuid default null)
returns table(
 id uuid, store_id uuid, store_name text, code text, title text, discount_type text, discount_value numeric,
 minimum_purchase numeric, maximum_discount numeric, usage_limit integer, usage_per_user integer,
 starts_at timestamptz, ends_at timestamptz, is_active boolean
)
language plpgsql
security definer
set search_path = public
as $$
begin
 if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
 return query select v.id,v.store_id,s.name,v.code,v.title,v.discount_type,v.discount_value,v.minimum_purchase,v.maximum_discount,v.usage_limit,v.usage_per_user,v.starts_at,v.ends_at,v.is_active
 from public.vouchers v join public.stores s on s.id=v.store_id where p_store_id is null or v.store_id=p_store_id order by v.created_at desc;
end;
$$;
revoke all on function public.superadmin_list_vouchers(uuid) from public, anon;
grant execute on function public.superadmin_list_vouchers(uuid) to authenticated, service_role;

create or replace function public.superadmin_save_voucher(
 p_voucher_id uuid,p_store_id uuid,p_code text,p_title text,p_discount_type text,p_discount_value numeric,
 p_minimum_purchase numeric,p_maximum_discount numeric,p_usage_limit integer,p_usage_per_user integer,
 p_starts_at timestamptz,p_ends_at timestamptz,p_is_active boolean
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare v_id uuid;
begin
 if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
 if p_discount_type not in ('fixed','percentage') then raise exception 'Invalid discount type'; end if;
 if p_discount_value<=0 then raise exception 'Discount must be greater than zero'; end if;
 if p_discount_type='percentage' and p_discount_value>100 then raise exception 'Percentage cannot exceed 100'; end if;
 if p_voucher_id is null then
  insert into public.vouchers(store_id,code,title,discount_type,discount_value,minimum_purchase,maximum_discount,usage_limit,usage_per_user,starts_at,ends_at,is_active)
  values(p_store_id,upper(btrim(p_code)),btrim(p_title),p_discount_type,p_discount_value,coalesce(p_minimum_purchase,0),p_maximum_discount,p_usage_limit,coalesce(p_usage_per_user,1),coalesce(p_starts_at,now()),p_ends_at,coalesce(p_is_active,true)) returning id into v_id;
 else
  update public.vouchers set code=upper(btrim(p_code)),title=btrim(p_title),discount_type=p_discount_type,discount_value=p_discount_value,
   minimum_purchase=coalesce(p_minimum_purchase,0),maximum_discount=p_maximum_discount,usage_limit=p_usage_limit,usage_per_user=coalesce(p_usage_per_user,1),
   starts_at=coalesce(p_starts_at,starts_at),ends_at=p_ends_at,is_active=coalesce(p_is_active,true)
  where id=p_voucher_id and store_id=p_store_id returning id into v_id;
  if v_id is null then raise exception 'Voucher not found'; end if;
 end if;
 insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
 values(p_store_id,auth.uid(),'superadmin_voucher_saved','voucher',v_id::text,jsonb_build_object('code',upper(btrim(p_code)),'active',p_is_active));
 return v_id;
end;
$$;
revoke all on function public.superadmin_save_voucher(uuid,uuid,text,text,text,numeric,numeric,numeric,integer,integer,timestamptz,timestamptz,boolean) from public, anon;
grant execute on function public.superadmin_save_voucher(uuid,uuid,text,text,text,numeric,numeric,numeric,integer,integer,timestamptz,timestamptz,boolean) to authenticated, service_role;

create or replace function public.superadmin_list_banners(p_store_id uuid default null)
returns table(id uuid,store_id uuid,store_name text,title text,subtitle text,image_url text,target_type text,target_id uuid,sort_order integer,starts_at timestamptz,ends_at timestamptz,is_active boolean)
language plpgsql
security definer
set search_path=public
as $$
begin
 if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
 return query select b.id,b.store_id,s.name,b.title,b.subtitle,b.image_url,b.target_type,b.target_id,b.sort_order,b.starts_at,b.ends_at,b.is_active
 from public.banners b join public.stores s on s.id=b.store_id where p_store_id is null or b.store_id=p_store_id order by b.sort_order,b.created_at desc;
end;
$$;
revoke all on function public.superadmin_list_banners(uuid) from public, anon;
grant execute on function public.superadmin_list_banners(uuid) to authenticated, service_role;

create or replace function public.superadmin_save_banner(
 p_banner_id uuid,p_store_id uuid,p_title text,p_subtitle text,p_image_url text,p_target_type text,p_target_id uuid,p_sort_order integer,p_starts_at timestamptz,p_ends_at timestamptz,p_is_active boolean
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare v_id uuid;
begin
 if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
 if btrim(coalesce(p_title,''))='' then raise exception 'Banner title required'; end if;
 if p_banner_id is null then
  insert into public.banners(store_id,title,subtitle,image_url,target_type,target_id,sort_order,starts_at,ends_at,is_active)
  values(p_store_id,btrim(p_title),nullif(btrim(coalesce(p_subtitle,'')),''),nullif(btrim(coalesce(p_image_url,'')),''),nullif(btrim(coalesce(p_target_type,'')),''),p_target_id,coalesce(p_sort_order,0),coalesce(p_starts_at,now()),p_ends_at,coalesce(p_is_active,true)) returning id into v_id;
 else
  update public.banners set title=btrim(p_title),subtitle=nullif(btrim(coalesce(p_subtitle,'')),''),image_url=nullif(btrim(coalesce(p_image_url,'')),''),
   target_type=nullif(btrim(coalesce(p_target_type,'')),''),target_id=p_target_id,sort_order=coalesce(p_sort_order,0),starts_at=coalesce(p_starts_at,starts_at),ends_at=p_ends_at,is_active=coalesce(p_is_active,true)
  where id=p_banner_id and store_id=p_store_id returning id into v_id;
  if v_id is null then raise exception 'Banner not found'; end if;
 end if;
 insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
 values(p_store_id,auth.uid(),'superadmin_banner_saved','banner',v_id::text,jsonb_build_object('title',p_title,'active',p_is_active));
 return v_id;
end;
$$;
revoke all on function public.superadmin_save_banner(uuid,uuid,text,text,text,text,uuid,integer,timestamptz,timestamptz,boolean) from public, anon;
grant execute on function public.superadmin_save_banner(uuid,uuid,text,text,text,text,uuid,integer,timestamptz,timestamptz,boolean) to authenticated, service_role;

create or replace function public.superadmin_list_returns(p_store_id uuid default null)
returns table(id uuid,order_id uuid,order_number text,store_id uuid,store_name text,customer_email text,reason text,description text,status text,created_at timestamptz,updated_at timestamptz)
language plpgsql
security definer
set search_path=public,auth
as $$
begin
 if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
 return query select r.id,r.order_id,o.order_number,o.store_id,s.name,u.email,r.reason,r.description,r.status,r.created_at,r.updated_at
 from public.returns r join public.orders o on o.id=r.order_id join public.stores s on s.id=o.store_id left join auth.users u on u.id=r.user_id
 where p_store_id is null or o.store_id=p_store_id order by r.created_at desc;
end;
$$;
revoke all on function public.superadmin_list_returns(uuid) from public, anon;
grant execute on function public.superadmin_list_returns(uuid) to authenticated, service_role;

create or replace function public.superadmin_update_return_status(p_return_id uuid,p_status text,p_note text default null)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare v public.returns%rowtype; v_store uuid;
begin
 if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
 if p_status not in ('requested','reviewing','approved','rejected','item_returning','item_received','refunded','closed') then raise exception 'Invalid return status'; end if;
 select * into v from public.returns where id=p_return_id for update;
 if v.id is null then raise exception 'Return not found'; end if;
 select store_id into v_store from public.orders where id=v.order_id;
 update public.returns set status=p_status,updated_at=now() where id=p_return_id;
 insert into public.audit_logs(store_id,actor_id,action,entity_type,entity_id,new_value)
 values(v_store,auth.uid(),'superadmin_return_status_changed','return',p_return_id::text,jsonb_build_object('from',v.status,'to',p_status,'note',p_note));
end;
$$;
revoke all on function public.superadmin_update_return_status(uuid,text,text) from public, anon;
grant execute on function public.superadmin_update_return_status(uuid,text,text) to authenticated, service_role;

create or replace function public.superadmin_audit_logs(p_limit integer default 200)
returns table(id bigint,store_id uuid,store_name text,actor_email text,action text,entity_type text,entity_id text,old_value jsonb,new_value jsonb,created_at timestamptz)
language plpgsql
security definer
set search_path=public,auth
as $$
begin
 if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
 return query select a.id,a.store_id,s.name,u.email,a.action,a.entity_type,a.entity_id,a.old_value,a.new_value,a.created_at
 from public.audit_logs a left join public.stores s on s.id=a.store_id left join auth.users u on u.id=a.actor_id
 order by a.created_at desc limit greatest(1,least(coalesce(p_limit,200),500));
end;
$$;
revoke all on function public.superadmin_audit_logs(integer) from public, anon;
grant execute on function public.superadmin_audit_logs(integer) to authenticated, service_role;

drop policy if exists product_images_superadmin_insert on storage.objects;
drop policy if exists product_images_superadmin_update on storage.objects;
drop policy if exists product_images_superadmin_delete on storage.objects;
create policy product_images_superadmin_insert on storage.objects for insert to authenticated
with check (bucket_id='product-images' and public.is_platform_super_admin());
create policy product_images_superadmin_update on storage.objects for update to authenticated
using (bucket_id='product-images' and public.is_platform_super_admin())
with check (bucket_id='product-images' and public.is_platform_super_admin());
create policy product_images_superadmin_delete on storage.objects for delete to authenticated
using (bucket_id='product-images' and public.is_platform_super_admin());
