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

