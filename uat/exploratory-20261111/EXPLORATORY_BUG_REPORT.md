# Exploratory Bug Report — 2026-11-11

## EXP-DEF-031 — Flutter lifecycle assertion (REPRODUCED)

- Scenario: EXP-002 catalog/filter/detail.
- Device: Xiaomi `nnzxea79ayypnzzx`.
- Actual: recovery screen displayed `Failed assertion: line 6281 pos 12:
  '_dependents.isEmpty': is not true.`
- Impact: exploratory catalog flow could not reach search/filter/detail.
- Evidence: live MCP screenshot captured at failure time; prior persistent
  evidence remains in `../evidence/screenshots/uat-admin-product-create-form.png`,
  `../evidence/screenshots/uat-admin-product-edit-form.png`, and the diagnosis log.
- Classification: Flutter runtime/application failure, not a selector-only failure.

## EXP-DEF-032 — Invalid voucher technical error disclosure (REPRODUCED)

- Scenario: EXP-007 invalid voucher.
- Input: `INVALID-UAT-20261111`.
- Actual: snackbar displayed `PostgrestException` with code `P0001` and
  `Voucher invalid or expired`.
- Expected: safe customer-facing rejection message; checkout total remains
  verifiably unchanged.
- Impact: backend implementation details are exposed; total invariant was not
  verifiable in this run because the keyboard/snackbar obscured the lower area.
- Evidence: `evidence/exploratory-20261111-exp007-invalid-voucher.png`.

## EXP-DEF-034 — Unexpected COD order from checkout recovery (OBSERVED)

- Scenario: EXP-004 checkout read-only / EXP-010 cleanup.
- Actual: without an intended submit step in the planned flow, a confirmation
  dialog appeared showing `BE554C77`, subtotal Rp35.000, delivery Rp5.000, and
  total Rp40.000. The order list identified the newest matching order as
  `SM-20261111-000016`, status `Dikonfirmasi`.
- Cleanup: only that newest matching order was cancelled through the UI. The
  order list subsequently showed `Dibatalkan`; no other order was changed.
- Impact: checkout state or recovery interaction can cause an unintended
  order mutation, and the confirmation/list identifiers are inconsistent.
- Evidence: `evidence/exploratory-20261111-exp010-unintended-order.png`,
  `evidence/exploratory-20261111-exp010-order-list-before-cancel.png`,
  `evidence/exploratory-20261111-exp010-cancel-dialog.png`, and
  `evidence/exploratory-20261111-exp010-cancel-result.png`.
- Classification: application behavior / state-management defect; exact
  triggering interaction is not proven in this session.
