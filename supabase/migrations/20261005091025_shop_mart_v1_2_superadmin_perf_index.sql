create index if not exists platform_admins_created_by_idx
  on public.platform_admins(created_by)
  where created_by is not null;
