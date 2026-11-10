# Outline Video Penjelasan UTS — KKMP Kerten (5–10 menit)

## 0:00–0:45 — Pembukaan

- Sebutkan aplikasi KKMP Kerten, versi `1.5.4+8`, dan tujuan pengujian mobile.
- Tampilkan package `com.fauzibondanp.shopmart` dan perangkat Xiaomi fisik.

## 0:45–1:45 — Produk dan target pengguna

- Jelaskan target: guest/customer, admin toko, dan Super Admin.
- Tunjukkan README dan fitur utama: katalog, pencarian, keranjang, pesanan,
  chat, admin, dan Error Log Center.

## 1:45–3:30 — Struktur repository dan flow Maestro

- Tunjukkan `lib/`, `.maestro/`, `uat/`, README, dan test source.
- Buka `startup.yaml`, `pencarian.yaml`, `keranjang.yaml`, dan
  `error-log-center.yaml`.
- Sorot assertion dan `takeScreenshot` pada setiap flow.

## 3:30–5:30 — Demo eksekusi di perangkat fisik

- Jalankan startup: assertion tagline dan screenshot.
- Jalankan pencarian `beras`: assertion layar/field dan screenshot hasil.
- Jalankan navigasi keranjang: assertion auth gate tanpa mengubah data.
- Jalankan Error Log Center: tunjukkan diagnostic log secara read-only.

## 5:30–7:00 — Skenario UAT dan bukti

- Tampilkan tabel lima skenario lengkap di `UTS_UAT_REPORT.md`.
- Tunjukkan screenshot yang terkait dengan UAT-013, UAT-015, UAT-019,
  UAT-023, dan UAT-082.
- Jelaskan bahwa PASS parsial diberi catatan dan tidak disamakan dengan
  sign-off penuh.

## 7:00–8:15 — Hasil baseline dan batasan

- Tampilkan angka terbaru: 14 PASS, 1 FAIL, 3 BLOCKED, 118 NOT RUN dari 136 kasus.
- Tunjukkan bukti UAT-036: form `UAT_TEST` terisi, tetapi alamat tidak muncul
  setelah save; jelaskan mengapa statusnya FAIL dan bukan PASS/BLOCKED.
- Tunjukkan CRUD Super Admin untuk `UAT_TEST_PRODUK_20261108`: create/read,
  update harga, lalu archive sebagai cleanup karena kontrol delete tidak tersedia.
- Jelaskan checkout/order creation, mutasi stok, role, logout, RLS, dan
  export reopen tidak dijalankan tanpa persetujuan/data sandbox.

## 8:15–9:15 — Kesimpulan

- Jelaskan bukti yang sudah tersedia dan persyaratan yang masih BELUM LENGKAP.
- Tegaskan tidak ada perubahan source Flutter/Supabase, transaksi nyata, atau
  push/commit otomatis.

## 9:15–10:00 — Penutup

- Tampilkan lokasi laporan, matriks CSV/JSON terbaru, log percobaan alamat,
  screenshot, dan flow YAML.
- Sebutkan langkah lanjutan: sandbox checkout/CRUD dengan akun UAT yang disetujui.
