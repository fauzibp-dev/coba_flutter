drop policy if exists reviews_owner_update on public.reviews;
create policy reviews_owner_update on public.reviews
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.order_items oi
      join public.orders o on o.id = oi.order_id
      where oi.id = reviews.order_item_id
        and oi.product_id = reviews.product_id
        and o.user_id = (select auth.uid())
        and o.status = 'completed'
    )
  );
