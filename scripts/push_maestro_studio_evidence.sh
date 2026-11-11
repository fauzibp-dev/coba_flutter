#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/Desktop/coba_flutter"
branch="test/maestro-exploration-20261111"
if [[ "$(git branch --show-current)" != "$branch" ]]; then
  echo "Branch belum sesuai. Jalankan: git switch $branch"; exit 2
fi
src="$HOME/.maestro/tests/2026-11-11_161134/artifacts/takeScreenshot"
if [[ ! -d "$src" ]]; then echo "Screenshot tidak ditemukan: $src"; exit 3; fi
dest="uat/evidence/maestro-studio/2026-11-11_161134"
mkdir -p "$dest" uat/reports
cp -n "$src/"*.png "$dest/"
for ext in pdf docx; do
  f="$HOME/Downloads/Laporan_UTS_Maestro_Studio_KKMP_Kerten.$ext"
  if [[ -f "$f" ]]; then cp -n "$f" uat/reports/; fi
done
echo "Screenshot selesai disalin. Periksa identitas pribadi sebelum push."
open "$PWD/$dest"
read -r -p "Sudah memeriksa/mensamarkan email, pesan dan data pribadi? Ketik YA untuk commit dan push: " answer
if [[ "$answer" != "YA" ]]; then echo "Belum di-push. Data lokal tetap ada."; exit 0; fi
git add uat/LAPORAN_MAESTRO_STUDIO_12_PASS.md uat/evidence/maestro-studio uat/reports
if ! git diff --cached --quiet; then
  git commit -m "docs(UTS): add reviewed Maestro Studio screenshots and reports"
fi
git push origin "$branch"
echo "Bukti Studio telah di-push ke branch pengujian."
