alter table public.campaign_products
  add column if not exists id uuid default gen_random_uuid();

alter table public.campaign_products
  drop constraint if exists campaign_products_pkey;

update public.campaign_products
set id=gen_random_uuid()
where id is null;

alter table public.campaign_products
  alter column id set not null;

alter table public.campaign_products
  add constraint campaign_products_pkey primary key (id);

alter table public.campaign_products
  alter column variant_id drop not null;

create unique index if not exists campaign_products_base_uidx
  on public.campaign_products(campaign_id, product_id)
  where variant_id is null;

create unique index if not exists campaign_products_variant_uidx
  on public.campaign_products(campaign_id, product_id, variant_id)
  where variant_id is not null;
