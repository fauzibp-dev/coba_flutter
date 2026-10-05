drop policy if exists inventory_movements_staff_insert on public.inventory_movements;
revoke insert, update, delete on public.inventory_movements from authenticated;
