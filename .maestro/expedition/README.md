# KKMP Kerten — Maestro Expedition (50 core flows)

Source-backed test suite for the Xiaomi Android physical device; package `com.fauzibondanp.shopmart`.
Prepared 2026-11-11 in branch `test/maestro-exploration-20261111`. **NOT YET EXECUTED on a connected device.**

## Scope

- **50 standalone YAML flows** in this folder, each with an assertion and a screenshot.
- **9 optional YAML flows** in `../expedition-optional/` (including the earlier admin read-only flow); require specific role/cart/test data.
- **2 one-take video journeys** in `../expedition-video/`.
- See `TEST_MATRIX.md` for every test and tag. Legacy flows under `.maestro/` are unchanged.

## Prerequisites

- Mac with Flutter, Android ADB and Maestro CLI; KKMP Kerten installed and accessible from launcher.
- A compatible existing login session; role-specific tests require Super Admin or Admin toko.
- Confirm target data (Sembako, Beras Premium Kerten) still exists before data-dependent flows.
- Tests `01` through `08` were carried forward, with categorization tags added; their selectors have NOT been validated against the latest device runtime.

## Quick start (from repository root)

```bash
git fetch origin
git switch test/maestro-exploration-20261111
adb devices
maestro --version
# Start with a small smoke suite, not 50 at once:
maestro --device nnzxea79ayypnzzx test .maestro/expedition --include-tags smoke
# Customer tests (may require login/data):
maestro --device nnzxea79ayypnzzx test .maestro/expedition --include-tags customer
# Super Admin tests (requires Super Admin session):
maestro --device nnzxea79ayypnzzx test .maestro/expedition --include-tags superadmin
# ALL 50 core flows (only if roles/prerequisites are satisfied):
maestro --device nnzxea79ayypnzzx test --format junit --output build/maestro-expedition-report.xml --test-output-dir build/maestro-expedition --debug-output build/maestro-debug .maestro/expedition
```

Alternatively use `bash scripts/run_maestro_expedition.sh smoke`, `customer`, `superadmin`, `validation` or `all`; the script creates a dated output directory, JUnit report and terminal log under `build/`.

## Video

```bash
maestro --device nnzxea79ayypnzzx test .maestro/expedition-video/complete_journey.yaml
maestro --device nnzxea79ayypnzzx test .maestro/expedition-video/platform_tour_readonly.yaml
```

Record longer demonstrations with the phone's screen recorder or OBS/scrcpy while running `maestro test`. Using `maestro record --local` may be limited in duration depending on the CLI edition.

## Safety and reporting

- Each standalone flow restarts only the app process (`stopApp`) and retains storage/auth state; no `clearState`.
- `03_product_cart_checkout` and `complete_journey` add an item to cart as part of a draft checkout test; neither clicks `Buat Pesanan`.
- Search tests may change history, but no order, payment, inventory, role, setting, deletion, or chat send action is submitted.
- Previously observed UAT-036 address persistence is still FAIL, not fixed by creating a separate form-validation flow.
- Keep baseline UAT results (14 PASS, 1 FAIL, 3 BLOCKED, 118 NOT RUN) until real runtime test evidence exists.
- Any accessibility selector mismatch should be fixed after inspecting Maestro hierarchy/debug artifacts; do not fabricate PASS.
