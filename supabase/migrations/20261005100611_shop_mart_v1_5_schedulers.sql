create extension if not exists pg_cron;

do $$
begin
  if exists(select 1 from cron.job where jobname='shop_mart_expire_unpaid_orders') then
    perform cron.unschedule('shop_mart_expire_unpaid_orders');
  end if;
end $$;

select cron.schedule(
  'shop_mart_expire_unpaid_orders',
  '*/10 * * * *',
  $$select public.expire_unpaid_orders();$$
);
