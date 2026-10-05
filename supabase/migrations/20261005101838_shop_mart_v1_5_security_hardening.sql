-- Shop Mart v1.5 security hardening
-- Keep public product search available while enforcing caller RLS,
-- and prevent direct invocation of trigger-only helpers.

alter function public.search_products_v2(
  text, uuid, numeric, numeric, numeric, text, integer, integer
) security invoker;

revoke execute on function public.sync_order_reservations_after_status()
  from public, anon, authenticated;

revoke execute on function public.touch_conversation_after_message()
  from public, anon, authenticated;
