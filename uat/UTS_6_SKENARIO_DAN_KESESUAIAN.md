# Audit kesesuaian soal UTS Mobile Testing — KKMP Kerten

Dokumen acuan: **UTS Mobile Testing TI23B, Tahun Akademik 2026/2027, halaman 1-2**. Disusun 11 November 2026. Pemetaan di bawah berdasarkan repository dan hasil UAT terdahulu. Flow Maestro `.maestro/uts/` **belum dieksekusi setelah disusun**, sehingga tidak dinyatakan PASS.

## Enam skenario UAT pilihan untuk pengumpulan (syarat minimal 5)

| ID | Tujuan | Persona | Kriteria penerimaan dan hasil yang diharapkan | Prasyarat | Langkah | Hasil aktual terdokumentasi | Status bukti lama | Flow baru | Bukti lama |
|---|---|---|---|---|---|---|---|---|---|
| UAT-013 | Katalog beranda tampil | Guest | Produk aktif terlihat dan halaman awal tidak blank | Backend katalog tersedia | Jalankan aplikasi, tunggu Home | Produk aktif tampil pada Home | PASS (historis) | 01 | [startup-home.png](../startup-home.png) |
| UAT-019 | Pencarian produk | Guest | Kueri beras menghasilkan produk relevan | Ada produk beras aktif | Buka pencarian, input beras, submit | Hasil beras terlihat | PASS (historis) | 02 | [search-results-beras.png](../search-results-beras.png) |
| UAT-029 | Pengelolaan quantity/cart | Customer | Keranjang memuat item yang ditambahkan, subtotal/quantity konsisten dan bertahan setelah aplikasi dibuka ulang | Akun login; produk tersedia berstok | Cari produk, Beli Sekarang, buka ulang app, cek cart | Bukti historis quantity/subtotal konsisten pada screenshot; assertion persistensi belum dieksekusi | PASS parsial (historis) | 03 | [uat-cart-plus-attempt.png](../uat-cart-plus-attempt.png), [uat-transaction-cart.png](../uat-transaction-cart.png) |
| REG-001 | Halaman checkout bukan layar putih | Customer | Section alamat, produk, metode bayar, ringkasan server dan tombol order tampil, server quote memberi total | Keranjang tidak kosong; akun login | Cart → Checkout → Ambil → Hitung Total Final | Checkout tampil; total server belum terverifikasi penuh | PASS parsial (historis) | 04 | [uat-transaction-checkout.png](../uat-transaction-checkout.png) |
| UAT-021 | Validasi kata kunci tak ditemukan | Guest | Empty state jelas beserta saran | Katalog berjalan | Cari zzzuatnotfound | Produk tidak ditemukan dan petunjuk alternatif tampil | PASS (historis) | 05 | [uat-validation-empty-search.png](../uat-validation-empty-search.png) |
| UAT-036 | Simpan alamat pengguna | Customer | Data alamat valid tersimpan dan dapat dilihat kembali; kolom wajib kosong menampilkan error | Akun customer login | Isi form, simpan, buka ulang daftar; uji juga validasi wajib kosong | Alamat UAT_TEST tidak tampil setelah save | FAIL (historis, belum diperbaiki) | 06 hanya menguji validasi wajib kosong; **tidak** mengulang pengujian save | [uat-address-form-filled.png](../uat-address-form-filled.png), [uat-address-create-failed.png](../uat-address-create-failed.png) |

Catatan: Status historis berasal dari `uat/UTS_UAT_REPORT.md` dan `uat/results/uat_execution_summary_20261110.md`, bukan hasil flow Maestro yang baru. Jangan memindahkan PASS historis ke hasil run 11 November tanpa eksekusi aktual. Sebagai batas pengujian, flow 03 membuktikan **CRUD CREATE/READ** pada keranjang; flow 04 membuktikan proses checkout hanya sampai kalkulasi server dan **tidak** membuat order final.

## Checklist persyaratan soal

| Poin soal | Hasil audit | Tindak lanjut |
|---|---|---|
| README tujuan, target, fitur, alur, batas | Ada | Pertahankan dokumentasi akar |
| README nama, NIM, kelas, peran | **Belum lengkap** | Isi identitas nyata pada bagian identitas README. Tidak boleh menggunakan nama/NIM dari project orang lain |
| UAT ≥5, memuat tujuan, peran, kriteria, prasyarat, langkah, hasil, status, bukti | Ada enam skenario di dokumen ini | Bukti lama ada; hasil pengujian ulang CLI perlu diisi setelah eksekusi |
| Maestro ≥4: launch, navigasi, transaksi/CRUD, error validation | **6 file disiapkan** di `.maestro/uts/` | Jalankan di Android fisik dan koreksi selector berdasarkan log; flow 03 create/read cart, 04 checkout quote |
| Tiap Maestro flow assertion + log/screenshot/rekaman | Assertion dan perintah screenshot ada di YAML | File eksekusi terbaru **belum tersedia** |
| Larangan menyimpan kredensial / API key | **Perlu ditinjau sebelum dikumpulkan**: `lib/core/config/supabase_config.dart` saat ini memuat **Supabase publishable key** sebagai default build. Publishable key bukan service-role secret dan memang ditujukan untuk client, namun lembar soal secara eksplisit melarang API key di repository. Pilihan patuh secara literal: pindahkan nilai default ke konfigurasi lokal `--dart-define`, exclude file lokal dari Git, dan uji kembali build | 
| Minimal 5 commit bermakna | Riwayat `main` menunjukkan >5 commit | Tampilkan Git history dalam video |
| Source dan APK / petunjuk menjalankan | Source Flutter dan petunjuk `flutter run` tersedia | APK debug dapat dibangun lokal jika dibutuhkan |
| Laporan UAT PDF atau Markdown dengan temuan | `uat/UTS_UAT_REPORT.md` tersedia | Lampirkan ringkasan bug UAT-036 dan screenshot |
| Cara instalasi, eksekusi, hasil | README UTS dan runner baru tersedia | Masukkan file log/JUnit/screenshots dari run baru |
| Video 5–10 menit + URL | **Belum ada URL** | Rekam, upload, tautkan (atur akses dosen) |
| Tautan repo dapat dibuka dosen | GitHub masih **private** | Undang akun dosen sebagai collaborator atau atur akses yang disetujui; uji tautan |
| Kumpulkan via e-learning | Belum dapat diverifikasi dari repository | Serahkan semua tautan/berkas di e-learning |

## Lima kriteria penilaian dari soal

- Kelengkapan dan ketepatan UAT: **25%**.
- Kualitas dan cakupan Maestro: **30%**.
- Fungsionalitas aplikasi dan keterulangan: **20%**.
- Dokumentasi dan video: **15%**.
- Kerapian repository dan Git: **10%**.

## Bukti yang masih perlu direkam

- Terminal PASS/FAIL dari eksekusi 6 flow baru di HP Xiaomi.
- File JUnit, log command dan screenshot, termasuk kondisi FAIL bila ada.
- Video penjelasan 5–10 menit yang memuat identitas mahasiswa, konteks KKMP Kerten, UAT, alur Maestro CRUD keranjang/checkout dan validasi kesalahan.
- UAT-036 disampaikan sebagai bug yang ditemukan, bukan disembunyikan.

Dokumen ini menilai kesesuaian komponen **yang disiapkan**, bukan menjamin aplikasi lulus tes otomatis. Jika run baru FAIL, selesaikan diagnosis sebelum mengklaim hasil.

## Tambahan pengujian untuk rekaman penuh (11 November 2026)

| ID tambahan | Area | Input/aksi dan assert | Bukti | Status |
|---|---|---|---|---|
| UTS-07 | Pengurutan produk | Pilih Harga terendah dan assert opsi aktif | `uts-07-sort-price` | NOT RUN |
| UTS-08 | Filter harga | Ketik harga minimum 10000 lalu assert 1 filter aktif | `uts-08-price-filter` | NOT RUN |
| UTS-09 | Super Admin SKU | Ketik SKU dummy dan assert Produk tidak ditemukan | `uts-09-superadmin-sku-invalid` | NOT RUN |
| UTS-10 | Super Admin produk | Isi nama dan harga pada form produk lalu Batal (tanpa INSERT) | `uts-10-product-draft`, `uts-10-product-cancelled` | NOT RUN |

Semua 10 flow dieksekusi dari satu proses Maestro lokal menggunakan `config.yaml` untuk urutan; `continueOnFailure: true` memberi rangkaian yang tetap berlanjut bila satu test gagal. Flow baru 07–10 **belum diuji pada perangkat**. Bukti yang lengkap harus diambil setelah eksekusi, bukan sekadar berdasar YAML.
