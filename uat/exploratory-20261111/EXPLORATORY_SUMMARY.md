# Exploratory UAT Summary — 2026-11-11

## Session outcome

Seven scenarios were executed on the required Xiaomi physical device. Six
execution paths reached their planned assertions; one failed on a Flutter
runtime assertion. The unexpected order cleanup was executed separately.

Matrix totals: **4 PASS, 3 qualified PASS, 1 FAIL, 0 BLOCKED, 2 NOT RUN**
(10 planned scenarios). Address CRUD and synthetic product CRUD remain NOT RUN.

## Scope covered

Startup, Home, tab navigation, product search, no-result validation, cart,
checkout COD presentation, account/role visibility, Super Admin dashboard,
invalid-voucher handling, and safe cleanup of the unexpected order.

## Unexpected side effect and cleanup

During recovery from the persisted checkout state, a COD order was created
without an intended submit step. The confirmation showed `BE554C77`; the order
list showed matching details under `SM-20261111-000016` with total Rp40.000.
That exact newest order was cancelled through the UI and verified as
`Dibatalkan`. The identifier discrepancy is documented as EXP-DEF-034.

## Scope not completed

Address CRUD and synthetic Super Admin product CRUD were not performed in this
session. No payment was made. The prior baseline remains separate and unchanged:
**14 PASS, 1 FAIL, 3 BLOCKED, 118 NOT RUN**.

## Artifacts

- YAML: `../../.maestro/exploratory-20261111/`
- Matrix: `EXPLORATORY_UAT_MATRIX.md`
- Detailed execution: `EXPLORATORY_EXECUTION_REPORT.md`
- Bugs: `EXPLORATORY_BUG_REPORT.md`
- Execution log: `logs/maestro_execution_20261111.log`
- Screenshots: `evidence/`
