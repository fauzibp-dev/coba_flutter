# KKMP Kerten — Maestro Expedition (11 November 2026)

Akun GitHub: `fauzibp-dev/coba_flutter` | package Android: `com.fauzibondanp.shopmart`.

Flow baru berbasis struktur layar dari source Flutter pada branch `main` commit `9688689bfcf4`. Versi 1.5.4+8. Pengujian runtime **belum dilakukan** pada perangkat setelah penambahan flow ini. Statusnya adalah **READY TO VALIDATE**, bukan PASS.

## Daftar flow

| Flow | Area | Perubahan data | Assertion | Bukti |
|---|---|---|---|---|
| 01_home_catalog.yaml | Startup, kategori, katalog | Tidak | Tagline, kategori, semua produk | 2 screenshot |
| 02_search_filters.yaml | Search, hasil beras, filter | Hanya history pencarian | UI pencarian, hasil, filter | 2 screenshot |
| 03_product_cart_checkout.yaml | Detail, beli sekarang, cart, checkout review | **Menambah item keranjang**; bukan order | Detail, subtotal, checkout | 3 screenshot |
| 04_orders_account_wishlist.yaml | Pesanan, alamat, wishlist | Tidak | Judul setiap halaman | 3 screenshot |
| 05_notifications_support.yaml | Notifikasi dan chat | Tidak | Halaman notifikasi/bantuan | 2 screenshot |
| 06_superadmin_readonly.yaml | Dashboard, katalog global, Error Log Center | Tidak | Modul & judul | 3 screenshot |
| 07_empty_search_validation.yaml | Empty-state | Menyimpan riwayat pencarian | Error & petunjuk alternatif | 1 screenshot |
| 08_address_required_validation.yaml | Form alamat kosong | Tidak (validasi client) | Form tetap terbuka, wajib diisi | 1 screenshot |

Flow admin toko `../expedition-optional/09_admin_readonly.yaml` hanya untuk akun dengan role Admin. Flow video tunggal `../expedition-video/complete_journey.yaml` menggabungkan perjalanan besar TANPA menutup aplikasi berkali-kali.

## Prasyarat

- Flutter app KKMP Kerten terpasang pada HP Android fisik.
- ADB dan Maestro CLI terpasang, USB debugging diaktifkan.
- HP terdeteksi via `adb devices` dan berada di launcher biasa dengan ikon aplikasi `KKMP Kerten`.
- Untuk flow 03–06, 08, dan video: login customer dengan hak yang sesuai. Flow 06 dan video juga membutuhkan sesi Super Admin aktif.
- Pencarian `Beras Premium Kerten` membutuhkan produk aktif berstok pada data uji. Bila stok/data berubah, sesuaikan selector sebelum demo.
- Semua flow memakai `stopApp` tanpa `clearState`: sesi login tetap dipertahankan, tetapi proses aplikasi di-restart agar navigasi dimulai dari root.

## Menjalankan

Dari root repository (Mac/Linux), sesuaikan ID dengan hasil `adb devices`:

```bash
adb devices
maestro --device nnzxea79ayypnzzx test .maestro/expedition/01_home_catalog.yaml
maestro --device nnzxea79ayypnzzx test --format junit --output maestro-expedition-results.xml --test-output-dir build/maestro-expedition .maestro/expedition
```

Untuk **satu rekaman perjalanan** tanpa siklus tutup-buka aplikasi berulang:

```bash
maestro --device nnzxea79ayypnzzx test .maestro/expedition-video/complete_journey.yaml
```

Alternatif MP4 dengan Maestro (limit rekaman CLI umumnya 2 menit):

```bash
maestro --device nnzxea79ayypnzzx record --local .maestro/expedition-video/complete_journey.yaml
```

Untuk video UTS panjang, gunakan perekam layar bawaan HP atau scrcpy/OBS bersamaan dengan perintah `maestro test`. Artefak screenshot/log tersimpan di folder output Maestro; simpan XML, bukti PNG, serta rekaman ke `uat/results/` setelah benar-benar dijalankan.

## Aturan kejujuran hasil

- File YAML dan screenshot perintah **bukan bukti PASS** sebelum Maestro dijalankan di HP.
- Bila suatu flow FAIL, simpan log/screenshot dan catat failure tersebut. Jangan ubah status menjadi PASS karena flow lain berhasil.
- Jangan menekan `Buat Pesanan`, menghapus produk/alamat, mengubah role, atau menjalankan pembayaran sungguhan tanpa data sandbox.
- UAT-036 sebelumnya FAIL (alamat baru tidak tampil setelah save). EXP-08 hanya menguji validasi form kosong dan **tidak membuktikan bug UAT-036 telah diperbaiki**.
- Data baseline UAT 136 kasus: 14 PASS, 1 FAIL, 3 BLOCKED, 118 NOT RUN, sesuai dokumentasi terakhir. Jangan mengubah statistik sampai ada eksekusi baru.
