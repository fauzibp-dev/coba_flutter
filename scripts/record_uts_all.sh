#!/usr/bin/env bash
set -euo pipefail

DEVICE="${MAESTRO_DEVICE_ID:-nnzxea79ayypnzzx}"
command -v scrcpy >/dev/null || {
  echo "scrcpy belum terpasang. Mac: brew install scrcpy (jika Homebrew tersedia)." >&2
  echo "Atau rekam via perekam layar Xiaomi, lalu jalankan: bash scripts/run_uts_maestro.sh all" >&2
  exit 127
}
command -v adb >/dev/null || { echo "ADB tidak ditemukan" >&2; exit 127; }
adb -s "$DEVICE" get-state >/dev/null 2>&1 || { echo "HP $DEVICE tidak terhubung" >&2; exit 3; }

OUT="build/uts-record-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
VIDEO="$OUT/KKMP_Kerten_UTS_Full_Test.mp4"
echo "Merekam layar HP ke $VIDEO"
echo "Rekam terminal dengan OBS jika juga ingin PASS/FAIL terlihat di video."

scrcpy --serial="$DEVICE" --no-audio --no-control --record="$VIDEO" > "$OUT/scrcpy.log" 2>&1 &
REC_PID=$!
cleanup() {
  trap - EXIT
  if kill -0 "$REC_PID" 2>/dev/null; then
    kill -INT "$REC_PID" 2>/dev/null || true
    wait "$REC_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT
sleep 3
if ! kill -0 "$REC_PID" 2>/dev/null; then
  echo "Recorder scrcpy gagal dibuka. Lihat $OUT/scrcpy.log" >&2
  exit 5
fi

echo "Memulai seluruh 10 flow dalam satu proses Maestro..."
result=0
bash scripts/run_uts_maestro.sh all 2>&1 | tee "$OUT/maestro-all.log" || result=$?
echo "Selesai dengan kode keluar $result. Rekaman akan difinalisasi saat script keluar."
echo "Video: $VIDEO"
echo "Log: $OUT/maestro-all.log"
exit "$result"
