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
| UAT-021 | PASS | `uat-validation-empty-search.png` |
| UAT-029 | PASS | `uat-transaction-checkout.png` |
| REG-001 | PASS | `uat-transaction-checkout.png` |
| UAT-040 | BLOCKED | `uat-transaction-checkout.png` |
| UAT-045 | BLOCKED | `uat-invalid-voucher.png` |
| UAT-036 | FAIL | `uat-address-form-filled.png`, `uat-address-save-attempt.png`, `uat-address-create-failed.png` |
| UAT-060 | PASS | `uat-admin-product-create-form.png`, `uat-admin-product-read.png` |
| UAT-063 | PASS | `uat-admin-product-edit-form.png`, `uat036_diagnosis_and_admin_crud_20261108-1355.log` |
| UAT-064 | PASS | `uat-admin-product-archive-attempt.png` |

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

Evidence audit corrections:
- UAT-045 shows `PostgrestException P0001: Voucher invalid or expired`; the
  voucher was rejected, but the technical error leaked into the UI and the
  post-rejection total was not verified. It remains BLOCKED.
- UAT-029 screenshot evidence shows quantity/subtotal pairs 5/Rp175.000 and
  8/Rp280.000, plus checkout quantity 6. No automated subtotal assertion was run.
- REG-001 has a checkout screenshot, but a clear total section/assertion is not
  available; it remains baseline PASS with an evidence-gap qualifier.
- `uat-admin-product-update-result.png` does not exist and is not evidence.

Final audit workbook: `uat/KKMP_Kerten_UAT_136_Kasus_synced_20261110.xlsx`.
The workbook preserves historical columns and marks UAT-023, UAT-029, UAT-060,
UAT-063, and UAT-064 as execution PASS with explicit partial-sign-off qualifiers.
