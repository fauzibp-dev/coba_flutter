# Laporan UTS Maestro Studio — KKMP Kerten

**Konteks:** UTS Mobile Testing 2026/2027, pengujian customer pada aplikasi Flutter Android KKMP Kerten.  
**Perangkat:** Xiaomi Android fisik, Maestro Studio mode Local (bukan Cloud).  
**App ID:** `com.fauzibondanp.shopmart`  
**Hasil terverifikasi dari screenshot pengguna, 11 November 2026:** **12/12 PASS, 0 FAIL**, durasi **6 menit 52 detik**.  
**Identitas:** [Nama resmi], [NIM], kelas TI23B [verifikasi], [peran] — lengkapi sebelum pengumpulan.  
**Tautan video 5–10 menit:** [belum diisi].

## Metodologi

- Maestro Studio di Mac menjalankan 12 YAML pada HP Xiaomi fisik melalui ADB.
- Setiap flow melakukan assertion pada elemen penting dan memiliki perintah `takeScreenshot`.
- Sesi customer harus login sebelum menjalankan flow akun, cart, pesanan dan bantuan.
- Flow customer tidak menyimpan password baru, tidak mengirim pesan, tidak membuat pesanan final dan tidak menguji Super Admin.
- **12/12 PASS merupakan hasil Maestro Studio, bukan 136/136 PASS UAT dan bukan hasil MCP Server.**

## Matriks pengujian (ringkas)

| ID | Flow | Persona/prasyarat | Langkah dan kriteria penerimaan | Actual | Status | Screenshot asli |
|---|---|---|---|---|---|---|
| ST-01 | [01_startup.yaml](../.maestro/studio-uts/01_startup.yaml) | Guest, APK terpasang | Buka aplikasi, Beranda, tagline dan kategori; elemen tujuan harus terlihat | Elemen yang diperiksa terdeteksi saat run Studio | **PASS** | `uts-01-startup.png` |
| ST-02 | [02_navigasi_pencarian.yaml](../.maestro/studio-uts/02_navigasi_pencarian.yaml) | Guest, APK terpasang | Cari beras dan pastikan hasil tampil; elemen tujuan harus terlihat | Elemen yang diperiksa terdeteksi saat run Studio | **PASS** | `uts-02-navigasi-cari.png` |
| ST-03 | [05_validasi_pencarian.yaml](../.maestro/studio-uts/05_validasi_pencarian.yaml) | Guest, APK terpasang | Cari zzzuatnotfound, verifikasi empty state; elemen tujuan harus terlihat | Elemen yang diperiksa terdeteksi saat run Studio | **PASS** | `uts-05-invalid-search.png` |
| ST-04 | [07_urutkan_harga.yaml](../.maestro/studio-uts/07_urutkan_harga.yaml) | Guest, APK terpasang | Pilih harga terendah, verifikasi pilihan; elemen tujuan harus terlihat | Elemen yang diperiksa terdeteksi saat run Studio | **PASS** | `uts-07-sort-price.png` |
| ST-05 | [06_detail_produk.yaml](../.maestro/studio-uts/06_detail_produk.yaml) | Guest, APK terpasang | Buka detail beras, verifikasi deskripsi produk; elemen tujuan harus terlihat | Elemen yang diperiksa terdeteksi saat run Studio | **PASS** | `studio-uts-06-detail-produk.png` |
| ST-06 | [03_cart_create_read.yaml](../.maestro/studio-uts/03_cart_create_read.yaml) | Customer login, APK terpasang | Tambah beras ke keranjang, buka ulang, cek persistensi; elemen tujuan harus terlihat | Elemen yang diperiksa terdeteksi saat run Studio | **PASS** | `uts-03-cart-persisted.png` |
| ST-07 | [08_wishlist_customer.yaml](../.maestro/studio-uts/08_wishlist_customer.yaml) | Customer login, APK terpasang | Akun → Wishlist dan verifikasi halaman; elemen tujuan harus terlihat | Elemen yang diperiksa terdeteksi saat run Studio | **PASS** | `studio-uts-08-wishlist.png` |
| ST-08 | [09_riwayat_pesanan.yaml](../.maestro/studio-uts/09_riwayat_pesanan.yaml) | Customer login, APK terpasang | Buka Pesanan Saya, verifikasi daftar; elemen tujuan harus terlihat | Elemen yang diperiksa terdeteksi saat run Studio | **PASS** | `studio-uts-09-pesanan.png` |
| ST-09 | [10_notifikasi_customer.yaml](../.maestro/studio-uts/10_notifikasi_customer.yaml) | Customer login, APK terpasang | Akun → Notifikasi, verifikasi Baca semua; elemen tujuan harus terlihat | Elemen yang diperiksa terdeteksi saat run Studio | **PASS** | `studio-uts-10-notifikasi.png` |
| ST-10 | [11_validasi_alamat.yaml](../.maestro/studio-uts/11_validasi_alamat.yaml) | Customer login, APK terpasang | Buka Tambah Alamat, simpan kosong, cek Wajib diisi; elemen tujuan harus terlihat | Elemen yang diperiksa terdeteksi saat run Studio | **PASS** | `studio-uts-11-alamat-kosong.png` |
| ST-11 | [12_keamanan_akun.yaml](../.maestro/studio-uts/12_keamanan_akun.yaml) | Customer login, APK terpasang | Dialog Ganti Password, lalu Batal; elemen tujuan harus terlihat | Elemen yang diperiksa terdeteksi saat run Studio | **PASS** | `studio-uts-12-dialog-password.png` |
| ST-12 | [13_pusat_bantuan.yaml](../.maestro/studio-uts/13_pusat_bantuan.yaml) | Customer login, APK terpasang | Buka Pusat Bantuan, verifikasi kolom Tulis pesan; elemen tujuan harus terlihat | Elemen yang diperiksa terdeteksi saat run Studio | **PASS** | `studio-uts-13-chat.png` |

## Penjelasan empat persyaratan Maestro pada soal UTS

1. **Pembukaan aplikasi:** 01 startup menguji Beranda, tagline dan kategori.
2. **Navigasi:** 02 pencarian, 07 sorting, 08 Wishlist, 09 Pesanan, 10 Notifikasi, dan 13 Bantuan.
3. **Transaksi/CRUD:** 03 menambahkan dan membaca ulang keranjang setelah aplikasi dibuka kembali (**CREATE/READ**); bukan submit order.
4. **Validasi kesalahan:** 05 produk tidak ditemukan, 11 form alamat kosong menghasilkan `Wajib diisi.`.

## Pengamatan dan batasan

- Layar detail produk menunjukkan deskripsi, tetapi ini tidak membuktikan semua data produk benar terhadap basis data.
- Gambar keranjang menunjukkan beras dan subtotal; assertion YAML membuktikan persistensi cart, bukan pengujian aritmetika lengkap semua harga.
- Validasi alamat kosong PASS **tidak** membuktikan bug MCP UAT-036 (alamat valid tidak tersimpan) selesai.
- Skenario keamanan membuka dialog dan memilih Batal. Tidak ada perubahan password.
- Fitur Pusat Bantuan dibuka tanpa mengirim pesan customer service.
- Tiga error selector pada run awal (detail produk, Ganti password, Pusat Bantuan) telah dikoreksi sebelum hasil 12/12 PASS.

## Bukti dan dokumentasi

Bukti foto asli ada pada Mac penguji di `~/.maestro/tests/2026-11-11_161134/artifacts/takeScreenshot/`. Folder GitHub `uat/evidence/maestro-studio/` disediakan untuk arsip setelah ditinjau. **Saat dokumen ini pertama kali dibuat, gambar belum disalin ke repo**, sehingga jangan mengklaim sudah tersimpan di GitHub tanpa memeriksa foldernya.

Jalankan `bash scripts/push_maestro_studio_evidence.sh` dari proyek Mac untuk menyalin hasil, memeriksa privasi, dan melakukan commit/push setelah persetujuan. Laporan Word/PDF yang sudah dibuat secara terpisah dapat ditambahkan melalui skrip bila tersimpan di Downloads.

## Kesesuaian pengumpulan UTS

Syarat minimal 5 skenario UAT, minimal 4 YAML, assertion, screenshot/log, README, source code, petunjuk perangkat, 5 commit bermakna: **ada cakupan di proyek**. Namun identitas resmi, video 5–10 menit beserta URL, akses dosen ke repo privat, dan larangan API key pada kode sumber harus dituntaskan sebelum pengumpulan.

## Kesimpulan

12 flow Maestro Studio yang berfokus pada pelanggan sudah menunjukkan **PASS 12/12** dalam eksekusi lokal di Xiaomi. Laporan ini dipisahkan dari hasil Maestro MCP Server: 14 PASS, 1 FAIL, 3 BLOCKED, 118 NOT RUN pada matriks 136 kasus UAT. Status UAT MCP tidak boleh digabung dengan status 12 flow Studio.

## Lampiran tambahan UTS-14 (belum diuji; tidak termasuk 12/12 PASS)

Penguji mengonfirmasi bahwa alur UTS-03 sebelumnya hanya menambah dan membaca isi keranjang, tidak menekan tombol `+`, `−`, atau hapus. Maka kategorinya adalah CREATE/READ parsial, bukan CRUD lengkap. Agar cakupan lebih kuat, ditambahkan [UTS-14 CRUD lengkap keranjang](../.maestro/studio-uts/14_crud_keranjang_lengkap.yaml) dengan assertion sebelum/sesudah update serta delete dan screenshot `uts-14-*.png`.

Flow baru **NOT RUN**, belum termasuk hasil 12/12 PASS. Perubahan Semantics pada Flutter memerlukan pembangunan dan pemasangan APK baru; jangan mengubah catatan sejarah 12/12 sebelum eksekusi terbaru.

## Koreksi bug keranjang setelah hasil Studio 12/12 PASS

Pengguna menguji tombol **+**, **−**, dan hapus secara manual dan melaporkan tidak ada perubahan. Pemeriksaan log Supabase pada 11 November 2026 menunjukkan RPC `set_cart_quantity` beberapa kali sukses **HTTP 204**, tetapi ada juga **HTTP 400** dengan pesan `Cart item not found`. Kode Flutter saat itu tidak menangkap error pada ketiga tombol, sehingga operasi yang gagal tidak memberi umpan balik ke pengguna.

Perubahan pada branch uji: permintaan kuantitas/hapus dijalankan **satu per satu**, indikator proses tampil, hasil dibaca ulang dari server dan dibandingkan dengan kuantitas yang diminta, error ditampilkan dalam SnackBar, dan tersedia tombol retry baca data. Tombol kurang tidak menghapus barang ketika jumlah satu; hapus dilakukan via ikon tempat sampah. Area sentuh tombol +/- diperbesar.

**Belum dikonfirmasi di perangkat.** UTS-14 yang menekan +/-/hapus harus dijalankan ulang setelah membangun APK baru. Status 12/12 PASS lama tidak berarti bug keranjang ini sudah diperbaiki pada APK fisik.
