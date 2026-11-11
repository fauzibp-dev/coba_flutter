# KKMP Kerten

**PRECHECK STARTUP XIAOMI:** Jalankan `bash scripts/run_uts_maestro.sh doctor` dahulu, baru `smoke` setelah layar HP menampilkan aplikasi. Script tidak lagi melaporkan banyak FAIL akibat startup tunggal. [Panduan](.maestro/uts/README.md).

**Perbaikan instalasi berulang driver Maestro (11 November 2026):** jalankan `bash scripts/run_uts_maestro.sh smoke`. Sekarang smoke dijalankan dalam satu proses Maestro (bukan `maestro test` berulang tiap flow). Baca [panduan](.maestro/uts/README.md).

## UTS Mobile Testing 2026/2027 — status pengumpulan

Dokumen soal meminta minimal **5 skenario UAT**, **4 flow YAML Maestro** (startup, navigasi, transaksi/CRUD dan validasi), assertion serta log/screenshot/rekaman, laporan UAT, README dan video 5–10 menit. Paket terfokus berada di:

- [6 flow khusus UTS](.maestro/uts/README.md)
- [Matriks enam skenario UAT dan audit kesesuaian soal](uat/UTS_6_SKENARIO_DAN_KESESUAIAN.md)
- [Laporan UAT historis dan temuan bug](uat/UTS_UAT_REPORT.md)
- [Panduan video dan tautan yang harus diisi](uat/VIDEO_PANDUAN_UTS_2026.md)

**Identitas untuk diisi sebelum pengumpulan** (jangan menyalin identitas dari tugas mahasiswa lain):
- **Nama mahasiswa:** [ISI NAMA RESMI]
- **NIM:** [ISI NIM]
- **Kelas:** TI23B (sesuai lembar soal; verifikasi)
- **Peran setiap anggota:** [ISI PERAN NYATA / PEMBAGIAN TUGAS]

**Tautan video:** [ISI URL VIDEO 5–10 MENIT, AKSES DOSEN HARUS DIBUKA]

**Kesesuaian kredensial:** source `lib/core/config/supabase_config.dart` memiliki *publishable* Supabase key sebagai default. Key itu bukan secret/server role, tetapi instruksi dosen melarang penyimpanan API key di repository. Sebelum pengumpulan, tentukan cara konfigurasi build lokal (`--dart-define`) dan jangan mengunggah nilai key di README/log; penghapusan default belum diterapkan supaya build/aplikasi yang sedang diuji tidak mendadak terputus dari backend.

**Akses repository:** repo GitHub saat audit masih **private**. Agar dosen dapat membaca, berikan akses melalui GitHub collaborator atau pengaturan akses lain yang disetujui. Pastikan tautan benar-benar dapat dibuka. Jangan menambahkan password, token, service-role/secret key ke GitHub.

Run cepat di Mac (HP fisik telah terpasang APK, session login untuk auth):
```bash
adb devices
bash scripts/run_uts_maestro.sh smoke
bash scripts/run_uts_maestro.sh auth
```

Hasil terbaru belum ada sampai dijalankan pada HP; status UAT historis **14 PASS, 1 FAIL, 3 BLOCKED, 118 NOT RUN** bukan status 6 flow baru. Jalur data UAT-036 masih berstatus FAIL.

---

KKMP Kerten adalah aplikasi e-commerce mobile Flutter untuk Koperasi Merah Putih Kerten, Kecamatan Laweyan.

**Tagline:** Belanja Lebih Mudah Di KKMP Kerten.

Brand lama aplikasi bernama Shop Mart. Identitas teknis (`coba_flutter`, package ID, database, dan migration history) dipertahankan agar pembaruan tetap kompatibel. Aplikasi ini dikembangkan oleh **fauzibondanp**.

Versi aplikasi yang diuji: **1.5.4+8**.

## Stack

- Flutter 3.47.5 / Dart 3.13+
- Supabase Auth
- PostgreSQL + Row Level Security
- Supabase Storage
- Supabase Realtime untuk customer support chat
- `pg_cron` untuk expiry order/reservation
- Android physical-device workflow

## Backend dan environment

Aplikasi memakai **Supabase publishable key** pada client. Secret key / service-role key tidak boleh masuk source Flutter, APK, atau repository.

Production URL dan publishable key memiliki default untuk deployment saat ini, tetapi keduanya dapat diganti saat build/run sehingga staging tidak perlu mengubah source:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
```

Backend mencakup profil, store, kategori, produk, multi-image gallery, opsi/varian, inventory ledger, stock reservation, wishlist, cart, alamat, voucher, campaign/flash sale, order, payment, manual-payment proof, shipping/fulfillment, reviews, notifications, chat, returns/refunds, warehouse, supplier/purchase order, stocktake, audit log, platform settings, privacy request, dan integration mapping.

Checkout, perubahan quantity cart, product+stock mutation, archive product, variant stock, purchase-order receiving, shipment lifecycle, payment verification, dan lifecycle order yang sensitif dilakukan lewat PostgreSQL RPC. Harga, voucher, campaign, stock, total, role, dan ownership divalidasi server-side. Checkout memakai client request UUID agar retry request yang sama tidak membuat order ganda.

## Customer commerce v1.5

- browse catalog tanpa login
- register / login email-password
- forgot/reset password, change password dan change email
- advanced search, filter harga/rating/kategori dan sorting
- search history dan recently viewed
- home merchandising: flash sale, best seller, produk terbaru dan rekomendasi katalog
- product detail dengan opsi/varian, variant-specific price/stock/image/weight
- multi-image product gallery
- wishlist
- persistent cart dengan server stock validation
- address book: tambah/edit/hapus/default
- **server checkout quote** sebelum membuat order
- voucher/campaign validation dari server
- COD / transfer manual
- pickup / local delivery + dynamic delivery zones
- idempotent checkout retry
- stock reservation + expiry lifecycle
- manual transfer deadline + upload bukti pembayaran
- daftar pesanan, detail dan timeline status
- shipment/tracking, driver, tracking number dan shipment events
- cancellation sesuai state machine
- rich review: rating, komentar, gambar, seller reply, helpful vote
- in-app notification center + preferences
- realtime support chat + image attachment
- item-level return/refund request + evidence upload
- account deletion request

## Admin toko

Dari **Akun > Shop Mart Admin**:

- tambah/edit/arsip produk
- multi-image gallery: upload beberapa foto, pilih primary, reorder dan delete
- opsi & varian: SKU/barcode/harga/berat/stok per kombinasi
- inventory adjustment wajib memiliki reason dan movement ledger
- lihat serta proses order
- update lifecycle order melalui state-machine RPC
- manual payment proof approval/rejection
- fulfillment: shipment status, driver, lokasi, tracking number dan event
- store settings: ongkir, free-shipping threshold, timeout transfer, bank account, return window
- delivery-zone management
- supplier management
- stocktake / stock opname
- purchase order: create PO, add item/variant, mark ordered, partial/full receiving
- PO receiving otomatis menambah inventory dan inventory movement

## Super Admin

Dari **Akun > Shop Mart Super Admin**:

- toko/koperasi global
- user, owner/admin/staff dan platform Super Admin
- kategori global
- katalog global
- **galeri produk global** lintas toko
- order global
- voucher dan banner
- Commerce Control Center
- analytics dan top products
- campaign / flash sale + quota dan promo price
- return/refund oversight
- customer support seluruh toko
- operations/integration/sync log
- maintenance mode dan minimum supported version
- account-deletion/privacy queue
- audit log platform

Super Admin tidak dapat mengambil alih platform dari client bootstrap. `claim_initial_owner()` tidak executable oleh role authenticated.

## Warehouse & reservation automation

- inventory memisahkan `available_qty` dan `reserved_qty`
- checkout membuat inventory reservation
- unpaid manual-transfer order memiliki expiry
- cron production menjalankan expiry cleanup setiap 10 menit
- cancellation/expiry mengembalikan stock sesuai ledger
- stocktake dan PO receiving dicatat sebagai inventory movement

## Notification & push readiness

In-app notification dan notification preferences sudah aktif. Schema `device_tokens` sudah tersedia untuk push provider.

**Transport push eksternal (FCM/OneSignal/APNs) belum diaktifkan** karena project credential/provider resmi belum disediakan. Jangan menaruh service credential push di Flutter client.

## Menjalankan di HP Android

```bash
git pull origin main
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter run
```

Pastikan HP terlihat lebih dulu:

```bash
flutter devices
adb devices
```

## Tujuan dan target pengguna

KKMP Kerten menyediakan katalog dan pembelian kebutuhan koperasi secara mobile. Target
penggunanya adalah pelanggan koperasi, admin toko, dan Super Admin platform. Alur
pelanggan utama adalah membuka katalog, mencari produk, melihat detail, mengelola
keranjang, mengisi checkout, memantau pesanan, dan memakai bantuan/chat. Admin mengelola
produk, stok, pesanan, fulfillment, dan dukungan; Super Admin mengelola konfigurasi
platform dan audit/error log.

## Batasan pengujian

UAT fisik saat ini menggunakan Xiaomi Android `nnzxea79ayypnzzx`
(`nnzxea79ayypnzzx`) dan tidak menggunakan emulator/cloud. Pengujian non-destruktif
tidak membuat pesanan, tidak mengubah stok/role, tidak logout atau clear state, dan
tidak mengirim chat. Skenario yang membutuhkan akun/data khusus, perubahan jaringan,
RLS, transaksi nyata, atau membuka ulang file ekspor diberi status `BLOCKED` atau
`NOT RUN` sampai ada persetujuan dan prasyarat yang aman.

## Maestro dan bukti UAT

Flow reusable berada di [`.maestro/`](.maestro/). Contoh menjalankan satu flow pada
perangkat fisik:

```bash
maestro test --device nnzxea79ayypnzzx .maestro/startup.yaml
maestro test --device nnzxea79ayypnzzx .maestro/pencarian.yaml
```

Setiap flow UTS yang aktif harus memiliki assertion dan `takeScreenshot`. Matriks dan
bukti eksekusi terbaru berada di
[`uat/results/`](uat/results/), terutama
[`uat_matrix_current_20261108-1355.csv`](uat/results/uat_matrix_current_20261108-1355.csv)
dan
[`uat_matrix_current_20261108-1355.json`](uat/results/uat_matrix_current_20261108-1355.json),
dengan ringkasan final
[`uat_execution_summary_20261110.md`](uat/results/uat_execution_summary_20261110.md)
dan workbook
[`KKMP_Kerten_UAT_136_Kasus_synced_20261110.xlsx`](uat/KKMP_Kerten_UAT_136_Kasus_synced_20261110.xlsx).

Eksekusi terbaru mencatat 14 PASS, 1 FAIL, 3 BLOCKED, dan 118 NOT RUN.
`UAT-036` gagal diverifikasi karena alamat `UAT_TEST` hilang dari daftar setelah
penyimpanan; bukti diagnosis ada di
`uat/results/uat036_diagnosis_and_admin_crud_20261108-1355.log`. CRUD produk
UAT_TEST berhasil dibuat, dibaca, diubah, lalu diarsipkan melalui UI; penghapusan
tidak tersedia pada layar Super Admin.

Flow UTS tambahan:

- [`.maestro/uat-transaction.yaml`](.maestro/uat-transaction.yaml): mencari produk,
  menambah ke cart, membuka checkout COD, dan mengassert section checkout tanpa
  mengirim order final.
- [`.maestro/uat-validation.yaml`](.maestro/uat-validation.yaml): validasi query
  tanpa hasil dengan assertion `Produk tidak ditemukan`.

## Supabase migrations

Perubahan database disimpan di `supabase/migrations/`. Riwayat database sebelum migration directory tersedia didokumentasikan di `supabase/MIGRATION_HISTORY.md`.

Semua perubahan schema/RLS/RPC berikutnya harus migration-first dan direview bersama perubahan aplikasi yang memakainya. Migration production v1.5 mencakup commerce suite, warehouse/variant operations, schedulers, security hardening, FK indexes, RLS performance, product gallery dan Super Admin gallery access.

## Release Android

Debug build tetap dapat dijalankan seperti biasa. Release build **tidak boleh memakai debug key**. Untuk membuat release resmi:

1. Buat dan simpan production keystore di luar repository.
2. Copy `android/key.properties.example` menjadi `android/key.properties`.
3. Isi referensi keystore/alias/password secara lokal atau dari CI secret.
4. Jalankan `flutter build appbundle --release`.

`android/key.properties`, `*.jks`, dan `*.keystore` di-ignore dan tidak boleh di-commit.

## External integrations

Payment gateway, kurir pihak ketiga, push provider, dan sinkronisasi e-commerce lama Koperasi Merah Putih Kerten tidak di-hardcode tanpa credential/API resmi.

Payment gateway sengaja menjadi tahap terakhir. Core payment abstraction sudah memiliki `payments`, payment state, manual-transfer proof, idempotent checkout, order/payment separation dan integration tables sehingga provider dapat ditambahkan tanpa membongkar commerce core.

Internal/local-delivery fulfillment sudah dapat berjalan tanpa API kurir eksternal.

## Security

- RLS aktif pada seluruh tabel public aplikasi yang menyimpan data aplikasi.
- Client hanya memakai publishable key.
- Customer-private data dibatasi dengan ownership/RLS.
- Direct mutation terhadap order dan inventory sensitif tidak diberikan kepada role authenticated.
- Mutation sensitif menggunakan RPC yang memeriksa ownership/role.
- Review harus terkait order item customer yang benar dan order completed.
- Product Storage write dibatasi folder store; Super Admin memiliki policy eksplisit untuk operasi global.
- Trigger-only helper RPC tidak executable oleh authenticated client.
- Checkout quote/search mengikuti RLS caller.
- Service-role / secret key tidak boleh dimasukkan ke APK atau repository.

## Final release gate

Sebelum menandai build sebagai release final publik:

1. GitHub CI harus hijau: analyze, test, debug build.
2. Supabase migration Git/production harus sinkron.
3. Security/integrity audit harus bersih dari blocker.
4. Jalankan physical-device UAT pada Android target.
5. Siapkan production signing bila aplikasi akan didistribusikan sebagai release/App Bundle.
6. Payment gateway baru diaktifkan setelah API/provider resmi tersedia.

## Android UAT runtime fixes (12 Oktober 2026)

- Initialize Indonesian date symbols before rendering order/chat/admin timestamps.
- Fix the server-side Super Admin analytics aggregates.
- Use an authorization-checked RPC for Privacy Queue profile lookup.
- Publish RLS-protected chat messages to Realtime; keep stream subscriptions stable and retryable.
- Production migrations: `20261012043032_shop_mart_uat_runtime_fixes.sql`, `20261012043810_shop_mart_superadmin_email_casts.sql`, and `20261012043901_shop_mart_superadmin_audit_email_cast.sql`.
- All 13 read-only Super Admin RPC smoke checks passed after the explicit `varchar` to `text` return-contract fixes.

## KKMP Kerten brand refresh

- Application label Android/iOS/web: `KKMP Kerten`.
- Tagline resmi aplikasi: `Belanja Lebih Mudah Di KKMP Kerten`.
- Ikon launcher Android, web icon dan logo UI memakai logo koperasi yang dikirim pada 12 Oktober 2026.
- Jangan mengubah `applicationId`, `namespace`, nama package Dart, atau project Supabase hanya demi tampilan brand.
