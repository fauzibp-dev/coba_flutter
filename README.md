# Shop Mart

Shop Mart adalah aplikasi e-commerce mobile Flutter untuk Koperasi Merah Putih Kerten, Kecamatan Laweyan. Aplikasi ini dikembangkan oleh **fauzibondanp**.

## Stack

- Flutter 3.47.5 / Dart 3.13+
- Supabase Auth
- PostgreSQL + Row Level Security
- Supabase Storage (`product-images`)
- Android physical-device workflow

## Production backend

Project Supabase utama sudah dikonfigurasi untuk Shop Mart. Aplikasi memakai **Supabase publishable key**, yang memang ditujukan untuk aplikasi client dan aman digunakan bersama RLS. Secret key / service-role key tidak pernah ditaruh di source Flutter.

Backend memiliki schema produksi untuk profil, store, kategori, produk, gambar, varian, inventory ledger, wishlist, cart, alamat, voucher, order, payment, reviews, notifications, chat, returns/refunds, audit log, dan integration mapping.

Checkout dilakukan lewat PostgreSQL RPC agar harga, voucher, stok, dan total tidak dipercaya dari client Flutter.

## Admin bootstrap

Deployment baru memakai bootstrap satu kali: akun authenticated pertama yang membuka menu Akun akan menjadi `owner` Koperasi Merah Putih Kerten jika belum ada owner. Setelah owner terbentuk, user berikutnya tetap customer biasa.

Pastikan akun pengelola koperasi menjadi akun pertama yang login sebelum aplikasi dibuka ke publik.

## Menjalankan di HP Android

```bash
git pull origin main
flutter pub get
flutter analyze
flutter run
```

Pastikan HP terlihat lebih dulu:

```bash
flutter devices
adb devices
```

## Alur customer aktif

- browse tanpa login
- register / login email-password
- search & kategori
- product detail
- wishlist
- cart tersimpan di database
- alamat
- checkout server-side
- COD / transfer manual
- histori dan status pesanan
- cancellation untuk status yang masih diizinkan

## Alur admin aktif

Dari **Akun > Shop Mart Admin**:

- tambah/edit/arsip produk
- upload foto produk ke Supabase Storage
- atur harga, kategori, SKU, stok, featured, status katalog
- lihat pesanan masuk
- update lifecycle status order
- ringkasan order dan nilai transaksi

## External integrations

Payment gateway, kurir pihak ketiga, dan sinkronisasi e-commerce lama Koperasi Merah Putih Kerten sengaja tidak di-hardcode karena credential/API resminya belum tersedia. Database sudah memiliki tabel `integration_sources`, `external_mappings`, dan `sync_logs` agar integrasi dapat ditambahkan tanpa membongkar core commerce.

## Security

- RLS aktif pada seluruh tabel public aplikasi.
- Client hanya memakai publishable key.
- Privileged checkout/order transitions memakai database function dengan pemeriksaan `auth.uid()` dan role.
- Service-role / secret key tidak boleh dimasukkan ke APK atau repository.
