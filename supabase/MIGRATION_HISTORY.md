# Supabase migration history

Shop Mart production database predates the repository migration directory. The following migrations are already recorded and applied in the Supabase project:

- `20260928085437_shop_mart_production_v1`
- `20260928085529_shop_mart_security_hardening`
- `20260928090804_shop_mart_order_admin_fix`
- `20260928091018_fix_checkout_store_selection`
- `20260928091912_shop_mart_fk_indexes`
- `20260928092412_shop_mart_order_state_machine`
- `20261005070659_shop_mart_v1_1_security_hardening`
- `20261005072051_disable_initial_owner_claim_safely`
- `20261005072319_harden_review_updates`
- `20261005073242_lock_inventory_ledger_writes`
- `20261005081811_revoke_initial_owner_claim_execute`
- `20261005083952_shop_mart_v1_2_superadmin`

The first six entries are the legacy production baseline that was created before database migration files were committed to Git. From v1.1 onward, every database change must be committed under `supabase/migrations/` using the exact Supabase migration version and name before it is merged to `main`.

Do not re-run the legacy baseline against the current production project. For a brand-new environment, export/restore the baseline schema first, then apply the version-controlled v1.1+ migrations in order. No service-role or database credentials belong in this repository.
