# UAT Execution Summary — KKMP Kerten 1.5.4+8

- Source: `uat/KKMP_Kerten_UAT_136_Kasus.xlsx`
- Device: `nnzxea79ayypnzzx` (physical Xiaomi Android)
- App ID: `com.fauzibondanp.shopmart`
- Execution scope: non-destructive Maestro MCP checks only; no checkout/order creation, logout, clear state, chat send, role/stock changes, or destructive admin operation.

## Current counts

| Status | Count |
|---|---:|
| PASS | 8 |
| FAIL | 0 |
| BLOCKED | 1 |
| NOT RUN | 127 |
| **Total** | **136** |

## Cases with current evidence

| ID | Status | Actual result | Evidence |
|---|---|---|---|
| UAT-013 | PASS | Home menampilkan produk aktif pada perangkat fisik; bukti startup/home dari Maestro. | ../evidence/screenshots/startup-home.png |
| UAT-015 | PASS | Kategori Sembako dibuka dan menampilkan produk Gula Pasir pada perangkat fisik. | ../evidence/screenshots/uat-u15-category-sembako.png |
| UAT-019 | PASS | Pencarian keyword beras dijalankan dan hasil produk beras terlihat. | ../evidence/screenshots/search-results-beras.png |
| UAT-023 | PASS | Detail produk Tes Produk terbuka dan layar Detail Produk terlihat. | ../evidence/screenshots/uat-u23-product-detail.png |
| UAT-051 | PASS | Daftar Pesanan terbuka dan order tersimpan terlihat pada perangkat fisik. | ../evidence/screenshots/uat-u51-orders-list.png |
| UAT-052 | PASS | Detail Pesanan order tersimpan terbuka dan dapat dibaca. | ../evidence/screenshots/uat-u52-order-detail.png |
| UAT-082 | PASS | Pusat Bantuan/chat terbuka tanpa mengirim pesan. | ../evidence/screenshots/uat-chat-open.png |
| REG-013 | PASS | Uji pencatatan log dijalankan dari Error Log Center; layar tetap terbuka dan log center dapat diakses. | ../evidence/screenshots/uat-reg013-error-log-after-test.png |
| REG-016 | BLOCKED | Menu ekspor terbuka dan opsi Simpan TXT dipilih, tetapi pembukaan ulang file UTF-8 tidak diverifikasi pada perangkat. | ../evidence/screenshots/uat-reg016-export-txt-result.png |

## Important limitations

- The 136 official cases were initialized from the workbook; historical workbook statuses were not reused as current evidence.
- PASS is limited to the exact visible behavior observed; it is not a full end-to-end sign-off.
- Checkout, transaction creation, cart mutation, account/logout flows, security/RLS, network-offline, admin mutations, and file reopen validation remain blocked or not run because they require controlled data, special accounts, or prohibited/destructive actions.
