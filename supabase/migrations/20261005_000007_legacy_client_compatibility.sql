begin;

-- Older Shop Mart clients called this RPC after login. Keep the endpoint harmless
-- so those clients can still sign in while removing the owner-escalation behavior.
create or replace function public.claim_initial_owner()
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select false;
$$;

revoke all on function public.claim_initial_owner() from public, anon;
grant execute on function public.claim_initial_owner() to authenticated;

commit;
