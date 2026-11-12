# Exploratory Execution Report — 2026-11-11

## Result

| Status | Count |
|---|---:|
| PASS | 4 |
| PASS* (qualified) | 3 |
| FAIL | 1 |
| BLOCKED | 0 |
| NOT RUN | 2 |
| **Scenarios in matrix** | **10** |

The seven successful executions were EXP-001, EXP-003, EXP-004, EXP-005,
EXP-006, EXP-007, and EXP-010. EXP-004 is qualified because the intended
read-only checkout path was followed by an unexpected order side effect.
EXP-007 is qualified because the invalid-voucher rejection was observed, but
the total invariant was not verified and the technical backend error was
exposed. EXP-010 is qualified because cleanup succeeded, but the transaction
reference in the confirmation dialog differed from the order-list identifier.

## Coverage

- Startup, Home, tab navigation: executed.
- Catalog/search and empty-result validation: executed.
- Filter/detail path: attempted but failed on a Flutter lifecycle assertion.
- Cart and checkout COD presentation: executed; an unexpected COD order was
  created during recovery and then cancelled through the customer UI.
- Account, role, help/address/wishlist surface: executed read-only.
- Super Admin platform dashboard: executed read-only.
- Address CRUD and product CRUD: not executed in this session.
- Final COD order: not intentionally executed; the unexpected order cleanup
  path was executed and verified.

## Important findings

1. **DEF-031 reproduced:** `_dependents.isEmpty` recovery screen appeared while
   starting the catalog/filter/detail flow.
2. **DEF-032 reproduced:** invalid voucher produced a visible
   `PostgrestException` with code `P0001`; the error is not user-safe.
3. Checkout displayed an existing address and COD option. An unexpected COD
   order was later visible as `SM-20261111-000016` (total Rp40.000); it was
   cancelled through the UI and the list showed `Dibatalkan`. No payment was
   made.
4. The confirmation dialog displayed transaction reference `BE554C77`, which
   did not match the order-list identifier; this discrepancy is recorded for
   diagnosis.
