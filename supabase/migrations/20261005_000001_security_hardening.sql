begin;

alter table public.orders add column if not exists client_request_id uuid;
create unique index if not exists orders_user_request_uq
  on public.orders(user_id, client_request_id)
  where client_request_id is not null;

drop policy if exists orders_staff_update on public.orders;
revoke insert, update, delete, truncate on table public.orders from anon, authenticated;
grant select on table public.orders to authenticated;

drop policy if exists inventory_manage on public.inventory;
revoke insert, update, delete, truncate on table public.inventory from anon, authenticated;
grant select on table public.inventory to anon, authenticated;

revoke insert, update, delete, truncate on table public.inventory_movements from anon, authenticated;
grant select on table public.inventory_movements to authenticated;

revoke insert, update, delete, truncate on table public.carts from anon, authenticated;
revoke insert, update, delete, truncate on table public.cart_items from anon, authenticated;
grant select on table public.carts, public.cart_items to authenticated;

revoke all on function public.claim_initial_owner() from public, anon, authenticated;

drop policy if exists reviews_owner_insert on public.reviews;
drop policy if exists reviews_owner_update on public.reviews;
revoke insert, update, delete, truncate on table public.reviews from anon, authenticated;
grant select on table public.reviews to anon, authenticated;

create or replace function public.submit_review(
  p_order_item_id uuid,
  p_product_id uuid,
  p_rating integer,
  p_comment text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_user uuid;
  v_order_status text;
  v_item_product uuid;
  v_review_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_rating < 1 or p_rating > 5 then raise exception 'Rating must be between 1 and 5'; end if;

  select o.user_id, o.status, oi.product_id
  into v_order_user, v_order_status, v_item_product
  from public.order_items oi
  join public.orders o on o.id = oi.order_id
  where oi.id = p_order_item_id;

  if v_order_user is null
     or v_order_user <> auth.uid()
     or v_order_status <> 'completed'
     or v_item_product is distinct from p_product_id then
    raise exception 'Review is not allowed for this product';
  end if;

  insert into public.reviews(user_id, product_id, order_item_id, rating, comment, is_approved)
  values(auth.uid(), p_product_id, p_order_item_id, p_rating, nullif(btrim(p_comment), ''), true)
  on conflict (order_item_id) do update
    set rating = excluded.rating,
        comment = excluded.comment,
        updated_at = now()
    where public.reviews.user_id = auth.uid()
  returning id into v_review_id;

  if v_review_id is null then raise exception 'Review cannot be updated'; end if;
  return v_review_id;
end;
$$;

revoke all on function public.submit_review(uuid, uuid, integer, text) from public, anon;
grant execute on function public.submit_review(uuid, uuid, integer, text) to authenticated;

create or replace function public.refresh_product_rating()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product uuid := coalesce(new.product_id, old.product_id);
begin
  update public.products p
  set rating_average = coalesce((
        select round(avg(r.rating)::numeric, 2)
        from public.reviews r
        where r.product_id = v_product and r.is_approved
      ), 0),
      rating_count = (
        select count(*)::integer
        from public.reviews r
        where r.product_id = v_product and r.is_approved
      )
  where p.id = v_product;
  return coalesce(new, old);
end;
$$;

revoke all on function public.refresh_product_rating() from public, anon, authenticated;
drop trigger if exists reviews_refresh_product_rating on public.reviews;
create trigger reviews_refresh_product_rating
after insert or update or delete on public.reviews
for each row execute function public.refresh_product_rating();

commit;
