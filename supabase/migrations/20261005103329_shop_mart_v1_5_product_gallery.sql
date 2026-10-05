alter table public.product_images
  add column if not exists storage_path text;

create unique index if not exists product_images_storage_path_uidx
  on public.product_images(storage_path)
  where storage_path is not null;

create index if not exists product_images_product_sort_idx
  on public.product_images(product_id, sort_order, created_at);
