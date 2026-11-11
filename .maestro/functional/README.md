# Paket perbaikan Maestro fungsional

Dibuat berdasarkan source Flutter dan laporan UAT lama. **BELUM dijalankan di HP fisik; jangan dianggap PASS.**

## Masalah yang diperbaiki
- Boot tidak lagi mengetuk ikon launcher, tetapi memakai `launchApp: {clearState: false}`.
- Home membuka halaman SearchScreen standalone, judulnya **Pencarian** (bukan `Cari Produk` yang hanya muncul ketika embedded).
- 18 tes utama mencakup mengetik pencarian, memilih sorting, mengisi filter, validasi alamat, mengisi draf form dan pencarian admin.
- 3 tes opsional di `../functional-optional/` memerlukan chat yang aktif atau keranjang berisi produk.

## Jalankan dari root repository
```bash
git fetch origin
git switch test/maestro-exploration-20261111
git pull
adb devices
bash scripts/run_maestro_functional.sh smoke
bash scripts/run_maestro_functional.sh customer
bash scripts/run_maestro_functional.sh superadmin
bash scripts/run_maestro_functional.sh all
```

Output setiap eksekusi: `build/maestro-functional-<timestamp>-<mode>/` berisi JUnit report, log terminal, screenshots/debug.

**Penting:** Flow `draft` menuliskan input lalu membatalkan (tidak menyimpan perubahan akun, toko, kategori, produk, voucher). `address_validation` sengaja menyimpan dengan data wajib kosong agar hanya memunculkan validasi. Flow checkout opsional tidak membuat pesanan. Query pencarian dapat memodifikasi history.

Folder `.maestro/expedition` 50-flow lama bukan bukti fungsi input. Bila ada FAIL lagi, kirim bagian terminal error dan artefak debug — kita perlu tahu command persis yang gagal.
