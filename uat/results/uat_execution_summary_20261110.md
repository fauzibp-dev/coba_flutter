# UAT Execution Summary — KKMP Kerten 1.5.4+8

- Source: `uat/KKMP_Kerten_UAT_136_Kasus.xlsx`
- Device: physical Xiaomi `nnzxea79ayypnzzx`
- App ID: `com.fauzibondanp.shopmart`
- Run date: 2026-11-08 Asia/Jakarta
- Scope: Maestro MCP, non-emulator/non-cloud.

| Status | Count |
|---|---:|
| PASS | 14 |
| FAIL | 1 |
| BLOCKED | 3 |
| NOT RUN | 118 |
| **Total** | **136** |

## Newly executed evidence

| ID | Status | Evidence |
|---|---|---|
| UAT-021 | PASS | `../evidence/screenshots/uat-validation-empty-search.png` |
| UAT-029 | PASS | `../evidence/screenshots/uat-cart-plus-attempt.png`, `../evidence/screenshots/uat-cart-plus-second-attempt.png`, `../evidence/screenshots/uat-transaction-checkout.png` |
| REG-001 | PASS | `../evidence/screenshots/uat-transaction-checkout.png` |
| UAT-040 | BLOCKED | `../evidence/screenshots/uat-transaction-checkout.png` |
| UAT-045 | BLOCKED | `../evidence/screenshots/uat-invalid-voucher.png` |
| UAT-036 | FAIL | `../evidence/screenshots/uat-address-form-filled.png`, `../evidence/screenshots/uat-address-save-attempt.png`, `../evidence/screenshots/uat-address-create-failed.png` |
| UAT-060 | PASS | `../evidence/screenshots/uat-admin-product-create-form.png`, `../evidence/screenshots/uat-admin-product-read.png` |
| UAT-063 | PASS | `../evidence/screenshots/uat-admin-product-edit-form.png`, `uat036_diagnosis_and_admin_crud_20261108-1355.log` |
| UAT-064 | PASS | `../evidence/screenshots/uat-admin-product-archive-attempt.png` |

The transaction flow added/updated a cart item and reached checkout with COD, but did not submit a final order because a verified fictitious address was not available.

The UAT-036 address creation action was executed with all required fields filled.
After saving, the new `UAT_TEST` address was absent from the address list. This is
recorded as FAIL, not BLOCKED, because the expected persisted result was not
observed after the required UI action.

Independent Super Admin CRUD was executed without depending on the address flow:
UAT_TEST_PRODUK_20261108 was created and read, its price was updated from
Rp10.000 to Rp11.000, and it was archived after verification. The application
does not expose a product-delete control in the Super Admin UI or repository, so
direct database deletion was intentionally not performed. During save, Flutter
also displayed a framework assertion (`_dependents.isEmpty`); database and
catalog evidence show the mutations nevertheless completed.

Final audit workbook: `uat/KKMP_Kerten_UAT_136_Kasus_synced_20261110.xlsx`.
The workbook preserves historical columns and marks UAT-023, UAT-029, UAT-060,
UAT-063, UAT-064, UAT-082, REG-001, and REG-013 as execution PASS with
explicit partial-sign-off qualifiers. UAT-029 screenshot evidence proves the
numeric quantity/subtotal pairs; no automated subtotal assertion was run.

Voucher audit: `INVALID-UAT` was visibly rejected with
`PostgrestException P0001: Voucher invalid or expired`; the rejection response
was visible but technically exposed, and the post-rejection total was not
verified.
