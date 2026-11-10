# KKMP Kerten UAT Execution Report

Date: 2026-11-08 (Asia/Jakarta)

## Environment

- App: KKMP Kerten 1.5.4+8
- Android application ID: `com.fauzibondanp.shopmart`
- Device: `nnzxea79ayypnzzx` (physical Android device)
- Emulator/cloud: not used
- Existing Flutter/Supabase data and login session: preserved

## UAT source availability

No Excel file (`.xlsx` or `.xls`) or CSV containing the requested 136 UAT cases was found in the workspace. Therefore, no official UAT case IDs or unexecuted-case results are fabricated. The 136-case mapping remains **NOT RUN / BLOCKED — source file unavailable** until the workbook is provided.

## Executed smoke/regression checks

| Internal check | Status | Evidence / notes |
|---|---|---|
| STARTUP-001 | PASS | App opened on the physical device; home title/tagline and catalog surface were visible. |
| CUSTOMER-001 | PASS | Home catalog and category surface verified; Account opened without changing the existing session. |
| SEARCH-001 | PASS | Search screen opened, query `beras` entered, and results were displayed. |
| CART-001 | PASS | Keranjang opened in the existing authenticated session; no item quantity or data was changed. |
| ORDERS-001 | PASS | `Pesanan Saya` opened and existing orders were displayed; no order was changed. |
| ACCOUNT-001 | PASS | Account screen showed the existing Super Admin session and navigation entry. |
| SUPERADMIN-001 | PASS | Super Admin dashboard opened; `Platform Control Center` and read-only metrics were visible. |
| CHECKOUT-001 | BLOCKED | No checkout/final order was performed because it could create a real order and the request forbids destructive/transactional actions. |
| ADMIN-001 | NOT RUN | No separate approved admin test account/session was established; role changes and login actions were not attempted. |
| ERRORLOG-001 | NOT RUN | Error Log Center was not opened because it requires Super Admin navigation and the requested run was limited to non-destructive smoke coverage. |

## Observed flow issues

- Initial selectors using `KKMP Kerten`, `Kategori`, and tab labels were ambiguous or incomplete because Android accessibility labels concatenate secondary text (for example, `Kategori\n5 kategori` and `Pesanan\nTab 4 of 5`). The reusable flows were corrected to wait for the in-app tagline and use anchored regular-expression selectors.
- `launchApp` alone did not reliably move the device from the launcher to the Flutter activity in this setup. The flows use the visible `KKMP Kerten` launcher icon and do not clear state.
- These are test-flow synchronization/selector findings, not confirmed application defects.

## Not run / requires manual approval

- Checkout confirmation and order creation.
- Payment, delivery, stock, product, promotion, return, support, and other admin mutations.
- Logout, clear state, account changes, role changes, deletion, and data reset.
- Official mapping of all 136 UAT cases until the Excel workbook is available.
