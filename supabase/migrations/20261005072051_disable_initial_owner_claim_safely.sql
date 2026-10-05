-- Disable client-side first-user owner takeover while keeping older clients compatible.
create or replace function public.claim_initial_owner()
returns boolean
language plpgsql
security definer
set search_path=public
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  -- Owner provisioning is intentionally administration-only in production.
  return false;
end;
$$;

revoke all on function public.claim_initial_owner() from public, anon;
grant execute on function public.claim_initial_owner() to authenticated;
