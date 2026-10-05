begin;

-- Customer/admin after-sales mutations are RPC-only.
drop policy if exists returns_owner_create on public.returns;
drop policy if exists returns_staff_update on public.returns;
revoke insert, update, delete, truncate on table public.returns from anon, authenticated;
grant select on table public.returns to authenticated;

drop policy if exists refunds_staff_manage on public.refunds;
revoke insert, update, delete, truncate on table public.refunds from anon, authenticated;
grant select on table public.refunds to authenticated;

-- Ensure an order-level refund also has a durable refund ledger row.
create or replace function public.record_completed_order_refund()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status='refunded' and old.status is distinct from new.status then
    if not exists(
      select 1 from public.refunds
      where order_id=new.id and status='completed'
    ) then
      insert into public.refunds(order_id,amount,status,note,completed_at)
      values(new.id,new.total_amount,'completed','Order refund completed',now());
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.record_completed_order_refund() from public, anon, authenticated;
drop trigger if exists orders_record_completed_refund on public.orders;
create trigger orders_record_completed_refund
after update of status on public.orders
for each row execute function public.record_completed_order_refund();

commit;
