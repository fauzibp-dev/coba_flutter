# Peringatan untuk 50 flow eksplorasi lama

Pengguna melaporkan seluruh 50 flow gagal dan kebanyakan hanya navigasi/scroll. Masalah yang terlihat dari source adalah ketidakcocokan teks `Pencarian` (standalone) vs `Cari Produk` (embedded), dan ketergantungan launcher. Seluruh kegagalan spesifik tidak dapat dipastikan tanpa log dari run tersebut.

**Gunakan `.maestro/functional/` terlebih dahulu** untuk input dan assertion sungguhan. Jangan membuat laporan PASS berdasarkan isi file saja; tunggu eksekusi HP fisik dan debug output.
