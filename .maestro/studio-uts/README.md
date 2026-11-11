## Tambahan UTS-14 — CRUD keranjang lengkap (belum diuji)

Pengujian Studio awal **12/12 PASS** tetap berlaku untuk 12 flow lama. UTS-03 **hanya** CREATE dan READ keranjang; tidak pernah menekan +/- atau hapus. Jangan klaim sudah CRUD lengkap dari UTS-03.

Flow `14_crud_keranjang_lengkap.yaml` baru ditambahkan untuk benar-benar melakukan:
1. Guard `Tes Produk` **belum** ada di cart, agar tidak menghapus barang lama.
2. CREATE: menambahkan Tes Produk satu kali.
3. READ: assert kuantitas 1, screenshot.
4. UPDATE (+): tap tombol tambah, assert kuantitas 2, screenshot.
5. UPDATE (-): tap tombol kurang, assert kuantitas 1, screenshot.
6. DELETE: tap ikon hapus **Tes Produk saja**, pastikan item hilang dan tidak kembali setelah restart.

**Perlu APK baru:** tombol +/- sebelumnya tidak punya label aksesibilitas. Source `lib/screens/cart_screen.dart` sekarang memberi Semantics untuk +/- dan quantity, serta tooltip hapus. Build di Mac dengan `flutter build apk --debug`, lalu `adb install -r build/app/outputs/flutter-apk/app-debug.apk`. `adb install -r` mempertahankan data lokal, tetapi gunakan aplikasi yang cocok dengan konfigurasi Supabase pengujian.

Tes produk "Tes Produk" harus aktif/berstok dan belum ada di cart. Kalau sudah ada, guard sengaja FAIL dan tes tidak menghapus item lama. Setelah instalasi, jalankan flow 14 saja di Studio terlebih dahulu; 13/13 PASS hanya boleh dilaporkan setelah dibuktikan perangkat.

---
## Koreksi berdasarkan screenshot Maestro Studio (11 November 2026, 14.47 WIB)

Pengguna melaporkan **hanya tiga flow FAIL** pada suite customer Studio: UTS-06, UTS-12, dan UTS-13. Screenshot menunjukkan:

- **UTS-06**: halaman detail sudah terbuka, `Detail Produk` dan `Beli Sekarang` terbaca; `scrollUntilVisible` gagal menemukan `Deskripsi Produk`. Kini ada screenshot sebelum scroll, swipe di area scrollable ListView, dan pencocokan regex DOTALL + visibility 50%.
- **UTS-12**: layar **Keamanan & Preferensi** sudah terbuka, tetapi `assertVisible: "Ganti password"` gagal walau title tile terlihat. Pada Flutter `ListTile`, title dan subtitle dapat digabung dalam satu accessibility text. Diganti regex DOTALL dan cek tombol dialog, lalu **Batal** tanpa mengganti password.
- **UTS-13**: tampilan chat **Pusat Bantuan** sudah terbuka, namun `assertVisible: "Pusat Bantuan"` gagal. `AppBar` berisi title dan subtitle, yang dapat menjadi satu node aksesibilitas. Diganti regex DOTALL; assertion `Tulis pesan...` tetap wajib.

Tiga file saja yang berubah. **Sembilan flow lain, termasuk lima flow sebelumnya yang pernah PASS, tidak diubah**. Tiga flow revisi **belum dijalankan di HP**, jangan mengklaim 12/12 PASS sebelum hasil Maestro Studio baru ada.

Untuk memperbarui Mac:
```bash
git switch test/maestro-exploration-20261111
git pull --ff-only
```

Maestro Studio workspace: `/Users/fauzibondanp/Desktop/coba_flutter/.maestro/studio-uts`; jika editor tidak memuat perubahan, tutup/buka file atau workspace. Pilih perangkat Xiaomi, **Local → Run All Tests**; rekam manual bila perlu.

---

# UTS Maestro Studio — 12 flow customer KKMP Kerten

**Dibuat pada 11 November 2026. Semua pengujian customer saja. Tidak ada YAML Super Admin di workspace ini.**

## Apa yang sudah terbukti

Lima flow lama di bawah ini **sudah PASS 5/5 di Maestro Studio**, sesuai screenshot yang dibagikan pengguna (durasi 3:17). File YAML-nya **tidak diubah**:

- `01_startup.yaml`: membuka aplikasi / katalog
- `02_navigasi_pencarian.yaml`: navigasi dan input keyword
- `03_cart_create_read.yaml`: tambah keranjang dan baca ulang setelah restart app (mengubah keranjang)
- `05_validasi_pencarian.yaml`: keyword tidak tersedia menampilkan empty-state
- `07_urutkan_harga.yaml`: pilihan harga terendah

## 7 flow customer baru — belum dieksekusi

| YAML | Tujuan | Risiko/Prasyarat |
|---|---|---|
| `06_detail_produk.yaml` | Cari beras → buka detail → cek deskripsi dan tombol beli | Produk beras tersedia |
| `08_wishlist_customer.yaml` | Masuk akun → buka Wishlist | Harus login |
| `09_riwayat_pesanan.yaml` | Buka tab Pesanan Saya | Harus login |
| `10_notifikasi_customer.yaml` | Masuk akun → halaman Notifikasi dan Baca semua terlihat | Harus login; tidak mengubah read status |
| `11_validasi_alamat.yaml` | Menu alamat → formulir baru → simpan kosong → peringatan wajib diisi | Harus login; tidak mengirim alamat |
| `12_keamanan_akun.yaml` | Menu keamanan → dialog ganti password → batal | Harus login; tidak mengganti password |
| `13_pusat_bantuan.yaml` | Masuk Pusat Bantuan → pastikan input Tulis pesan tampil | Harus login; tergantung layanan chat; tidak mengirim pesan |

**Penting:** Jika login hilang saat mencoba flow customer, lakukan login manual di HP *sebelum* menjalankan semua flow. File tidak menyimpan email/password/token. Beberapa halaman bergantung pada data Supabase, jadi hasil FAIL harus tetap dicatat dan dianalisis di Studio, jangan diubah jadi PASS hanya dengan membuang assertion.

## Eksekusi di Maestro Studio (tanpa skrip/Cloud)

1. Buka workspace `/Users/fauzibondanp/Desktop/coba_flutter/.maestro/studio-uts` di Studio.
2. Pastikan Xiaomi Android fisik dipilih dan **Local** aktif.
3. Jalankan `Run All Tests`; Maestro menyimpan status langkah, screenshot, dan log. `continueOnFailure: true` memberi hasil per-flow tanpa menutupi flow yang gagal.
4. Rekam manual di HP apabila akan dipakai untuk video UTS.

Nama lengkap tiap flow pada `config.yaml` mengatur urutan, sehingga flow dibuka dahulu, baru katalog/customer transaksi/akun.

**Jangan jalankan** `.maestro/uts` sebagai workspace Studio jika hanya ingin tes customer, karena folder lama berisi flow Super Admin.

---

## Catatan versi sebelumnya

# KKMP Kerten — Workspace Maestro Studio (Xiaomi fisik)

Workspace ini disiapkan langsung lewat GitHub. **Tidak perlu membuat file satu per satu di GUI.**

## Yang disiapkan

- 01: pembukaan app dan katalog
- 02: navigasi, input pencarian beras
- 07: urut harga terendah
- 05: validasi pencarian tidak ditemukan
- 03: tambah produk beras ke keranjang dan cek masih ada setelah aplikasi dihentikan/dibuka

Kelima flow ini **pernah PASS pada Maestro CLI di HP Xiaomi** menurut log dari pengguna yang dikirim 11 Nov 2026 sekitar pukul 13.40 WIB. Ini **bukan** klaim bahwa flow sudah dijalankan lewat Studio. Uji ulang untuk memastikan Studio memberi hasil yang sama.

Semua flow berisi assertion dan screenshot. UTS mencakup startup, navigasi, transaksi/CRUD keranjang, dan validasi error.

## Cara menjalankan melalui Maestro Studio

1. Di Mac, `git switch test/maestro-exploration-20261111 && git pull --ff-only`.
2. Di Studio, pilih atau ganti workspace location ke folder **`/Users/fauzibondanp/Desktop/coba_flutter/.maestro/studio-uts`**, bukan root `coba_flutter` yang memiliki banyak flow eksperimen lama.
3. Pastikan perangkat `nnzxea79ayypnzzx` terdeteksi dengan status Android.
4. Buka `01_startup.yaml` lalu klik Run Test / Run Locally, atau **Run All Tests** untuk lima flow.
5. Gunakan **Inspect Screen** / **Run and Insert** untuk memilih selector yang benar dari layar, hanya jika ada yang gagal. Tidak perlu mengetik semua YAML dari nol.
6. Rekam layar manual di HP bila diperlukan; tidak membutuhkan scrcpy atau Cloud.

## Batasan

- Folder ini sengaja hanya memuat **5 flow yang sudah punya bukti PASS**. Lima flow lain di `.maestro/uts/` belum stabil (checkout, alamat, filter, Super Admin) sehingga tidak ikut dimasukkan ke Run All Tests Studio.
- Flow keranjang **menambah item** pada akun aktif, tidak membuat pesanan sungguhan.
- Jika UTS meminta laporan lebih luas, status dan bukti semua 10 flow lama masih ada di `uat/results/maestro_all_cli_20261111_132322.md` dan log Mac pengguna.
- Jika suatu saat membuat flow tambahan, gunakan Studio Inspect Screen dan masukkan file ke folder ini setelah benar-benar diuji.


