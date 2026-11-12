# Laporan UTS Mobile Testing — KKMP Kerten

## 1. Identitas pengujian

- Aplikasi: KKMP Kerten `1.5.4+8`
- Package: `com.fauzibondanp.shopmart`
- Perangkat: Xiaomi Android fisik `nnzxea79ayypnzzx`
- Metode: Maestro MCP, tanpa emulator/cloud
- Sumber kasus: `uat/KKMP_Kerten_UAT_136_Kasus.xlsx`
- Status setelah eksekusi terbaru: **14 PASS, 1 FAIL, 3 BLOCKED, 118 NOT RUN**

## 2. Skenario UAT lengkap

Kriteria penerimaan pada tabel mengikuti expected result workbook. PASS hanya diberikan
untuk hasil yang terlihat pada perangkat; pemeriksaan parsial dicatat pada catatan.

| ID | Tujuan | Peran | Kriteria penerimaan | Prasyarat | Langkah | Expected result | Actual result | Status | Bukti |
|---|---|---|---|---|---|---|---|---|---|
| UAT-013 | Memastikan katalog Home memuat produk aktif | Guest | Produk aktif tampil dengan nama, harga, gambar/fallback yang benar | Produk aktif tersedia | Buka Home; amati katalog | Produk aktif tampil | Produk aktif terlihat pada Home | PASS | [`evidence/screenshots/startup-home.png`](evidence/screenshots/startup-home.png) |
| UAT-015 | Memastikan navigasi kategori | Guest | Hanya produk sesuai kategori yang ditampilkan | Kategori dan produk tersedia | Buka Kategori; pilih Sembako | Produk kategori sesuai tampil | Kategori Sembako terbuka dan produk Gula Pasir terlihat | PASS | [`evidence/screenshots/uat-u15-category-sembako.png`](evidence/screenshots/uat-u15-category-sembako.png) |
| UAT-019 | Memastikan pencarian nama produk | Guest | Product A muncul relevan | Product A aktif | Cari `beras` | Product A muncul relevan | Pencarian `beras` dijalankan dan hasil terlihat | PASS | [`evidence/screenshots/search-results-beras.png`](evidence/screenshots/search-results-beras.png) |
| UAT-021 | Memastikan pencarian tanpa hasil memiliki error state | Guest | Empty search state jelas | Catalog tersedia | Cari `zzzuatnotfound` | Produk tidak ditemukan dan petunjuk alternatif tampil | `Produk tidak ditemukan` dan petunjuk pencarian alternatif terlihat | PASS | [`evidence/screenshots/uat-validation-empty-search.png`](evidence/screenshots/uat-validation-empty-search.png) |
| UAT-023 | Memastikan detail produk dapat dibuka | Guest | Nama, harga, gambar, deskripsi, availability konsisten | Product A aktif | Tap Product A | Detail produk memuat data konsisten | Layar Detail Produk terbuka; seluruh field pembanding belum diaudit | PASS* | [`evidence/screenshots/uat-u23-product-detail.png`](evidence/screenshots/uat-u23-product-detail.png) |
| UAT-029 | Memastikan quantity cart bertambah | Customer | Quantity/subtotal update benar | Product A di cart; stock cukup | Tekan `+` | Quantity dan subtotal berubah | Screenshot menunjukkan quantity 5/subtotal Rp175.000, quantity 8/subtotal Rp280.000, dan checkout quantity 6. Konsisten dengan harga Rp35.000; automated assertion subtotal tidak dijalankan | PASS* | [`evidence/screenshots/uat-cart-plus-attempt.png`](evidence/screenshots/uat-cart-plus-attempt.png), [`evidence/screenshots/uat-cart-plus-second-attempt.png`](evidence/screenshots/uat-cart-plus-second-attempt.png), [`evidence/screenshots/uat-transaction-checkout.png`](evidence/screenshots/uat-transaction-checkout.png) |
| UAT-082 | Memastikan Pusat Bantuan/chat dapat dibuka | Customer | Conversation terbentuk/terbuka normal | Login customer/session tersedia | Buka chat/contact store | Conversation terbuka normal | Pusat Bantuan/chat terbuka; pesan tidak dikirim | PASS* | [`evidence/screenshots/uat-chat-open.png`](evidence/screenshots/uat-chat-open.png) |
| REG-001 | Memastikan checkout tidak blank/white dan semua section utama tampil | Customer | Produk, alamat, pembayaran, voucher, total/action terlihat | Cart berisi produk aktif | Buka Checkout dan tunggu | Checkout sections render tanpa white/empty content | Produk, alamat/fulfillment, COD, voucher/catatan, dan action terlihat; section total/assertion total belum terbukti jelas | PASS* | [`evidence/screenshots/uat-transaction-checkout.png`](evidence/screenshots/uat-transaction-checkout.png) |

`PASS*` berarti navigasi/layar utama terbukti, tetapi sebagian detail expected result
belum diverifikasi penuh. Untuk penilaian dosen, kasus tersebut **bukan sign-off
penuh**. Hitungan baseline tetap mempertahankan status eksekusi PASS sesuai matriks.

### Audit delapan PASS parsial

| Kasus | Yang terbukti | Yang belum terbukti | Kesimpulan audit |
|---|---|---|---|
| UAT-023 | Detail Produk terbuka | Perbandingan lengkap nama, harga, gambar, deskripsi, availability terhadap TD-005 | PASS eksekusi parsial; bukan sign-off penuh |
| UAT-029 | Screenshot membuktikan quantity 5/subtotal Rp175.000 dan quantity 8/subtotal Rp280.000; checkout quantity 6 | Automated assertion subtotal belum dilakukan | PASS eksekusi parsial; bukan sign-off penuh |
| UAT-060 | Create/read produk UAT di Super Admin | Produk active belum dibuka ulang pada katalog customer sebelum archive | PASS eksekusi parsial; bukan sign-off penuh |
| UAT-063 | Harga berubah Rp10.000 menjadi Rp11.000 pada admin/query | Refresh customer sesuai langkah Excel | PASS eksekusi parsial; bukan sign-off penuh |
| UAT-064 | Archive dan hilang dari query publik | Histori aman dan layar customer diverifikasi penuh | PASS eksekusi parsial; bukan sign-off penuh |
| UAT-082 | Pusat Bantuan/chat terbuka tanpa mengirim pesan | Pembuatan conversation baru dan pengiriman pesan | PASS eksekusi parsial; bukan sign-off penuh |
| REG-001 | Section checkout utama terlihat pada screenshot | Section total dan assertion total yang jelas | PASS eksekusi parsial; bukan sign-off penuh |
| REG-013 | Uji pencatatan log dan layar Error Log Center | Refresh eksplisit serta timestamp, severity, source, detail satu per satu | PASS eksekusi parsial; bukan sign-off penuh |

### Hasil pembuatan data uji

`UAT-036` dijalankan pada perangkat fisik dengan seluruh field wajib terisi,
termasuk label `UAT_TEST` dan alamat TD-009. Hierarchy sebelum penyimpanan
membuktikan nilai input. Setelah `Simpan Alamat`, aplikasi kembali ke daftar,
tetapi hanya alamat `Rumah` yang sudah ada terlihat; `UAT_TEST` tidak muncul
dan tidak dapat dipilih ulang. Karena aksi dan expected result sudah diuji,
statusnya **FAIL**, bukan BLOCKED. Bukti: [`evidence/screenshots/uat-address-form-filled.png`](evidence/screenshots/uat-address-form-filled.png),
[`evidence/screenshots/uat-address-save-attempt.png`](evidence/screenshots/uat-address-save-attempt.png), dan
[`evidence/screenshots/uat-address-create-failed.png`](evidence/screenshots/uat-address-create-failed.png).

### Diagnosis dan CRUD Super Admin independen

Penelusuran kode menunjukkan jalur penyimpanan alamat menggunakan
`ShopRepository.addAddress()` dan query daftar `addresses()` dengan filter
`user_id = auth.uid()`. Refresh setelah bottom sheet ditutup juga sudah
terhubung melalui `setState(_reload)`. Karena log Supabase terautentikasi/JWT
tidak tersedia, hasil query REST anonim `[]` tidak cukup untuk menyimpulkan RLS
atau database sebagai akar masalah. Insert/RLS/backend, user yang aktif, dan
refresh tetap belum dapat dipisahkan secara final; UAT-036 dipertahankan sebagai
FAIL karena hasil tersimpan tidak terbukti.

Pengujian independen Super Admin berhasil membuat dan membaca
`UAT_TEST_PRODUK_20261108`, mengubah harga dari Rp10.000 menjadi Rp11.000, lalu
mengarsipkannya melalui UI. Tidak ada kontrol hapus produk pada UI/repository,
sehingga penghapusan langsung ke database tidak dilakukan. Saat dialog produk
disimpan, perangkat juga menampilkan assertion Flutter
`framework.dart:6281 '_dependents.isEmpty'`; ini dicatat sebagai bug lifecycle
Flutter terpisah dari keberhasilan mutasi data. Bukti dan trace ada di
[`uat036_diagnosis_and_admin_crud_20261108-1355.log`](results/uat036_diagnosis_and_admin_crud_20261108-1355.log).

## 3. Flow Maestro dan bukti

| Flow | Cakupan | Assertion | Screenshot/log | Status |
|---|---|---|---|---|
| [`startup.yaml`](../.maestro/startup.yaml) | Pembukaan aplikasi dan Home | Tagline terlihat | `startup-home` | SUDAH TERPENUHI |
| [`pencarian.yaml`](../.maestro/pencarian.yaml) | Navigasi dan pencarian produk | Layar Pencarian, field, dan hasil query | `search-results-beras` | SUDAH TERPENUHI |
| [`keranjang.yaml`](../.maestro/keranjang.yaml) | Navigasi keranjang tanpa mutasi | `Keranjang masih kosong` terlihat | `cart-empty-readonly` | SUDAH TERPENUHI setelah perbaikan sinkronisasi |
| [`customer.yaml`](../.maestro/customer.yaml) | Navigasi akun dan session Super Admin | `KKMP Kerten Super Admin` terlihat | `customer-guest-account` | SUDAH TERPENUHI untuk sesi Super Admin; bukan customer biasa |
| [`error-log-center.yaml`](../.maestro/error-log-center.yaml) | Validasi/error log Super Admin | Error Log Center/log center terlihat | screenshot Error Log Center | BELUM LENGKAP: navigasi menuju modul belum berhasil diulang |
| [`checkout.yaml`](../.maestro/checkout.yaml) | Checkout guard tanpa membuat order | Tagline terlihat | `checkout-blocked-no-mutation` | SUDAH TERPENUHI sebagai guard |
| [`uat-transaction.yaml`](../.maestro/uat-transaction.yaml) | Tambah item ke cart dan membuka checkout COD | Produk, COD, tombol Buat Pesanan | `uat-transaction-cart`, `uat-transaction-checkout` | SUDAH TERPENUHI untuk checkout screen; order final tidak disubmit |
| [`uat-validation.yaml`](../.maestro/uat-validation.yaml) | Validasi pencarian tanpa hasil | `Produk tidak ditemukan` dan petunjuk alternatif | `uat-validation-empty-search` | SUDAH TERPENUHI |

Alur transaksi cart dan checkout screen sudah dijalankan. Submit order final belum
dijalankan karena alamat tersimpan belum dapat dibuktikan sebagai alamat fiktif TD-009.
CRUD Super Admin untuk produk `UAT_TEST_PRODUK_20261108` sudah dijalankan secara
independen: create/read, update harga, dan archive sebagai cleanup. Kontrol delete
produk tidak tersedia pada UI/repository, sehingga tidak dilakukan melalui database.

### Audit bukti tambahan

- **UAT-045:** `INVALID-UAT` ditolak dengan `PostgrestException P0001:
  Voucher invalid or expired`. Penolakan terlihat, tetapi membocorkan error teknis;
  total setelah penolakan belum terbukti tetap. Status tetap **BLOCKED**, bukan PASS.
- **REG-001:** screenshot membuktikan beberapa section checkout, tetapi bukti
  section total/assertion total tidak jelas. Status baseline dipertahankan dengan
  kualifikasi **PASS parsial**, bukan full sign-off.
- `customer.yaml` memeriksa sesi dan role **KKMP Kerten Super Admin**; flow itu
  bukan bukti customer biasa.
- `uat-admin-product-update-result.png` tidak ditemukan dan tidak dirujuk sebagai
  bukti.

## 4. Baseline 136 kasus

| Status | Jumlah |
|---|---:|
| PASS | 14 |
| FAIL | 1 |
| BLOCKED | 3 |
| NOT RUN | 118 |
| Total | 136 |

Matriks lengkap terbaru: [`uat_matrix_current_20261108-1355.csv`](results/uat_matrix_current_20261108-1355.csv)
dan [`uat_matrix_current_20261108-1355.json`](results/uat_matrix_current_20261108-1355.json).
Workbook tersinkronisasi: [`KKMP_Kerten_UAT_136_Kasus_synced_20261110.xlsx`](KKMP_Kerten_UAT_136_Kasus_synced_20261110.xlsx).
Ringkasan final audit: [`uat_execution_summary_20261110.md`](results/uat_execution_summary_20261110.md).
Bukti percobaan alamat: [`maestro_address_attempt_20261108-1331.log`](results/maestro_address_attempt_20261108-1331.log).

## 5. Batasan dan risiko

- Checkout final, pembuatan order, perubahan stok, perubahan role, logout, clear state,
  pengiriman chat, security/RLS, dan offline belum dijalankan.
- Pembuatan alamat UAT_TEST gagal diverifikasi setelah save; checkout COD final
  yang memerlukan alamat tersebut belum dapat dilanjutkan secara valid.
- CRUD produk UAT_TEST sudah dijalankan secara independen. Produk diarsipkan
  sebagai cleanup karena fitur hapus tidak tersedia pada UI/repository.
- Cart item uji sudah dikurangi kembali sampai quantity 1; penghapusan akhir item
  belum dapat diverifikasi secara stabil melalui accessibility tree dan dicatat sebagai
  cleanup yang belum terkonfirmasi.
- Export TXT sudah mencapai opsi Simpan TXT, tetapi reopen file belum diverifikasi.
- `INVALID-UAT` sudah dimasukkan dan tombol `Terapkan` ditekan; feedback penolakan
  yang stabil belum muncul sehingga kasus UAT-045 tetap BLOCKED, bukan PASS.
- Error Log Center menampilkan observasi runtime `setState() callback argument returned
  a Future.` dan diagnostic ListTile; keduanya belum diklasifikasikan sebagai defect
  final tanpa reproduksi dan korelasi kode.

## 6. Checklist persyaratan UTS

| Persyaratan | Status | Bukti |
|---|---|---|
| Minimal 5 skenario UAT lengkap | SUDAH TERPENUHI* | Tabel skenario bagian 2 |
| Minimal 4 flow Maestro | SUDAH TERPENUHI | `.maestro/*.yaml` |
| Assertion + screenshot/log tiap flow | SUDAH TERPENUHI | Flow startup, navigasi, transaksi, validasi, dan cart memiliki assertion+screenshot; error-log tetap belum lulus |
| README tujuan, target, fitur, alur, batasan, instalasi, Maestro | SUDAH TERPENUHI | [`README.md`](../README.md) |
| Source code, folder Maestro, laporan, README | SUDAH TERPENUHI | Repository root, `.maestro/`, `uat/` |
| Minimal 5 commit bermakna | SUDAH TERPENUHI | `git log`: commits aplikasi historis |
| Struktur laporan Markdown | SUDAH TERPENUHI | Dokumen ini |
| Alur transaksi/CRUD aktual | BELUM LENGKAP | Cart add/quantity, checkout screen, dan CRUD produk UAT_TEST terbukti; UAT-036 FAIL; submit final belum dapat diverifikasi |

`*` Perlu peninjauan dosen karena delapan kasus parsial—UAT-023, UAT-029,
UAT-060, UAT-063, UAT-064, UAT-082, REG-001, dan REG-013—belum merupakan
sign-off penuh. Bukti screenshot Maestro tersimpan
sebagai artefak root hasil eksekusi sebelumnya.

## 7. Kesimpulan

Repository memenuhi struktur dokumentasi, source, flow, dan bukti startup, navigasi,
transaksi cart, checkout screen, validasi empty search, serta CRUD produk Super Admin
parsial. Status kelulusan UTS masih **BELUM LENGKAP** untuk submit order COD dan
validasi invalid voucher. UAT-036 dan assertion Flutter tetap menjadi defect terbuka.

## 8. Defect log terbaru

- **DEF-030 / UAT-036 — OPEN:** alamat `UAT_TEST` hilang setelah save. Insert/RLS/backend,
  user/session, dan refresh belum dapat dipisahkan tanpa respons Supabase terautentikasi.
- **DEF-031 / REG-011 — OPEN:** assertion Flutter `_dependents.isEmpty` setelah dialog
  produk disimpan. Produk tetap termutasi, tetapi dialog menampilkan layar kendala.
  REG-011 sendiri tetap **NOT RUN**; relasi ini adalah area regresi terkait, bukan
  bukti bahwa REG-011 telah gagal atau lulus.
- **DEF-032 / UAT-045 — OPEN:** invalid voucher menampilkan `PostgrestException
  P0001`/`Voucher invalid or expired` kepada pengguna; total pasca-penolakan belum
  terverifikasi.
- **DEF-033 / layout observation — OPEN:** dialog Tambah/Edit Produk Global
  menampilkan banner kuning-hitam `OVERFLOWED BY`. Ini terpisah dari DEF-031.
- Detail reproduksi, dampak, dan bukti: [`uat036_diagnosis_and_admin_crud_20261108-1355.log`](results/uat036_diagnosis_and_admin_crud_20261108-1355.log)
  serta [`uat_bugs_20261110.md`](results/uat_bugs_20261110.md) dan sheet
  `03_Defect_Log` pada workbook tersinkronisasi.
