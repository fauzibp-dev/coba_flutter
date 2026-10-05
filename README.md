# Shop Mart

Shop Mart adalah aplikasi e-commerce mobile Flutter untuk Koperasi Merah Putih Kerten, Kecamatan Laweyan. Aplikasi ini dikembangkan oleh **fauzibondanp**.

## Versi

- App: **1.1.0+2**
- Flutter: 3.47.5
- Dart: 3.13+
- Target utama: Android physical device

## Stack

- Flutter
- Supabase Auth
- PostgreSQL + Row Level Security
- PostgreSQL RPC untuk mutation yang sensitif
- Supabase Storage (`product-images`)
- GitHub Actions CI

## Arsitektur keamanan v1.1

Client hanya memakai Supabase publishable key. Secret/service-role key tidak boleh dimasukkan ke Flutter, APK, maupun repository.

Mutation sensitif tidak lagi mengandalkan direct table update dari client:

- cart quantity melalui RPC dengan validasi stok
- checkout melalui RPC dengan validasi harga, voucher, stok, dan request idempotency
- perubahan lifecycle order melalui RPC state machine
- perubahan stok admin melalui RPC yang menulis inventory ledger secara atomik
- review melalui RPC yang memastikan user benar-benar membeli produk tersebut dan order sudah selesai
- owner tidak lagi dapat diklaim otomatis oleh user pertama yang login
- product image mutation dibatasi berdasarkan folder `store_id`

Schema/mutation production mulai v1.1 disimpan di `supabase/migrations/` agar perubahan database dapat direview dan direproduksi.

## Backend environment

Default build tetap menunjuk project Shop Mart production yang sudah ada. Untuk staging/dev, override saat run/build dengan `dart-define`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxx
```

Gunakan project staging untuk UAT berulang atau automated integration test agar data production tidak tercampur dengan data pengujian.

## Menjalankan di HP Android

```bash
git pull origin main
flutter pub get
flutter analyze
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
- product detail + stok varian
- wishlist
- cart tersimpan di database dengan validasi stok server
- kelola alamat (tambah/edit/hapus/default)
- checkout COD / transfer manual
- checkout idempotent untuk mencegah duplicate order akibat retry
- histori pesanan + detail + timeline status
- cancellation sesuai state
- review produk setelah order selesai
- pengajuan retur setelah order delivered/completed
- notification center
- chat dengan pengelola koperasi

## Alur admin

Dari **Akun > Shop Mart Admin**:

- tambah/edit/arsip produk
- upload/ganti foto produk
- atur harga, kategori, SKU, stok, featured, status katalog
- alasan perubahan stok tercatat ke inventory ledger
- lihat pesanan masuk
- update lifecycle status order melalui state machine server
- ringkasan nilai order yang sudah dibayar
- lihat dan proses retur
- tambah/edit/aktifkan voucher promo

## Owner / admin bootstrap

Aplikasi **tidak** memberikan role owner secara otomatis kepada user yang login. Owner production yang sudah ada tetap dipertahankan di database.

Untuk deployment baru, bootstrap owner harus dilakukan melalui proses administrasi/database yang terkontrol, bukan dari client Flutter. Jangan membuka kembali `claim_initial_owner()` untuk role `authenticated`.

## Supabase migrations

Migration v1.1 berada di:

```text
supabase/migrations/
  20261005_000001_security_hardening.sql
  20261005_000002_cart_checkout.sql
  20261005_000003_admin_product_orders.sql
  20261005_000004_notifications_chat_returns.sql
```

Apply migration secara berurutan. Jangan mengedit database production secara manual tanpa menambahkan migration ekuivalen ke repository.

## CI

Workflow `.github/workflows/flutter.yml` menjalankan:

```text
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug
```

## Release Android

Workflow development/course masih memakai debug APK. Untuk distribusi Play Store, konfigurasi production keystore dan signing secret harus dilakukan secara terpisah dan tidak boleh di-commit ke Git.

## External integrations

Payment gateway, kurir pihak ketiga, dan sinkronisasi e-commerce lama Koperasi Merah Putih Kerten tidak di-hardcode karena credential/API resminya belum tersedia. Database sudah memiliki `integration_sources`, `external_mappings`, dan `sync_logs` agar integrasi dapat ditambahkan tanpa membongkar core commerce.

## Security checklist

- RLS aktif pada tabel public aplikasi
- client memakai publishable key
- privileged mutation memakai checked RPC
- checkout memiliki idempotency key
- order total dihitung server-side
- stock revalidated server-side
- review terikat ke purchased order item
- owner bootstrap tidak exposed ke client
- service-role/secret key tidak boleh ada di source
- production keystore tidak boleh ada di repository
