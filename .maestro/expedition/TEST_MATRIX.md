# KKMP Kerten — Maestro test matrix

Prepared: 2026-11-11 | Branch `test/maestro-exploration-20261111`.

**Status:** authored only, NOT RUN. File existence is not runtime PASS. All tests must run on physical Xiaomi before updating UAT counts.

## 50 core standalone flows

| No. | File | Tags |
|---|---|---|
| 1 | `01_home_catalog.yaml` | smoke, customer, catalog |
| 2 | `02_search_filters.yaml` | customer, search, data-dependent |
| 3 | `03_product_cart_checkout.yaml` | customer, checkout, cart-write, auth, data-dependent |
| 4 | `04_orders_account_wishlist.yaml` | customer, orders, auth |
| 5 | `05_notifications_support.yaml` | customer, support, auth |
| 6 | `06_superadmin_readonly.yaml` | superadmin, platform, auth |
| 7 | `07_empty_search_validation.yaml` | smoke, customer, validation |
| 8 | `08_address_required_validation.yaml` | customer, validation, auth |
| 9 | `09_home_category_sembako.yaml` | customer, catalog, data-dependent |
| 10 | `10_home_search_shortcut.yaml` | smoke, customer, search |
| 11 | `11_search_sort_price_low.yaml` | customer, search |
| 12 | `12_search_sort_newest.yaml` | customer, search |
| 13 | `13_search_minimum_price.yaml` | customer, search, validation |
| 14 | `14_search_rating_filter.yaml` | customer, search |
| 15 | `15_search_filter_reset.yaml` | customer, search, validation |
| 16 | `16_search_other_empty_state.yaml` | customer, search, validation |
| 17 | `17_product_description.yaml` | customer, product, data-dependent |
| 18 | `18_product_reviews.yaml` | customer, product, data-dependent |
| 19 | `19_cart_open_readonly.yaml` | customer, cart, auth |
| 20 | `20_order_list_readonly.yaml` | customer, orders, auth |
| 21 | `21_account_role_readonly.yaml` | superadmin, account, auth |
| 22 | `22_address_form_preview.yaml` | customer, account, validation, auth |
| 23 | `23_security_preferences_overview.yaml` | customer, account, auth |
| 24 | `24_password_dialog_cancel.yaml` | customer, account, validation, auth |
| 25 | `25_email_dialog_cancel.yaml` | customer, account, validation, auth |
| 26 | `26_privacy_request_cancel.yaml` | customer, account, validation, auth |
| 27 | `27_notification_center_readonly.yaml` | customer, notifications, auth |
| 28 | `28_support_chat_readonly.yaml` | customer, support, auth |
| 29 | `29_superadmin_platform_metrics.yaml` | superadmin, platform, auth |
| 30 | `30_superadmin_stores.yaml` | superadmin, platform, auth |
| 31 | `31_superadmin_users.yaml` | superadmin, platform, auth |
| 32 | `32_superadmin_unknown_user.yaml` | superadmin, platform, validation, auth |
| 33 | `33_superadmin_categories.yaml` | superadmin, platform, auth |
| 34 | `34_superadmin_catalog.yaml` | superadmin, platform, auth |
| 35 | `35_superadmin_product_notfound.yaml` | superadmin, platform, validation, auth |
| 36 | `36_superadmin_gallery.yaml` | superadmin, platform, auth |
| 37 | `37_superadmin_orders.yaml` | superadmin, platform, auth |
| 38 | `38_superadmin_vouchers.yaml` | superadmin, platform, promotions, auth |
| 39 | `39_superadmin_banners.yaml` | superadmin, platform, promotions, auth |
| 40 | `40_superadmin_returns.yaml` | superadmin, platform, auth |
| 41 | `41_superadmin_support_inbox.yaml` | superadmin, platform, support, auth |
| 42 | `42_superadmin_broadcast_tab.yaml` | superadmin, platform, operations, auth |
| 43 | `43_superadmin_integrations_tab.yaml` | superadmin, platform, operations, auth |
| 44 | `44_superadmin_synclog_tab.yaml` | superadmin, platform, operations, auth |
| 45 | `45_superadmin_audit_log.yaml` | superadmin, platform, auth |
| 46 | `46_superadmin_commerce_analytics.yaml` | superadmin, platform, analytics, auth |
| 47 | `47_superadmin_commerce_campaign.yaml` | superadmin, platform, analytics, auth |
| 48 | `48_superadmin_privacy_queue.yaml` | superadmin, platform, privacy, auth |
| 49 | `49_superadmin_error_center.yaml` | superadmin, platform, observability, auth |
| 50 | `50_maintenance_dialog_cancel.yaml` | superadmin, platform, validation, auth |

## Optional tests

- `expedition-optional/09_admin_readonly.yaml` (existing, role-dependent).
- `.maestro/expedition-optional/51_admin_products_readonly.yaml`
- `.maestro/expedition-optional/52_admin_orders_readonly.yaml`
- `.maestro/expedition-optional/53_admin_operations_readonly.yaml`
- `.maestro/expedition-optional/54_admin_purchase_orders.yaml`
- `.maestro/expedition-optional/55_checkout_pickup_only.yaml`
- `.maestro/expedition-optional/56_checkout_transfer_display.yaml`
- `.maestro/expedition-optional/57_store_form_cancel.yaml`
- `.maestro/expedition-optional/58_voucher_form_cancel.yaml`

## Video journeys

- `expedition-video/complete_journey.yaml` — customer to Super Admin (adds product to cart; no order creation).
- `expedition-video/platform_tour_readonly.yaml` — in-app Super Admin navigation only.

## Preconditions and risk

- Existing logged-in role must match test tags.
- Catalogue tests require active Sembako category and Beras Premium Kerten (data-dependent).
- Optional checkout screens need an already-populated cart, and must not click **Buat Pesanan**.
- 03_product_cart_checkout adds a cart item; searches may persist search history.
- No flow archives/deletes products, changes roles, sends chat, sends email, updates maintenance, creates order, or makes a real payment.
- Failure in any test must be recorded, not reclassified as PASS.
