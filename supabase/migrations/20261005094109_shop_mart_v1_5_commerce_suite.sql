create extension if not exists pg_trgm;

-- Store commerce configuration
create table if not exists public.store_settings (
  store_id uuid primary key references public.stores(id) on delete cascade,
  currency text not null default 'IDR',
  timezone text not null default 'Asia/Jakarta',
  local_delivery_fee numeric(14,2) not null default 5000 check (local_delivery_fee >= 0),
  free_shipping_threshold numeric(14,2) null check (free_shipping_threshold is null or free_shipping_threshold >= 0),
  manual_payment_timeout_minutes integer not null default 120 check (manual_payment_timeout_minutes between 15 and 10080),
  bank_name text null,
  bank_account_name text null,
  bank_account_number text null,
  support_phone text null,
  return_window_days integer not null default 7 check (return_window_days between 0 and 90),
  maintenance_mode boolean not null default false,
  updated_at timestamptz not null default now()
);
insert into public.store_settings(store_id)
select id from public.stores
on conflict (store_id) do nothing;

create table if not exists public.delivery_zones (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  city text null,
  district text null,
  fee numeric(14,2) not null default 0 check (fee >= 0),
  free_shipping_threshold numeric(14,2) null check (free_shipping_threshold is null or free_shipping_threshold >= 0),
  priority integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists delivery_zones_store_idx on public.delivery_zones(store_id,is_active,priority desc);

-- Product option / variant model
create table if not exists public.product_options (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  name text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique(product_id,name)
);
create table if not exists public.product_option_values (
  id uuid primary key default gen_random_uuid(),
  option_id uuid not null references public.product_options(id) on delete cascade,
  value text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique(option_id,value)
);
create table if not exists public.variant_option_values (
  variant_id uuid not null references public.product_variants(id) on delete cascade,
  option_value_id uuid not null references public.product_option_values(id) on delete cascade,
  primary key(variant_id,option_value_id)
);
alter table public.product_variants add column if not exists barcode text null;
alter table public.product_variants add column if not exists weight_grams integer not null default 0;
alter table public.product_variants add column if not exists image_url text null;
alter table public.product_variants add column if not exists sort_order integer not null default 0;
alter table public.product_variants add constraint product_variants_weight_nonnegative check (weight_grams >= 0) not valid;
alter table public.product_variants validate constraint product_variants_weight_nonnegative;
create index if not exists product_variants_product_sort_idx on public.product_variants(product_id,sort_order);

-- Campaigns / flash sale / voucher scope
create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  campaign_type text not null check (campaign_type in ('flash_sale','auto_discount','featured','category_promo')),
  status text not null default 'draft' check (status in ('draft','active','paused','ended')),
  starts_at timestamptz not null default now(),
  ends_at timestamptz null,
  priority integer not null default 0,
  config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.campaign_products (
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  variant_id uuid null references public.product_variants(id) on delete cascade,
  promo_price numeric(14,2) null check (promo_price is null or promo_price >= 0),
  quota integer null check (quota is null or quota > 0),
  sold_qty integer not null default 0 check (sold_qty >= 0),
  per_user_limit integer null check (per_user_limit is null or per_user_limit > 0),
  primary key(campaign_id,product_id,variant_id)
);
create unique index if not exists campaign_products_no_variant_uq on public.campaign_products(campaign_id,product_id) where variant_id is null;
create index if not exists campaigns_active_idx on public.campaigns(store_id,status,starts_at,ends_at);

create table if not exists public.voucher_products (
  voucher_id uuid not null references public.vouchers(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  primary key(voucher_id,product_id)
);
create table if not exists public.voucher_categories (
  voucher_id uuid not null references public.vouchers(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  primary key(voucher_id,category_id)
);
alter table public.vouchers add column if not exists first_order_only boolean not null default false;
alter table public.vouchers add column if not exists free_shipping boolean not null default false;
alter table public.vouchers add column if not exists minimum_quantity integer not null default 1;
alter table public.vouchers add column if not exists is_public boolean not null default true;
alter table public.vouchers add constraint vouchers_minimum_quantity_check check (minimum_quantity > 0) not valid;
alter table public.vouchers validate constraint vouchers_minimum_quantity_check;

-- Reservation lifecycle
create table if not exists public.inventory_reservations (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  variant_id uuid null references public.product_variants(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  status text not null default 'active' check (status in ('active','committed','released','expired')),
  expires_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(order_id,product_id,variant_id)
);
create index if not exists inventory_reservations_expiry_idx on public.inventory_reservations(status,expires_at) where status='active';
alter table public.orders add column if not exists payment_due_at timestamptz null;
alter table public.orders add column if not exists reservation_expires_at timestamptz null;
alter table public.order_items add column if not exists original_unit_price numeric(14,2) null;
alter table public.order_items add column if not exists campaign_id uuid null references public.campaigns(id) on delete set null;

-- Shipping / fulfillment
create table if not exists public.shipments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  store_id uuid not null references public.stores(id) on delete cascade,
  shipping_method text not null check (shipping_method in ('pickup','local_delivery','external_courier')),
  provider text null,
  tracking_number text null,
  internal_delivery_code text null unique,
  driver_name text null,
  driver_phone text null,
  status text not null default 'pending' check (status in ('pending','assigned','ready_for_pickup','picked_up','in_transit','failed_attempt','delivered','cancelled')),
  estimated_delivery_at timestamptz null,
  picked_up_at timestamptz null,
  delivered_at timestamptz null,
  proof_path text null,
  recipient_name text null,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.shipment_events (
  id uuid primary key default gen_random_uuid(),
  shipment_id uuid not null references public.shipments(id) on delete cascade,
  status text not null,
  description text null,
  location text null,
  actor_id uuid null references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists shipment_events_shipment_idx on public.shipment_events(shipment_id,created_at);

-- Manual payment evidence
create table if not exists public.manual_payment_proofs (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  proof_path text not null,
  bank_name text null,
  payer_name text null,
  amount numeric(14,2) null check (amount is null or amount >= 0),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  admin_note text null,
  verified_by uuid null references auth.users(id) on delete set null,
  verified_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists manual_payment_proofs_order_idx on public.manual_payment_proofs(order_id,created_at desc);

-- Rich return / review
alter table public.returns add column if not exists requested_resolution text null;
alter table public.returns add column if not exists admin_note text null;
alter table public.returns add column if not exists expires_at timestamptz null;
create table if not exists public.return_items (
  id uuid primary key default gen_random_uuid(),
  return_id uuid not null references public.returns(id) on delete cascade,
  order_item_id uuid not null references public.order_items(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  reason text null,
  condition_note text null,
  resolution text null check (resolution is null or resolution in ('refund','replace','store_credit')),
  unique(return_id,order_item_id)
);
create table if not exists public.return_evidence (
  id uuid primary key default gen_random_uuid(),
  return_id uuid not null references public.returns(id) on delete cascade,
  uploaded_by uuid not null references auth.users(id) on delete cascade,
  file_path text not null,
  media_type text not null default 'image' check (media_type in ('image','video','document')),
  created_at timestamptz not null default now()
);
create table if not exists public.review_images (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.reviews(id) on delete cascade,
  image_url text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create table if not exists public.review_helpful_votes (
  review_id uuid not null references public.reviews(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(review_id,user_id)
);
create table if not exists public.review_reports (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.reviews(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reason text not null,
  status text not null default 'open' check (status in ('open','reviewed','dismissed','removed')),
  created_at timestamptz not null default now(),
  unique(review_id,user_id)
);

-- Discovery / engagement
create table if not exists public.search_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  query text not null,
  created_at timestamptz not null default now()
);
create index if not exists search_history_user_idx on public.search_history(user_id,created_at desc);
create table if not exists public.product_views (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  viewed_at timestamptz not null default now()
);
create index if not exists product_views_user_idx on public.product_views(user_id,viewed_at desc);
create index if not exists product_views_product_idx on public.product_views(product_id,viewed_at desc);
create index if not exists products_name_trgm_idx on public.products using gin (name gin_trgm_ops);
create index if not exists products_description_trgm_idx on public.products using gin (coalesce(description,'') gin_trgm_ops);

-- Notification preferences / push readiness
create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  order_updates boolean not null default true,
  chat_messages boolean not null default true,
  promotions boolean not null default true,
  push_enabled boolean not null default true,
  email_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('android','ios','web')),
  provider text not null default 'fcm',
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists device_tokens_user_idx on public.device_tokens(user_id,is_active);

-- Support operations
alter table public.conversations add column if not exists status text not null default 'open';
alter table public.conversations add column if not exists priority text not null default 'normal';
alter table public.conversations add column if not exists assigned_to uuid null references auth.users(id) on delete set null;
alter table public.conversations add column if not exists last_message_at timestamptz null;
alter table public.conversations add constraint conversations_status_check check (status in ('open','pending','resolved','closed')) not valid;
alter table public.conversations validate constraint conversations_status_check;
alter table public.conversations add constraint conversations_priority_check check (priority in ('low','normal','high','urgent')) not valid;
alter table public.conversations validate constraint conversations_priority_check;
alter table public.messages add column if not exists reply_to_id uuid null references public.messages(id) on delete set null;
create table if not exists public.canned_replies (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  title text not null,
  body text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Warehouse operations
create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  phone text null,
  email text null,
  address text null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  supplier_id uuid null references public.suppliers(id) on delete set null,
  po_number text not null unique,
  status text not null default 'draft' check (status in ('draft','ordered','partial','received','cancelled')),
  expected_at timestamptz null,
  notes text null,
  total_cost numeric(14,2) not null default 0 check (total_cost >= 0),
  created_by uuid null references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.purchase_order_items (
  id uuid primary key default gen_random_uuid(),
  purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  variant_id uuid null references public.product_variants(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  received_quantity integer not null default 0 check (received_quantity >= 0),
  unit_cost numeric(14,2) not null default 0 check (unit_cost >= 0)
);
create table if not exists public.stocktakes (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  status text not null default 'draft' check (status in ('draft','counting','completed','cancelled')),
  notes text null,
  created_by uuid null references auth.users(id) on delete set null,
  completed_at timestamptz null,
  created_at timestamptz not null default now()
);
create table if not exists public.stocktake_items (
  id uuid primary key default gen_random_uuid(),
  stocktake_id uuid not null references public.stocktakes(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  variant_id uuid null references public.product_variants(id) on delete restrict,
  system_qty integer not null,
  counted_qty integer null,
  variance integer generated always as (case when counted_qty is null then null else counted_qty-system_qty end) stored,
  unique(stocktake_id,product_id,variant_id)
);

-- Platform settings and account lifecycle
create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  is_public boolean not null default false,
  updated_by uuid null references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
insert into public.app_settings(key,value,is_public) values
  ('minimum_supported_version','{"android":"1.2.0"}'::jsonb,true),
  ('maintenance','{"enabled":false,"message":"Shop Mart sedang dalam pemeliharaan."}'::jsonb,true)
on conflict (key) do nothing;
create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  reason text null,
  status text not null default 'requested' check (status in ('requested','processing','completed','rejected')),
  requested_at timestamptz not null default now(),
  processed_at timestamptz null,
  unique(user_id,status)
);

-- Enable RLS
alter table public.store_settings enable row level security;
alter table public.delivery_zones enable row level security;
alter table public.product_options enable row level security;
alter table public.product_option_values enable row level security;
alter table public.variant_option_values enable row level security;
alter table public.campaigns enable row level security;
alter table public.campaign_products enable row level security;
alter table public.voucher_products enable row level security;
alter table public.voucher_categories enable row level security;
alter table public.inventory_reservations enable row level security;
alter table public.shipments enable row level security;
alter table public.shipment_events enable row level security;
alter table public.manual_payment_proofs enable row level security;
alter table public.return_items enable row level security;
alter table public.return_evidence enable row level security;
alter table public.review_images enable row level security;
alter table public.review_helpful_votes enable row level security;
alter table public.review_reports enable row level security;
alter table public.search_history enable row level security;
alter table public.product_views enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.device_tokens enable row level security;
alter table public.canned_replies enable row level security;
alter table public.suppliers enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.purchase_order_items enable row level security;
alter table public.stocktakes enable row level security;
alter table public.stocktake_items enable row level security;
alter table public.app_settings enable row level security;
alter table public.account_deletion_requests enable row level security;

-- Public/config/catalog policies
create policy store_settings_public_read on public.store_settings for select using (exists(select 1 from public.stores s where s.id=store_id and s.is_active));
create policy store_settings_staff_write on public.store_settings for all to authenticated using (public.is_store_admin(store_id)) with check (public.is_store_admin(store_id));
create policy delivery_zones_public_read on public.delivery_zones for select using (is_active and exists(select 1 from public.stores s where s.id=store_id and s.is_active));
create policy delivery_zones_staff_write on public.delivery_zones for all to authenticated using (public.is_store_admin(store_id)) with check (public.is_store_admin(store_id));
create policy product_options_public_read on public.product_options for select using (exists(select 1 from public.products p where p.id=product_id and p.status='active'));
create policy product_options_staff_write on public.product_options for all to authenticated using (exists(select 1 from public.products p where p.id=product_id and public.is_store_staff(p.store_id))) with check (exists(select 1 from public.products p where p.id=product_id and public.is_store_staff(p.store_id)));
create policy product_option_values_public_read on public.product_option_values for select using (exists(select 1 from public.product_options o join public.products p on p.id=o.product_id where o.id=option_id and p.status='active'));
create policy product_option_values_staff_write on public.product_option_values for all to authenticated using (exists(select 1 from public.product_options o join public.products p on p.id=o.product_id where o.id=option_id and public.is_store_staff(p.store_id))) with check (exists(select 1 from public.product_options o join public.products p on p.id=o.product_id where o.id=option_id and public.is_store_staff(p.store_id)));
create policy variant_option_values_public_read on public.variant_option_values for select using (exists(select 1 from public.product_variants v join public.products p on p.id=v.product_id where v.id=variant_id and p.status='active'));
create policy variant_option_values_staff_write on public.variant_option_values for all to authenticated using (exists(select 1 from public.product_variants v join public.products p on p.id=v.product_id where v.id=variant_id and public.is_store_staff(p.store_id))) with check (exists(select 1 from public.product_variants v join public.products p on p.id=v.product_id where v.id=variant_id and public.is_store_staff(p.store_id)));
create policy campaigns_public_read on public.campaigns for select using (status='active' and starts_at<=now() and (ends_at is null or ends_at>=now()));
create policy campaigns_staff_write on public.campaigns for all to authenticated using (public.is_store_admin(store_id)) with check (public.is_store_admin(store_id));
create policy campaign_products_public_read on public.campaign_products for select using (exists(select 1 from public.campaigns c where c.id=campaign_id and c.status='active' and c.starts_at<=now() and (c.ends_at is null or c.ends_at>=now())));
create policy campaign_products_staff_write on public.campaign_products for all to authenticated using (exists(select 1 from public.campaigns c where c.id=campaign_id and public.is_store_admin(c.store_id))) with check (exists(select 1 from public.campaigns c where c.id=campaign_id and public.is_store_admin(c.store_id)));
create policy voucher_products_public_read on public.voucher_products for select using (exists(select 1 from public.vouchers v where v.id=voucher_id and v.is_active));
create policy voucher_products_staff_write on public.voucher_products for all to authenticated using (exists(select 1 from public.vouchers v where v.id=voucher_id and public.is_store_admin(v.store_id))) with check (exists(select 1 from public.vouchers v where v.id=voucher_id and public.is_store_admin(v.store_id)));
create policy voucher_categories_public_read on public.voucher_categories for select using (exists(select 1 from public.vouchers v where v.id=voucher_id and v.is_active));
create policy voucher_categories_staff_write on public.voucher_categories for all to authenticated using (exists(select 1 from public.vouchers v where v.id=voucher_id and public.is_store_admin(v.store_id))) with check (exists(select 1 from public.vouchers v where v.id=voucher_id and public.is_store_admin(v.store_id)));

-- Private commerce policies
create policy inventory_reservations_owner_read on public.inventory_reservations for select to authenticated using (exists(select 1 from public.orders o where o.id=order_id and (o.user_id=auth.uid() or public.is_store_staff(o.store_id))));
create policy shipments_owner_staff_read on public.shipments for select to authenticated using (exists(select 1 from public.orders o where o.id=order_id and (o.user_id=auth.uid() or public.is_store_staff(o.store_id))));
create policy shipment_events_owner_staff_read on public.shipment_events for select to authenticated using (exists(select 1 from public.shipments s join public.orders o on o.id=s.order_id where s.id=shipment_id and (o.user_id=auth.uid() or public.is_store_staff(o.store_id))));
create policy manual_payment_proofs_owner_staff_read on public.manual_payment_proofs for select to authenticated using (user_id=auth.uid() or exists(select 1 from public.orders o where o.id=order_id and public.is_store_staff(o.store_id)));
create policy manual_payment_proofs_owner_insert on public.manual_payment_proofs for insert to authenticated with check (user_id=auth.uid() and exists(select 1 from public.orders o where o.id=order_id and o.user_id=auth.uid() and o.payment_method='manual_transfer'));
create policy return_items_owner_staff_read on public.return_items for select to authenticated using (exists(select 1 from public.returns r join public.orders o on o.id=r.order_id where r.id=return_id and (r.user_id=auth.uid() or public.is_store_staff(o.store_id))));
create policy return_evidence_owner_staff_read on public.return_evidence for select to authenticated using (exists(select 1 from public.returns r join public.orders o on o.id=r.order_id where r.id=return_id and (r.user_id=auth.uid() or public.is_store_staff(o.store_id))));
create policy return_evidence_owner_insert on public.return_evidence for insert to authenticated with check (uploaded_by=auth.uid() and exists(select 1 from public.returns r where r.id=return_id and r.user_id=auth.uid()));
create policy review_images_public_read on public.review_images for select using (exists(select 1 from public.reviews r where r.id=review_id and r.is_approved));
create policy review_images_owner_insert on public.review_images for insert to authenticated with check (exists(select 1 from public.reviews r where r.id=review_id and r.user_id=auth.uid()));
create policy review_votes_public_read on public.review_helpful_votes for select using (true);
create policy review_votes_owner_write on public.review_helpful_votes for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy review_reports_owner_insert on public.review_reports for insert to authenticated with check (user_id=auth.uid());
create policy review_reports_owner_staff_read on public.review_reports for select to authenticated using (user_id=auth.uid() or exists(select 1 from public.reviews r join public.products p on p.id=r.product_id where r.id=review_id and public.is_store_staff(p.store_id)));
create policy search_history_owner on public.search_history for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy product_views_owner on public.product_views for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy notification_preferences_owner on public.notification_preferences for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy device_tokens_owner on public.device_tokens for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy canned_replies_staff on public.canned_replies for all to authenticated using (public.is_store_staff(store_id)) with check (public.is_store_staff(store_id));
create policy suppliers_staff on public.suppliers for all to authenticated using (public.is_store_staff(store_id)) with check (public.is_store_staff(store_id));
create policy purchase_orders_staff on public.purchase_orders for all to authenticated using (public.is_store_staff(store_id)) with check (public.is_store_staff(store_id));
create policy purchase_order_items_staff on public.purchase_order_items for all to authenticated using (exists(select 1 from public.purchase_orders po where po.id=purchase_order_id and public.is_store_staff(po.store_id))) with check (exists(select 1 from public.purchase_orders po where po.id=purchase_order_id and public.is_store_staff(po.store_id)));
create policy stocktakes_staff on public.stocktakes for all to authenticated using (public.is_store_staff(store_id)) with check (public.is_store_staff(store_id));
create policy stocktake_items_staff on public.stocktake_items for all to authenticated using (exists(select 1 from public.stocktakes st where st.id=stocktake_id and public.is_store_staff(st.store_id))) with check (exists(select 1 from public.stocktakes st where st.id=stocktake_id and public.is_store_staff(st.store_id)));
create policy app_settings_public_read on public.app_settings for select using (is_public or public.is_platform_super_admin());
create policy app_settings_superadmin_write on public.app_settings for all to authenticated using (public.is_platform_super_admin()) with check (public.is_platform_super_admin());
create policy account_deletion_owner on public.account_deletion_requests for select to authenticated using (user_id=auth.uid() or public.is_platform_super_admin());
create policy account_deletion_owner_insert on public.account_deletion_requests for insert to authenticated with check (user_id=auth.uid());

-- Helper: shipping fee based on zone and store configuration
create or replace function public.calculate_shipping_fee(p_store_id uuid,p_address_id uuid,p_shipping_method text,p_subtotal numeric default 0)
returns numeric
language plpgsql
stable
security definer
set search_path=public
as $$
declare v_address public.addresses%rowtype; v_fee numeric:=0; v_threshold numeric; v_zone record;
begin
  if p_shipping_method='pickup' then return 0; end if;
  if p_shipping_method not in ('local_delivery','external_courier') then raise exception 'Unsupported shipping method'; end if;
  if p_address_id is null then raise exception 'Delivery address required'; end if;
  select * into v_address from public.addresses where id=p_address_id and user_id=auth.uid();
  if v_address.id is null then raise exception 'Address not found'; end if;
  select dz.fee,dz.free_shipping_threshold into v_zone
  from public.delivery_zones dz
  where dz.store_id=p_store_id and dz.is_active
    and (dz.city is null or lower(dz.city)=lower(v_address.city))
    and (dz.district is null or lower(dz.district)=lower(v_address.district))
  order by (dz.district is not null) desc,(dz.city is not null) desc,dz.priority desc
  limit 1;
  if found then
    v_fee:=v_zone.fee; v_threshold:=v_zone.free_shipping_threshold;
  else
    select local_delivery_fee,free_shipping_threshold into v_fee,v_threshold from public.store_settings where store_id=p_store_id;
    v_fee:=coalesce(v_fee,5000);
  end if;
  if v_threshold is not null and p_subtotal>=v_threshold then return 0; end if;
  return coalesce(v_fee,0);
end; $$;
revoke all on function public.calculate_shipping_fee(uuid,uuid,text,numeric) from public,anon;
grant execute on function public.calculate_shipping_fee(uuid,uuid,text,numeric) to authenticated,service_role;

-- Checkout quotation from authoritative server data
create or replace function public.quote_checkout_v2(p_address_id uuid,p_shipping_method text,p_voucher_code text default null)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
 v_cart uuid; v_store uuid; v_subtotal numeric:=0; v_discount numeric:=0; v_shipping numeric:=0; v_total numeric:=0;
 v_voucher public.vouchers%rowtype; v_usage int:=0; v_qty int:=0; v_eligible numeric:=0; r record; v_price numeric; v_campaign uuid; v_items jsonb:='[]'::jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_shipping_method not in ('pickup','local_delivery') then raise exception 'Unsupported shipping method'; end if;
 select id into v_cart from public.carts where user_id=auth.uid();
 if v_cart is null or not exists(select 1 from public.cart_items where cart_id=v_cart) then raise exception 'Cart is empty'; end if;
 select p.store_id into v_store from public.cart_items ci join public.products p on p.id=ci.product_id where ci.cart_id=v_cart limit 1;
 if exists(select 1 from public.cart_items ci join public.products p on p.id=ci.product_id where ci.cart_id=v_cart and p.store_id<>v_store) then raise exception 'Multi-store checkout is not enabled yet'; end if;
 for r in
  select ci.*,p.name product_name,p.price base_price,p.category_id,p.status,pv.price_override,pv.is_active variant_active,pv.name variant_name,i.available_qty
  from public.cart_items ci join public.products p on p.id=ci.product_id
  left join public.product_variants pv on pv.id=ci.variant_id
  left join public.inventory i on i.product_id=ci.product_id and ((ci.variant_id is null and i.variant_id is null) or i.variant_id=ci.variant_id)
  where ci.cart_id=v_cart
 loop
  if r.status<>'active' or (r.variant_id is not null and coalesce(r.variant_active,false)=false) then raise exception 'Product unavailable: %',r.product_name; end if;
  if coalesce(r.available_qty,0)<r.quantity then raise exception 'Stock not enough for %',r.product_name; end if;
  v_price:=coalesce(r.price_override,r.base_price); v_campaign:=null;
  select cp.promo_price,cp.campaign_id into v_price,v_campaign
  from public.campaign_products cp join public.campaigns c on c.id=cp.campaign_id
  where cp.product_id=r.product_id and (cp.variant_id is null or cp.variant_id=r.variant_id)
    and cp.promo_price is not null and c.status='active' and c.starts_at<=now() and (c.ends_at is null or c.ends_at>=now())
    and (cp.quota is null or cp.sold_qty+r.quantity<=cp.quota)
  order by c.priority desc,cp.variant_id is not null desc,cp.promo_price asc limit 1;
  v_subtotal:=v_subtotal+(v_price*r.quantity); v_qty:=v_qty+r.quantity;
  v_items:=v_items||jsonb_build_array(jsonb_build_object('cart_item_id',r.id,'product_id',r.product_id,'variant_id',r.variant_id,'name',r.product_name,'variant_name',r.variant_name,'quantity',r.quantity,'unit_price',v_price,'campaign_id',v_campaign,'stock',r.available_qty));
 end loop;
 if p_voucher_code is not null and btrim(p_voucher_code)<>'' then
  select * into v_voucher from public.vouchers where store_id=v_store and upper(code)=upper(btrim(p_voucher_code)) and is_active and starts_at<=now() and (ends_at is null or ends_at>=now()) limit 1;
  if v_voucher.id is null then raise exception 'Voucher invalid or expired'; end if;
  if v_voucher.first_order_only and exists(select 1 from public.orders where user_id=auth.uid() and status not in ('cancelled','refunded')) then raise exception 'Voucher only valid for first order'; end if;
  if v_qty<v_voucher.minimum_quantity then raise exception 'Minimum quantity not reached'; end if;
  select count(*) into v_usage from public.voucher_usages where voucher_id=v_voucher.id and user_id=auth.uid();
  if v_usage>=v_voucher.usage_per_user then raise exception 'Voucher usage limit reached'; end if;
  if v_voucher.usage_limit is not null and (select count(*) from public.voucher_usages where voucher_id=v_voucher.id)>=v_voucher.usage_limit then raise exception 'Voucher quota exhausted'; end if;
  if exists(select 1 from public.voucher_products where voucher_id=v_voucher.id) or exists(select 1 from public.voucher_categories where voucher_id=v_voucher.id) then
    select coalesce(sum((x->>'unit_price')::numeric*(x->>'quantity')::int),0) into v_eligible
    from jsonb_array_elements(v_items) x
    join public.products p on p.id=(x->>'product_id')::uuid
    where exists(select 1 from public.voucher_products vp where vp.voucher_id=v_voucher.id and vp.product_id=p.id)
       or exists(select 1 from public.voucher_categories vc where vc.voucher_id=v_voucher.id and vc.category_id=p.category_id);
  else v_eligible:=v_subtotal; end if;
  if v_eligible<v_voucher.minimum_purchase then raise exception 'Minimum purchase not reached'; end if;
  if v_voucher.discount_type='fixed' then v_discount:=least(v_eligible,v_voucher.discount_value); else v_discount:=v_eligible*(v_voucher.discount_value/100); end if;
  if v_voucher.maximum_discount is not null then v_discount:=least(v_discount,v_voucher.maximum_discount); end if;
 end if;
 v_shipping:=public.calculate_shipping_fee(v_store,p_address_id,p_shipping_method,v_subtotal);
 if v_voucher.id is not null and v_voucher.free_shipping then v_shipping:=0; end if;
 v_total:=greatest(0,v_subtotal-v_discount+v_shipping);
 return jsonb_build_object('store_id',v_store,'items',v_items,'subtotal',v_subtotal,'discount',v_discount,'shipping',v_shipping,'total',v_total,'voucher_id',v_voucher.id,'voucher_title',v_voucher.title,'shipping_method',p_shipping_method);
end; $$;
revoke all on function public.quote_checkout_v2(uuid,text,text) from public,anon;
grant execute on function public.quote_checkout_v2(uuid,text,text) to authenticated,service_role;

-- Production checkout v2 with campaign pricing, delivery config and expiring reservations
create or replace function public.create_checkout_v2(p_address_id uuid,p_payment_method text,p_shipping_method text,p_voucher_code text default null,p_notes text default null,p_client_request_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
 v_quote jsonb; v_cart uuid; v_store uuid; v_order uuid; v_order_number text; v_payment uuid; v_due timestamptz; r record; v_inventory uuid; v_campaign uuid; v_price numeric; v_base numeric;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_payment_method not in ('cod','manual_transfer') then raise exception 'Unsupported payment method'; end if;
 if p_client_request_id is not null then
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':'||p_client_request_id::text,0));
  select id into v_order from public.orders where user_id=auth.uid() and client_request_id=p_client_request_id;
  if v_order is not null then return v_order; end if;
 end if;
 v_quote:=public.quote_checkout_v2(p_address_id,p_shipping_method,p_voucher_code);
 v_store:=(v_quote->>'store_id')::uuid;
 select id into v_cart from public.carts where user_id=auth.uid();
 if p_payment_method='manual_transfer' then
  select now()+make_interval(mins=>coalesce(manual_payment_timeout_minutes,120)) into v_due from public.store_settings where store_id=v_store;
  v_due:=coalesce(v_due,now()+interval '2 hours');
 end if;
 v_order_number:='SM-'||to_char(now(),'YYYYMMDD')||'-'||lpad(nextval('public.order_number_seq')::text,6,'0');
 insert into public.orders(order_number,user_id,store_id,status,payment_status,payment_method,shipping_method,subtotal,discount_amount,shipping_cost,total_amount,voucher_id,address_snapshot,customer_notes,client_request_id,payment_due_at,reservation_expires_at)
 select v_order_number,auth.uid(),v_store,'pending_payment','pending',p_payment_method,p_shipping_method,
  (v_quote->>'subtotal')::numeric,(v_quote->>'discount')::numeric,(v_quote->>'shipping')::numeric,(v_quote->>'total')::numeric,
  nullif(v_quote->>'voucher_id','')::uuid,(select to_jsonb(a.*) from public.addresses a where a.id=p_address_id and a.user_id=auth.uid()),p_notes,p_client_request_id,v_due,v_due
 returning id into v_order;

 for r in
  select ci.*,p.name product_name,p.sku product_sku,p.price base_price,pv.name variant_name,pv.sku variant_sku,pv.price_override
  from public.cart_items ci join public.products p on p.id=ci.product_id left join public.product_variants pv on pv.id=ci.variant_id where ci.cart_id=v_cart
 loop
  select i.id into v_inventory from public.inventory i where i.product_id=r.product_id and ((r.variant_id is null and i.variant_id is null) or i.variant_id=r.variant_id) for update;
  if v_inventory is null or (select available_qty from public.inventory where id=v_inventory)<r.quantity then raise exception 'Stock not enough for %',r.product_name; end if;
  v_base:=coalesce(r.price_override,r.base_price); v_price:=v_base; v_campaign:=null;
  select cp.promo_price,cp.campaign_id into v_price,v_campaign
  from public.campaign_products cp join public.campaigns c on c.id=cp.campaign_id
  where cp.product_id=r.product_id and (cp.variant_id is null or cp.variant_id=r.variant_id) and cp.promo_price is not null
    and c.status='active' and c.starts_at<=now() and (c.ends_at is null or c.ends_at>=now())
    and (cp.quota is null or cp.sold_qty+r.quantity<=cp.quota)
  order by c.priority desc,cp.variant_id is not null desc,cp.promo_price asc limit 1 for update of cp;
  insert into public.order_items(order_id,product_id,variant_id,product_name,variant_name,sku,unit_price,quantity,subtotal,original_unit_price,campaign_id)
  values(v_order,r.product_id,r.variant_id,r.product_name,r.variant_name,coalesce(r.variant_sku,r.product_sku),v_price,r.quantity,v_price*r.quantity,v_base,v_campaign);
  update public.inventory set available_qty=available_qty-r.quantity,reserved_qty=reserved_qty+case when p_payment_method='manual_transfer' then r.quantity else 0 end where id=v_inventory;
  insert into public.inventory_reservations(order_id,product_id,variant_id,quantity,status,expires_at)
  values(v_order,r.product_id,r.variant_id,r.quantity,case when p_payment_method='manual_transfer' then 'active' else 'committed' end,v_due);
  insert into public.inventory_movements(store_id,product_id,variant_id,movement_type,quantity,note,reference_id,actor_id)
  values(v_store,r.product_id,r.variant_id,case when p_payment_method='manual_transfer' then 'reservation' else 'sale' end,-r.quantity,case when p_payment_method='manual_transfer' then 'Checkout reservation' else 'COD sale' end,v_order,auth.uid());
  if v_campaign is not null then update public.campaign_products set sold_qty=sold_qty+r.quantity where campaign_id=v_campaign and product_id=r.product_id and ((variant_id is null and r.variant_id is null) or variant_id=r.variant_id); end if;
 end loop;
 insert into public.payments(order_id,method,status,amount) values(v_order,p_payment_method,'pending',(v_quote->>'total')::numeric) returning id into v_payment;
 insert into public.order_status_history(order_id,status,note,actor_id) values(v_order,'pending_payment','Order created',auth.uid());
 if nullif(v_quote->>'voucher_id','') is not null then insert into public.voucher_usages(voucher_id,user_id,order_id,discount_amount) values((v_quote->>'voucher_id')::uuid,auth.uid(),v_order,(v_quote->>'discount')::numeric); end if;
 insert into public.shipments(order_id,store_id,shipping_method,provider,status,internal_delivery_code)
 values(v_order,v_store,p_shipping_method,case when p_shipping_method='pickup' then 'store_pickup' else 'internal' end,'pending','DLV-'||upper(substr(replace(v_order::text,'-',''),1,10)));
 insert into public.shipment_events(shipment_id,status,description,actor_id)
 select id,'pending','Fulfillment created',auth.uid() from public.shipments where order_id=v_order;
 delete from public.cart_items where cart_id=v_cart;
 if p_payment_method='cod' then
  update public.orders set status='confirmed' where id=v_order;
  insert into public.order_status_history(order_id,status,note,actor_id) values(v_order,'confirmed','COD order confirmed',auth.uid());
 end if;
 return v_order;
end; $$;
revoke all on function public.create_checkout_v2(uuid,text,text,text,text,uuid) from public,anon;
grant execute on function public.create_checkout_v2(uuid,text,text,text,text,uuid) to authenticated,service_role;

-- Expire abandoned manual-transfer orders and release reservations
create or replace function public.expire_unpaid_orders()
returns integer language plpgsql security definer set search_path=public as $$
declare o record; r record; v_count int:=0;
begin
 if auth.uid() is not null and not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
 for o in select * from public.orders where payment_method='manual_transfer' and status='pending_payment' and payment_status='pending' and payment_due_at is not null and payment_due_at<now() for update loop
  for r in select * from public.inventory_reservations where order_id=o.id and status='active' for update loop
   update public.inventory set available_qty=available_qty+r.quantity,reserved_qty=greatest(0,reserved_qty-r.quantity) where product_id=r.product_id and ((r.variant_id is null and variant_id is null) or variant_id=r.variant_id);
   update public.inventory_reservations set status='expired',updated_at=now() where id=r.id;
   insert into public.inventory_movements(store_id,product_id,variant_id,movement_type,quantity,note,reference_id) values(o.store_id,r.product_id,r.variant_id,'release',r.quantity,'Payment reservation expired',o.id);
  end loop;
  update public.campaign_products cp set sold_qty=greatest(0,cp.sold_qty-oi.quantity) from public.order_items oi where oi.order_id=o.id and oi.campaign_id=cp.campaign_id and oi.product_id=cp.product_id and ((oi.variant_id is null and cp.variant_id is null) or oi.variant_id=cp.variant_id);
  update public.orders set status='cancelled',payment_status='expired',updated_at=now() where id=o.id;
  update public.payments set status='expired',updated_at=now() where order_id=o.id;
  insert into public.order_status_history(order_id,status,note) values(o.id,'cancelled','Payment deadline expired');
  v_count:=v_count+1;
 end loop;
 return v_count;
end; $$;
revoke all on function public.expire_unpaid_orders() from public,anon,authenticated;
grant execute on function public.expire_unpaid_orders() to service_role;

-- Manual transfer proof workflow
create or replace function public.submit_manual_payment_proof(p_order_id uuid,p_proof_path text,p_bank_name text default null,p_payer_name text default null,p_amount numeric default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_payment uuid; v_id uuid; v_order public.orders%rowtype;
begin
 select * into v_order from public.orders where id=p_order_id and user_id=auth.uid() for update;
 if v_order.id is null then raise exception 'Order not found'; end if;
 if v_order.payment_method<>'manual_transfer' or v_order.payment_status<>'pending' or v_order.status<>'pending_payment' then raise exception 'Payment proof is not allowed for this order'; end if;
 if v_order.payment_due_at is not null and v_order.payment_due_at<now() then raise exception 'Payment deadline expired'; end if;
 select id into v_payment from public.payments where order_id=p_order_id;
 insert into public.manual_payment_proofs(payment_id,order_id,user_id,proof_path,bank_name,payer_name,amount)
 values(v_payment,p_order_id,auth.uid(),p_proof_path,nullif(btrim(coalesce(p_bank_name,'')),''),nullif(btrim(coalesce(p_payer_name,'')),''),p_amount) returning id into v_id;
 insert into public.notifications(user_id,type,title,body,data) values(auth.uid(),'payment','Bukti pembayaran terkirim','Bukti transfer sedang diverifikasi.',jsonb_build_object('order_id',p_order_id));
 return v_id;
end; $$;
revoke all on function public.submit_manual_payment_proof(uuid,text,text,text,numeric) from public,anon;
grant execute on function public.submit_manual_payment_proof(uuid,text,text,text,numeric) to authenticated,service_role;

create or replace function public.verify_manual_payment_proof(p_proof_id uuid,p_approved boolean,p_note text default null)
returns void language plpgsql security definer set search_path=public as $$
declare v public.manual_payment_proofs%rowtype; o public.orders%rowtype;
begin
 select * into v from public.manual_payment_proofs where id=p_proof_id for update;
 if v.id is null then raise exception 'Proof not found'; end if;
 select * into o from public.orders where id=v.order_id for update;
 if not public.is_store_staff(o.store_id) then raise exception 'Not authorized'; end if;
 if v.status<>'pending' then raise exception 'Proof already reviewed'; end if;
 update public.manual_payment_proofs set status=case when p_approved then 'approved' else 'rejected' end,admin_note=p_note,verified_by=auth.uid(),verified_at=now(),updated_at=now() where id=v.id;
 if p_approved then
  update public.orders set status='paid',payment_status='paid',updated_at=now() where id=o.id;
  update public.payments set status='paid',paid_at=now(),updated_at=now() where id=v.payment_id;
  insert into public.order_status_history(order_id,status,note,actor_id) values(o.id,'paid',coalesce(p_note,'Manual transfer verified'),auth.uid());
  insert into public.notifications(user_id,type,title,body,data) values(o.user_id,'payment','Pembayaran terverifikasi','Pembayaran pesanan '||o.order_number||' sudah diterima.',jsonb_build_object('order_id',o.id));
 else
  insert into public.notifications(user_id,type,title,body,data) values(o.user_id,'payment','Bukti pembayaran ditolak',coalesce(p_note,'Silakan unggah ulang bukti pembayaran yang valid.'),jsonb_build_object('order_id',o.id));
 end if;
end; $$;
revoke all on function public.verify_manual_payment_proof(uuid,boolean,text) from public,anon;
grant execute on function public.verify_manual_payment_proof(uuid,boolean,text) to authenticated,service_role;

-- Shipment update tied to order timeline
create or replace function public.update_shipment_status(p_shipment_id uuid,p_status text,p_description text default null,p_location text default null,p_driver_name text default null,p_driver_phone text default null,p_tracking_number text default null)
returns void language plpgsql security definer set search_path=public as $$
declare s public.shipments%rowtype; o public.orders%rowtype;
begin
 if p_status not in ('pending','assigned','ready_for_pickup','picked_up','in_transit','failed_attempt','delivered','cancelled') then raise exception 'Invalid shipment status'; end if;
 select * into s from public.shipments where id=p_shipment_id for update;
 if s.id is null then raise exception 'Shipment not found'; end if;
 select * into o from public.orders where id=s.order_id;
 if not public.is_store_staff(o.store_id) then raise exception 'Not authorized'; end if;
 update public.shipments set status=p_status,driver_name=coalesce(nullif(btrim(coalesce(p_driver_name,'')),''),driver_name),driver_phone=coalesce(nullif(btrim(coalesce(p_driver_phone,'')),''),driver_phone),tracking_number=coalesce(nullif(btrim(coalesce(p_tracking_number,'')),''),tracking_number),picked_up_at=case when p_status in ('picked_up','in_transit') and picked_up_at is null then now() else picked_up_at end,delivered_at=case when p_status='delivered' then now() else delivered_at end,updated_at=now() where id=s.id;
 insert into public.shipment_events(shipment_id,status,description,location,actor_id) values(s.id,p_status,p_description,p_location,auth.uid());
 if p_status in ('picked_up','in_transit') and o.status='ready_to_ship' then perform public.admin_update_order_status(o.id,'shipped',coalesce(p_description,'Shipment picked up')); end if;
 if p_status='delivered' and o.status='shipped' then perform public.admin_update_order_status(o.id,'delivered',coalesce(p_description,'Shipment delivered')); end if;
 insert into public.notifications(user_id,type,title,body,data) values(o.user_id,'shipping','Update pengiriman',coalesce(p_description,'Status pengiriman: '||replace(p_status,'_',' ')),jsonb_build_object('order_id',o.id,'shipment_id',s.id,'status',p_status));
end; $$;
revoke all on function public.update_shipment_status(uuid,text,text,text,text,text,text) from public,anon;
grant execute on function public.update_shipment_status(uuid,text,text,text,text,text,text) to authenticated,service_role;

-- Item-level returns
create or replace function public.request_return_v2(p_order_id uuid,p_reason text,p_description text,p_resolution text,p_items jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare o public.orders%rowtype; v_return uuid; x jsonb; oi public.order_items%rowtype; v_qty int; v_window int;
begin
 select * into o from public.orders where id=p_order_id and user_id=auth.uid() for update;
 if o.id is null then raise exception 'Order not found'; end if;
 if o.status not in ('delivered','completed') then raise exception 'Order is not eligible for return'; end if;
 select return_window_days into v_window from public.store_settings where store_id=o.store_id;
 if now()>o.updated_at+make_interval(days=>coalesce(v_window,7)) then raise exception 'Return window has expired'; end if;
 if p_items is null or jsonb_array_length(p_items)=0 then raise exception 'Select at least one item'; end if;
 if exists(select 1 from public.returns where order_id=o.id and status not in ('rejected','closed')) then raise exception 'An active return already exists for this order'; end if;
 insert into public.returns(order_id,user_id,reason,description,requested_resolution,expires_at)
 values(o.id,auth.uid(),btrim(p_reason),nullif(btrim(coalesce(p_description,'')),''),p_resolution,now()+interval '14 days') returning id into v_return;
 for x in select * from jsonb_array_elements(p_items) loop
  select * into oi from public.order_items where id=(x->>'order_item_id')::uuid and order_id=o.id;
  if oi.id is null then raise exception 'Invalid return item'; end if;
  v_qty:=(x->>'quantity')::int;
  if v_qty<1 or v_qty>oi.quantity then raise exception 'Invalid return quantity'; end if;
  insert into public.return_items(return_id,order_item_id,quantity,reason,resolution) values(v_return,oi.id,v_qty,nullif(x->>'reason',''),p_resolution);
 end loop;
 update public.orders set status='return_requested',updated_at=now() where id=o.id;
 insert into public.order_status_history(order_id,status,note,actor_id) values(o.id,'return_requested',p_reason,auth.uid());
 return v_return;
end; $$;
revoke all on function public.request_return_v2(uuid,text,text,text,jsonb) from public,anon;
grant execute on function public.request_return_v2(uuid,text,text,text,jsonb) to authenticated,service_role;

-- Discovery helpers
create or replace function public.record_product_view(p_product_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null then return; end if;
 if not exists(select 1 from public.products where id=p_product_id and status='active') then return; end if;
 insert into public.product_views(user_id,product_id) values(auth.uid(),p_product_id);
 delete from public.product_views where user_id=auth.uid() and id not in (select id from public.product_views where user_id=auth.uid() order by viewed_at desc limit 200);
end; $$;
revoke all on function public.record_product_view(uuid) from public,anon;
grant execute on function public.record_product_view(uuid) to authenticated,service_role;

create or replace function public.search_products_v2(p_query text default null,p_category_id uuid default null,p_min_price numeric default null,p_max_price numeric default null,p_min_rating numeric default null,p_sort text default 'relevance',p_limit int default 30,p_offset int default 0)
returns setof public.products
language sql stable security definer set search_path=public as $$
 select p.* from public.products p
 where p.status='active'
   and (p_category_id is null or p.category_id=p_category_id)
   and (p_min_price is null or p.price>=p_min_price)
   and (p_max_price is null or p.price<=p_max_price)
   and (p_min_rating is null or p.rating_average>=p_min_rating)
   and (coalesce(btrim(p_query),'')='' or p.name ilike '%'||btrim(p_query)||'%' or coalesce(p.description,'') ilike '%'||btrim(p_query)||'%' or similarity(p.name,btrim(p_query))>0.2)
 order by
  case when p_sort='price_asc' then p.price end asc,
  case when p_sort='price_desc' then p.price end desc,
  case when p_sort='sold' then p.sold_count end desc,
  case when p_sort='rating' then p.rating_average end desc,
  case when p_sort='newest' then extract(epoch from p.created_at) end desc,
  case when p_sort='relevance' and coalesce(btrim(p_query),'')<>'' then similarity(p.name,btrim(p_query)) end desc,
  p.created_at desc
 limit greatest(1,least(coalesce(p_limit,30),100)) offset greatest(0,coalesce(p_offset,0));
$$;
revoke all on function public.search_products_v2(text,uuid,numeric,numeric,numeric,text,int,int) from public;
grant execute on function public.search_products_v2(text,uuid,numeric,numeric,numeric,text,int,int) to anon,authenticated,service_role;

-- Warehouse stocktake completion
create or replace function public.complete_stocktake(p_stocktake_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare s public.stocktakes%rowtype; x record; v_inv public.inventory%rowtype;
begin
 select * into s from public.stocktakes where id=p_stocktake_id for update;
 if s.id is null or not public.is_store_staff(s.store_id) then raise exception 'Not authorized'; end if;
 if s.status='completed' then return; end if;
 if exists(select 1 from public.stocktake_items where stocktake_id=s.id and counted_qty is null) then raise exception 'All items must be counted'; end if;
 for x in select * from public.stocktake_items where stocktake_id=s.id loop
  select * into v_inv from public.inventory where product_id=x.product_id and ((x.variant_id is null and variant_id is null) or variant_id=x.variant_id) for update;
  if v_inv.id is null then raise exception 'Inventory missing'; end if;
  if x.counted_qty<0 then raise exception 'Invalid counted quantity'; end if;
  if x.counted_qty<>v_inv.available_qty then
   update public.inventory set available_qty=x.counted_qty,updated_at=now() where id=v_inv.id;
   insert into public.inventory_movements(store_id,product_id,variant_id,movement_type,quantity,note,reference_id,actor_id) values(s.store_id,x.product_id,x.variant_id,'adjustment',x.counted_qty-v_inv.available_qty,'Stocktake adjustment',s.id,auth.uid());
  end if;
 end loop;
 update public.stocktakes set status='completed',completed_at=now() where id=s.id;
end; $$;
revoke all on function public.complete_stocktake(uuid) from public,anon;
grant execute on function public.complete_stocktake(uuid) to authenticated,service_role;

-- Analytics
create or replace function public.superadmin_commerce_analytics(p_days int default 30)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare v_since timestamptz:=now()-make_interval(days=>greatest(1,least(coalesce(p_days,30),365))); v jsonb;
begin
 if not public.is_platform_super_admin() then raise exception 'Not authorized'; end if;
 select jsonb_build_object(
  'since',v_since,
  'orders',count(*),
  'paid_orders',count(*) filter(where payment_status='paid'),
  'revenue',coalesce(sum(total_amount) filter(where payment_status='paid'),0),
  'aov',coalesce(avg(total_amount) filter(where payment_status='paid'),0),
  'cancelled',count(*) filter(where status='cancelled'),
  'completed',count(*) filter(where status='completed'),
  'customers',count(distinct user_id)
 ) into v from public.orders where created_at>=v_since;
 return v||jsonb_build_object(
  'top_products',coalesce((select jsonb_agg(t) from (select product_name,sum(quantity) qty,sum(subtotal) sales from public.order_items oi join public.orders o on o.id=oi.order_id where o.created_at>=v_since and o.status<>'cancelled' group by product_name order by qty desc limit 10)t),'[]'::jsonb),
  'return_count',(select count(*) from public.returns where created_at>=v_since),
  'new_users',(select count(*) from public.profiles where created_at>=v_since),
  'low_stock',(select count(*) from public.inventory where available_qty<=low_stock_threshold)
 );
end; $$;
revoke all on function public.superadmin_commerce_analytics(int) from public,anon;
grant execute on function public.superadmin_commerce_analytics(int) to authenticated,service_role;

-- Reservation/campaign bookkeeping trigger for existing cancellation/confirmation functions
create or replace function public.sync_order_reservations_after_status()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.status='confirmed' and old.status='paid' then update public.inventory_reservations set status='committed',updated_at=now() where order_id=new.id and status='active'; end if;
 if new.status='cancelled' and old.status<>'cancelled' then
  update public.inventory_reservations set status='released',updated_at=now() where order_id=new.id and status='active';
  update public.campaign_products cp set sold_qty=greatest(0,cp.sold_qty-oi.quantity) from public.order_items oi where oi.order_id=new.id and oi.campaign_id=cp.campaign_id and oi.product_id=cp.product_id and ((oi.variant_id is null and cp.variant_id is null) or oi.variant_id=cp.variant_id);
 end if;
 return new;
end; $$;
drop trigger if exists trg_sync_order_reservations_after_status on public.orders;
create trigger trg_sync_order_reservations_after_status after update of status on public.orders for each row when (old.status is distinct from new.status) execute function public.sync_order_reservations_after_status();

-- Product rating summary trigger
create or replace function public.refresh_product_rating()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_product uuid:=coalesce(new.product_id,old.product_id);
begin
 update public.products p set rating_average=coalesce((select round(avg(r.rating)::numeric,2) from public.reviews r where r.product_id=v_product and r.is_approved),0),rating_count=(select count(*) from public.reviews r where r.product_id=v_product and r.is_approved),updated_at=now() where p.id=v_product;
 return coalesce(new,old);
end; $$;
drop trigger if exists trg_refresh_product_rating on public.reviews;
create trigger trg_refresh_product_rating after insert or update or delete on public.reviews for each row execute function public.refresh_product_rating();

-- Storage buckets
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('payment-proofs','payment-proofs',false,5242880,array['image/jpeg','image/png','image/webp','application/pdf']),
 ('return-evidence','return-evidence',false,8388608,array['image/jpeg','image/png','image/webp','video/mp4','application/pdf']),
 ('review-images','review-images',true,5242880,array['image/jpeg','image/png','image/webp']),
 ('chat-attachments','chat-attachments',false,5242880,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict(id) do update set file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists payment_proofs_owner_insert on storage.objects;
create policy payment_proofs_owner_insert on storage.objects for insert to authenticated with check (bucket_id='payment-proofs' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists payment_proofs_owner_staff_read on storage.objects;
create policy payment_proofs_owner_staff_read on storage.objects for select to authenticated using (bucket_id='payment-proofs' and ((storage.foldername(name))[1]=auth.uid()::text or exists(select 1 from public.manual_payment_proofs mp join public.orders o on o.id=mp.order_id where mp.proof_path=name and public.is_store_staff(o.store_id))));
drop policy if exists return_evidence_owner_insert on storage.objects;
create policy return_evidence_owner_insert on storage.objects for insert to authenticated with check (bucket_id='return-evidence' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists return_evidence_owner_staff_read on storage.objects;
create policy return_evidence_owner_staff_read on storage.objects for select to authenticated using (bucket_id='return-evidence' and ((storage.foldername(name))[1]=auth.uid()::text or exists(select 1 from public.return_evidence re join public.returns r on r.id=re.return_id join public.orders o on o.id=r.order_id where re.file_path=name and public.is_store_staff(o.store_id))));
drop policy if exists review_images_owner_insert on storage.objects;
create policy review_images_owner_insert on storage.objects for insert to authenticated with check (bucket_id='review-images' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists chat_attachments_owner_insert on storage.objects;
create policy chat_attachments_owner_insert on storage.objects for insert to authenticated with check (bucket_id='chat-attachments' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists chat_attachments_participant_read on storage.objects;
create policy chat_attachments_participant_read on storage.objects for select to authenticated using (bucket_id='chat-attachments' and ((storage.foldername(name))[1]=auth.uid()::text or exists(select 1 from public.messages m join public.conversations c on c.id=m.conversation_id where m.metadata->>'attachment_path'=name and (c.customer_id=auth.uid() or public.is_store_staff(c.store_id)))));

-- Seed app setting for feature surface
insert into public.app_settings(key,value,is_public) values('commerce_features','{"shipping_tracking":true,"variants":true,"checkout_quote":true,"manual_payment_proof":true,"returns_v2":true,"advanced_search":true,"campaigns":true,"warehouse":true,"analytics":true,"push_ready":true}'::jsonb,true)
on conflict(key) do update set value=excluded.value,updated_at=now();