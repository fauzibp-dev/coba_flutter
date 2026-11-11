## Temuan dari pengujian penuh 10 flow — 11 November 2026

Berdasarkan log terminal yang dikirim pengguna: **3 PASS / 7 FAIL**. UTS-01/02/05 PASS; flow lainnya gagal seperti dirinci di [laporan](../../uat/results/maestro_all_cli_20261111_132322.md). Revisi saat ini bersifat **BELUM TERUJI RUNTIME**: reset route app, koreksi nama beras, filter hasil kosong, diagnostik checkout/Super Admin, dan urutan config menggunakan `name:` persis.

**Jangan langsung mengklaim semua PASS.** Setelah `git pull --ff-only` jalankan ulang `bash scripts/run_uts_maestro.sh all` sambil merekam manual lewat Xiaomi. Jika checkout atau Super Admin masih gagal, diperlukan screenshot gagal dari folder debug; tes tetap harus FAIL, bukan dilewati.

---
## Satu kali tes + rekam dari awal sampai akhir (10 flow)

Paket rekaman UTS sekarang berisi **10 flow** (6 flow sebelumnya + 4 skenario tambahan). Setelah tiga smoke test pada 11 November **3/3 PASS**, flow tambahan yang baru dibuat **belum diuji secara runtime**, dan tiga flow auth lama juga belum dikonfirmasi ulang.

**Urutan eksekusi dipaksa melalui `.maestro/uts/config.yaml`:** start, cari produk, urut harga, filter harga, validasi pencarian, tambah/baca cart, checkout draft, validasi alamat, cari SKU Super Admin, isi form produk draft lalu batal. `continueOnFailure: true` sengaja membiarkan tes berikutnya berjalan ketika tes sebelumnya FAIL agar rekaman mencakup keseluruhan. Tiap kegagalan tetap tercatat FAIL, bukan diabaikan.

Semua berjalan dalam **satu proses Maestro**:
```bash
bash scripts/run_uts_maestro.sh all
```

**Sekalian rekam satu video HP** dengan scrcpy (tidak perlu merekam dan menjalankan tes dari dua terminal):
```bash
bash scripts/record_uts_all.sh
```

Skrip ini hanya bekerja jika scrcpy sudah terpasang. Output video MP4 ada di `build/uts-record-<timestamp>/`. Jika scrcpy belum ada, rekam dengan aplikasi perekam layar Xiaomi lalu jalankan `bash scripts/run_uts_maestro.sh all`. Untuk video yang memuat terminal PASS/FAIL juga, gunakan OBS/screen recording Mac.

**Prasyarat:** Login akun customer yang juga memiliki akses Super Admin, `Beras Premium Kerten` aktif/berstok, ADB terhubung, driver Maestro disetujui jika Xiaomi meminta izin. Flow cart menambah item (bisa menaikkan kuantitas pada pengulangan); tidak ada flow yang menekan **Buat Pesanan**, menyimpan produk, menghapus produk, mengganti password, atau mengirim pesan. Tanpa prasyarat, sebagian flow mungkin FAIL dan perlu dicatat.

---
## Catatan eksekusi smoke nyata — 11 November 2026

Pengguna membagikan terminal log `smoke` dari Mac Xiaomi, sebelum runner versi satu-proses digunakan. Tiga flow PASS secara nyata:

- `01_startup.yaml`: PASS, app Home, tagline dan kategori visible, screenshot berhasil diambil (24 detik).
- `02_navigasi_pencarian.yaml`: PASS, Maestro mengetik `beras`, Enter, hasil beras tampil, screenshot berhasil diambil (38 detik).
- `05_validasi_pencarian.yaml`: PASS, Maestro mengetik `zzzuatnotfound`, empty-state dan petunjuk terlihat, screenshot berhasil diambil (39 detik).

Log asal lokal: `build/uts-maestro-20261111-125547-smoke/` di Mac pengguna; output dikirim sebagai teks ke percakapan. Bukti screenshot/JUnit XML masih lokal dan **belum diunggah ke repository**. Runner tersebut memanggil Maestro tiga kali (`1/1 Flow Passed` tiga kali), yang mungkin menjelaskan permintaan instalasi driver di Xiaomi berulang.

Runner sekarang memakai **satu path direktori** `.maestro/uts` dengan `--include-tags=uts-smoke` / `--include-tags=uts-auth`; tidak memakai banyak path YAML sebagai argumen. Wajib jalankan ulang untuk membuktikan pengurangan prompt instalasi driver; perubahan skrip belum dieksekusi di HP.

Lihat `uat/results/maestro_smoke_cli_20261111.md` untuk ringkasan bukti terverifikasi dan batasannya.

---

## Pembaruan 11 November 2026 — jangan ketuk Install setiap flow

**Masalah:** runner sebelumnya memanggil proses `maestro test` **sekali per YAML**. Di Xiaomi/MIUI setiap inisialisasi berpotensi menampilkan permintaan **Install** driver Maestro, sehingga pengguna harus mengizinkan berulang-ulang.

**Perbaikan:** runner baru membuka aplikasi melalui ADB sekali, lalu menjalankan seluruh flow smoke/auth/all yang dipilih dalam **satu pemanggilan `maestro test`**. JUnit, log dan screenshot tetap dikumpulkan. Perintah `doctor` tidak melakukan testing. Tidak menginstal ulang APK KKMP Kerten.

```bash
git fetch origin
git switch test/maestro-exploration-20261111
git pull --ff-only
bash scripts/run_uts_maestro.sh smoke
```

Jika masih muncul jendela **Install** walaupun sekali per run, lihat nama aplikasinya. Jika menyebut **Maestro** atau `dev.mobile.maestro`, itu driver pengujian, bukan KKMP Kerten. Xiaomi/MIUI kadang meminta persetujuan instalasi lewat USB. Jangan menonaktifkan Play Protect secara umum; lihat pengaturan izin instalasi USB hanya jika memang diperlukan dan installer dapat diverifikasi. Jika prompt justru menyebut **KKMP Kerten**, kirim fotonya agar penyebabnya dipastikan.

Bukti hasil berada di `build/uts-maestro-<waktu>-<mode>/junit.xml`, `terminal.log`, `artifacts/` dan `debug/`. Satu proses CLI dapat melanjutkan flow berikutnya walau flow sebelumnya FAIL, sehingga evaluasi per-flow tetap dilakukan dari JUnit.

---

# PERBAIKAN STARTUP XIAOMI — 11 NOVEMBER 2026

Pengguna melaporkan smoke FAIL sebelum aplikasi terbuka. Pada perangkat ini pola `launchApp` pernah tidak andal; kode flow kini kembali memakai pola launcher dari `.maestro/startup.yaml` yang pernah PASS.

Script baru memeriksa ADB, memvalidasi `pm path` (termasuk output kosong), memulai KKMP Kerten via ADB `monkey` tanpa menghapus sesi, menyimpan `preflight.png` dan `launch.log`, lalu menjalankan YAML secara berurutan dan berhenti pada FAIL pertama. Proses aplikasi hidup **belum membuktikan layar UI benar-benar tampil**; periksa layar HP/screenshot sebelum menjalankan smoke.

```bash
git fetch origin
git switch test/maestro-exploration-20261111
git pull --ff-only
bash scripts/run_uts_maestro.sh doctor
# HANYA jika KKMP Kerten sudah terlihat pada HP:
bash scripts/run_uts_maestro.sh smoke
```

Gunakan `auth` atau `all` setelah smoke berhasil dan session login tersedia. Output: `build/uts-maestro-<waktu>-<mode>/` — tiap flow memiliki JUnit XML, log, screenshot dan debug. **Status PASS belum tersedia hingga dieksekusi pada HP.**

---

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
