-- Cache auth.uid() once per statement inside RLS policies to avoid
-- per-row auth function re-evaluation reported by the Supabase advisor.

alter policy account_deletion_owner on public.account_deletion_requests
  using ((user_id = (select auth.uid())) or is_platform_super_admin());
alter policy account_deletion_owner_insert on public.account_deletion_requests
  with check (user_id = (select auth.uid()));

alter policy addresses_owner on public.addresses
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
alter policy carts_owner on public.carts
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

alter policy conversations_customer_create on public.conversations
  with check (customer_id = (select auth.uid()));
alter policy conversations_participants on public.conversations
  using ((customer_id = (select auth.uid())) or is_store_staff(store_id));

alter policy device_tokens_owner on public.device_tokens
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

alter policy inventory_reservations_owner_read on public.inventory_reservations
  using (exists (
    select 1 from public.orders o
    where o.id=inventory_reservations.order_id
      and (o.user_id=(select auth.uid()) or is_store_staff(o.store_id))
  ));

alter policy manual_payment_proofs_owner_insert on public.manual_payment_proofs
  with check (
    user_id=(select auth.uid()) and exists (
      select 1 from public.orders o
      where o.id=manual_payment_proofs.order_id
        and o.user_id=(select auth.uid())
        and o.payment_method='manual_transfer'
    )
  );
alter policy manual_payment_proofs_owner_staff_read on public.manual_payment_proofs
  using (
    user_id=(select auth.uid()) or exists (
      select 1 from public.orders o
      where o.id=manual_payment_proofs.order_id and is_store_staff(o.store_id)
    )
  );

alter policy messages_participants_insert on public.messages
  with check (
    sender_id=(select auth.uid()) and exists (
      select 1 from public.conversations c
      where c.id=messages.conversation_id
        and (c.customer_id=(select auth.uid()) or is_store_staff(c.store_id))
    )
  );
alter policy messages_participants_read on public.messages
  using (exists (
    select 1 from public.conversations c
    where c.id=messages.conversation_id
      and (c.customer_id=(select auth.uid()) or is_store_staff(c.store_id))
  ));

alter policy notification_preferences_owner on public.notification_preferences
  using (user_id=(select auth.uid()))
  with check (user_id=(select auth.uid()));
alter policy notifications_owner on public.notifications
  using (user_id=(select auth.uid()))
  with check (user_id=(select auth.uid()));

alter policy order_items_owner_or_staff on public.order_items
  using (exists (
    select 1 from public.orders o
    where o.id=order_items.order_id
      and (o.user_id=(select auth.uid()) or is_store_staff(o.store_id))
  ));
alter policy order_history_read on public.order_status_history
  using (exists (
    select 1 from public.orders o
    where o.id=order_status_history.order_id
      and (o.user_id=(select auth.uid()) or is_store_staff(o.store_id))
  ));
alter policy orders_owner_or_staff on public.orders
  using ((user_id=(select auth.uid())) or is_store_staff(store_id));
alter policy payments_read on public.payments
  using (exists (
    select 1 from public.orders o
    where o.id=payments.order_id
      and (o.user_id=(select auth.uid()) or is_store_staff(o.store_id))
  ));

alter policy product_views_owner on public.product_views
  using (user_id=(select auth.uid()))
  with check (user_id=(select auth.uid()));

alter policy profiles_own_select on public.profiles
  using (
    id=(select auth.uid()) or exists (
      select 1 from public.store_members sm where sm.user_id=(select auth.uid())
    )
  );
alter policy profiles_own_update on public.profiles
  using (id=(select auth.uid()))
  with check (id=(select auth.uid()));

alter policy refunds_owner_or_staff on public.refunds
  using (exists (
    select 1 from public.orders o
    where o.id=refunds.order_id
      and (o.user_id=(select auth.uid()) or is_store_staff(o.store_id))
  ));

alter policy return_evidence_owner_insert on public.return_evidence
  with check (
    uploaded_by=(select auth.uid()) and exists (
      select 1 from public.returns r
      where r.id=return_evidence.return_id and r.user_id=(select auth.uid())
    )
  );
alter policy return_evidence_owner_staff_read on public.return_evidence
  using (exists (
    select 1 from public.returns r
    join public.orders o on o.id=r.order_id
    where r.id=return_evidence.return_id
      and (r.user_id=(select auth.uid()) or is_store_staff(o.store_id))
  ));
alter policy return_items_owner_staff_read on public.return_items
  using (exists (
    select 1 from public.returns r
    join public.orders o on o.id=r.order_id
    where r.id=return_items.return_id
      and (r.user_id=(select auth.uid()) or is_store_staff(o.store_id))
  ));
alter policy returns_owner_create on public.returns
  with check (
    user_id=(select auth.uid()) and exists (
      select 1 from public.orders o
      where o.id=returns.order_id and o.user_id=(select auth.uid())
        and o.status in ('delivered','completed')
    )
  );
alter policy returns_owner_or_staff_read on public.returns
  using (
    user_id=(select auth.uid()) or exists (
      select 1 from public.orders o
      where o.id=returns.order_id and is_store_staff(o.store_id)
    )
  );

alter policy review_votes_owner_write on public.review_helpful_votes
  using (user_id=(select auth.uid()))
  with check (user_id=(select auth.uid()));
alter policy review_images_owner_insert on public.review_images
  with check (exists (
    select 1 from public.reviews r
    where r.id=review_images.review_id and r.user_id=(select auth.uid())
  ));
alter policy review_reports_owner_insert on public.review_reports
  with check (user_id=(select auth.uid()));
alter policy review_reports_owner_staff_read on public.review_reports
  using (
    user_id=(select auth.uid()) or exists (
      select 1 from public.reviews r
      join public.products p on p.id=r.product_id
      where r.id=review_reports.review_id and is_store_staff(p.store_id)
    )
  );

alter policy search_history_owner on public.search_history
  using (user_id=(select auth.uid()))
  with check (user_id=(select auth.uid()));

alter policy shipment_events_owner_staff_read on public.shipment_events
  using (exists (
    select 1 from public.shipments s
    join public.orders o on o.id=s.order_id
    where s.id=shipment_events.shipment_id
      and (o.user_id=(select auth.uid()) or is_store_staff(o.store_id))
  ));
alter policy shipments_owner_staff_read on public.shipments
  using (exists (
    select 1 from public.orders o
    where o.id=shipments.order_id
      and (o.user_id=(select auth.uid()) or is_store_staff(o.store_id))
  ));

alter policy store_members_self_read on public.store_members
  using ((user_id=(select auth.uid())) or is_store_admin(store_id));

alter policy voucher_usages_owner_or_staff on public.voucher_usages
  using (
    user_id=(select auth.uid()) or exists (
      select 1 from public.orders o
      where o.id=voucher_usages.order_id and is_store_staff(o.store_id)
    )
  );

alter policy wishlist_owner on public.wishlists
  using (user_id=(select auth.uid()))
  with check (user_id=(select auth.uid()));
