# Paket Maestro khusus UTS Mobile Testing 2026/2027

Sumber: `UTS_mobile_testing_ti_23_B(2).pdf`, ketentuan C.3-4.

**6 YAML mandiri** dengan assertion dan instruksi screenshot. Paket ini belum pernah dijalankan pada perangkat setelah commit: **READY TO TEST, bukan PASS.**

| Flow | Uji | Kelompok | Bukti |
|---|---|---|---|
| 01_startup.yaml | Launch dan Home | smoke | uts-01-startup |
| 02_navigasi_pencarian.yaml | Navigasi Home ke Search dan input beras | smoke | uts-02-navigasi-cari |
| 03_cart_create_read.yaml | Tambah keranjang, baca kembali setelah restart app tanpa hapus state | auth | uts-03-cart-created, uts-03-cart-persisted |
| 04_checkout_quote.yaml | Cart, checkout pickup, server quote | auth | uts-04-cart, uts-04-quote |
| 05_validasi_pencarian.yaml | Kata kunci tidak ditemukan | smoke | uts-05-invalid-search |
| 06_validasi_alamat.yaml | Wajib isi form alamat | auth | uts-06-address-required |

## Cara menjalankan (Mac dan Android fisik)

1. Instal Flutter dan Android Platform Tools/ADB. Maestro CLI: lihat https://docs.maestro.dev/get-started/installing-maestro.
2. `adb devices` — pastikan ID perangkat aktif.
3. `flutter pub get`, kemudian `flutter run -d nnzxea79ayypnzzx` bila aplikasi belum ada.
4. Masuk dengan akun UAT yang sesuai pada HP; flow `auth` memerlukan sesi login yang tetap tersimpan.

```bash
bash scripts/run_uts_maestro.sh smoke  # 01, 02, 05; tanpa login
bash scripts/run_uts_maestro.sh auth   # 03, 04, 06; butuh login, produk, stok
bash scripts/run_uts_maestro.sh all    # seluruh 6 flow; jangan jalankan sebagai guest
```

**Aturan:**
- Semua flow memakai `launchApp(clearState:false)` sehingga tidak logout dan tidak menghapus data lokal.
- Flow 03 dan 04 menambah item ke keranjang (perubahan nyata), tidak membuat order/payment. Pengulangan dapat menambah quantity dan berisiko melampaui stok; jalankan di akun/data uji dan periksa cart sebelum mengulang.
- Flow 04 **hanya sampai server quote**, tidak mengklaim pembayaran/pesanan selesai. Jika quote gagal, laporkan hasil FAIL.
- Flow 06 memicu validasi form kosong; tidak menyimpan alamat.
- Label produk `Beras Premium Kerten` berdasar eksekusi sebelumnya. Data backend bisa berubah.
- Setiap perintah screenshot baru menjadi bukti hanya jika HP benar-benar menjalankannya. Hasil PASS/FAIL berasal dari JUnit/log CLI yang tersimpan.
- Jika selector gagal, pakai `maestro hierarchy`/Studio untuk memeriksa accessibility tree; jangan mengubah assertion semata-mata supaya jadi PASS.

Output `build/uts-maestro-<waktu>-<mode>/` berisi `junit.xml`, `terminal.log`, screenshot/command traces dan log debug. Salin hasil nyata yang ingin dikumpulkan ke `uat/results/` setelah diperiksa (hindari data sensitif).
