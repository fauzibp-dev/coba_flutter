# Shop Mart

Shop Mart adalah aplikasi e-commerce mobile Flutter untuk Koperasi Merah Putih Kerten, Kecamatan Laweyan. Aplikasi ini dikembangkan oleh **fauzibondanp**.

## Stack

- Flutter 3.47.5 / Dart 3.13+
- Supabase Auth
- PostgreSQL + Row Level Security
- Supabase Storage (`product-images`)
- Android physical-device workflow

## Backend dan environment

Aplikasi memakai **Supabase publishable key** pada client. Secret key / service-role key tidak boleh masuk source Flutter, APK, atau repository.

Production URL dan publishable key memiliki default untuk deployment saat ini, tetapi keduanya dapat diganti saat build/run sehingga staging tidak perlu mengubah source:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
```

Backend mencakup profil, store, kategori, produk, gambar, varian, inventory ledger, wishlist, cart, alamat, voucher, order, payment, reviews, notifications, chat, returns/refunds, audit log, dan integration mapping.

Checkout, perubahan quantity cart, product+stock mutation, archive product, dan lifecycle order yang sensitif dilakukan lewat PostgreSQL RPC. Harga, voucher, stock, total, role, dan ownership divalidasi server-side. Checkout memakai client request UUID agar retry request yang sama tidak membuat order ganda.

## Owner dan admin

Owner **tidak pernah lagi di-bootstrap dari user pertama yang login**. Fungsi legacy `claim_initial_owner()` dipertahankan sebagai no-op untuk kompatibilitas client lama, tetapi tidak dapat membuat owner baru.

Provisioning owner/admin dilakukan lewat administrasi database yang terkontrol. Jangan membuat flow client yang dapat mempromosikan dirinya sendiri menjadi owner/admin.

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

## Alur customer

- browse tanpa login
- register / login email-password
- search & kategori
- product detail + variant-specific stock
- wishlist
- cart tersimpan dan dibatasi stock server
- address book: tambah/edit/hapus/default
- checkout server-side, COD / transfer manual, pickup / local delivery
- idempotent checkout retry
- daftar + detail pesanan dan timeline status
- cancellation untuk status yang masih diizinkan
- notification center untuk update order
- review produk setelah order completed
- chat bantuan dengan koperasi
- request return/refund untuk order delivered/completed

## Alur admin

Dari **Akun > Shop Mart Admin**:

- tambah/edit/arsip produk
- upload foto produk ke Supabase Storage
- atur harga, kategori, SKU, stok, featured, status katalog
- perubahan stok wajib memiliki alasan dan tercatat di inventory ledger
- lihat pesanan masuk
- update lifecycle status order melalui state-machine RPC
- ringkasan order dan nilai transaksi

## Supabase migrations

Perubahan database v1.1+ disimpan di `supabase/migrations/`. Riwayat database yang dibuat sebelum migration directory tersedia didokumentasikan di `supabase/MIGRATION_HISTORY.md`.

Semua perubahan schema/RLS/RPC berikutnya harus migration-first dan direview bersama perubahan aplikasi yang memakainya.

## Release Android

Debug build tetap dapat dijalankan seperti biasa. Release build **tidak akan memakai debug key**. Untuk membuat release resmi:

1. Buat dan simpan production keystore di luar repository.
2. Copy `android/key.properties.example` menjadi `android/key.properties`.
3. Isi referensi keystore/alias/password secara lokal atau dari CI secret.
4. Jalankan `flutter build appbundle --release`.

`android/key.properties`, `*.jks`, dan `*.keystore` sudah di-ignore dan tidak boleh di-commit.

## External integrations

Payment gateway, kurir pihak ketiga, dan sinkronisasi e-commerce lama Koperasi Merah Putih Kerten tidak di-hardcode karena credential/API resmi belum tersedia. Database memiliki `integration_sources`, `external_mappings`, dan `sync_logs` sehingga integrasi dapat ditambahkan tanpa membongkar core commerce.

## Security

- RLS aktif pada seluruh tabel public aplikasi.
- Client hanya memakai publishable key.
- Customer-private data dibatasi dengan `auth.uid()`/ownership.
- Direct mutation terhadap order, inventory, cart item, dan product core dibatasi; mutation sensitif memakai RPC yang memeriksa ownership/role.
- Review harus terkait order item milik customer yang benar dan order completed.
- Product Storage write dibatasi ke folder store yang dimiliki staff terkait.
- Service-role / secret key tidak boleh dimasukkan ke APK atau repository.
