alter policy product_images_manage on public.product_images
  using (
    public.is_platform_super_admin()
    or exists (
      select 1 from public.products p
      where p.id = product_images.product_id
        and public.is_store_staff(p.store_id)
    )
  )
  with check (
    public.is_platform_super_admin()
    or exists (
      select 1 from public.products p
      where p.id = product_images.product_id
        and public.is_store_staff(p.store_id)
    )
  );
