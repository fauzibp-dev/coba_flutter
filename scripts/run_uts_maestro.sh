#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-doctor}"
DEVICE="${MAESTRO_DEVICE_ID:-nnzxea79ayypnzzx}"
APP="com.fauzibondanp.shopmart"
case "$MODE" in doctor|smoke|auth|all) ;; *) echo "Mode: doctor | smoke | auth | all" >&2; exit 2 ;; esac
command -v adb >/dev/null || { echo "ERROR: adb tidak ditemukan" >&2; exit 127; }
if [[ "$MODE" != "doctor" ]]; then
  command -v maestro >/dev/null || { echo "ERROR: Maestro tidak ditemukan" >&2; exit 127; }
fi
OUT="build/uts-maestro-$(date +%Y%m%d-%H%M%S)-$MODE"
mkdir -p "$OUT"
echo "DEVICE: $DEVICE | MODE: $MODE | HASIL: $OUT"
adb -s "$DEVICE" get-state >/dev/null 2>&1 || { echo "PRECHECK FAIL: HP offline. Jalankan adb devices."; exit 3; }
installed="$(adb -s "$DEVICE" shell pm path "$APP" 2>&1 | tr -d '\r')"
if [[ "$installed" != *"package:"* ]]; then
  echo "PRECHECK FAIL: APK $APP tidak ditemukan di perangkat $DEVICE"
  echo "$installed"
  exit 4
fi
echo "APK: $installed"

open_app() {
  local msg="" n
  adb -s "$DEVICE" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
  adb -s "$DEVICE" shell am force-stop "$APP" || return 1
  msg="$(adb -s "$DEVICE" shell monkey -p "$APP" -c android.intent.category.LAUNCHER 1 2>&1)" || {
    echo "PRECHECK FAIL: aplikasi gagal diluncurkan lewat ADB"
    echo "$msg"
    return 1
  }
  printf '%s\n' "$msg" > "$OUT/launch.log"
  for ((n=0;n<15;n++)); do
    if adb -s "$DEVICE" shell pidof "$APP" 2>/dev/null | grep -Eq '[0-9]'; then
      adb -s "$DEVICE" exec-out screencap -p > "$OUT/preflight.png" || true
      echo "PRECHECK OK: proses aplikasi hidup; screenshot: $OUT/preflight.png"
      echo "Pastikan layar HP menampilkan KKMP Kerten, bukan lockscreen."
      return 0
    fi
    sleep 1
  done
  echo "PRECHECK FAIL: APK terpasang, tapi proses aplikasi belum berjalan."
  return 1
}
if ! open_app; then exit 5; fi
if [[ "$MODE" == "doctor" ]]; then
  echo "DOCTOR SELESAI. Periksa layar HP atau $OUT/preflight.png"
  exit 0
fi

case "$MODE" in
 smoke) flows=(01_startup.yaml 02_navigasi_pencarian.yaml 05_validasi_pencarian.yaml) ;;
 auth) flows=(03_cart_create_read.yaml 04_checkout_quote.yaml 06_validasi_alamat.yaml) ;;
 all) flows=(01_startup.yaml 02_navigasi_pencarian.yaml 03_cart_create_read.yaml 04_checkout_quote.yaml 05_validasi_pencarian.yaml 06_validasi_alamat.yaml) ;;
esac
printf '| Flow | Status |\n|---|---|\n' > "$OUT/summary.md"
for file in "${flows[@]}"; do
  echo "===== TEST: $file ====="
  if ! open_app; then
    echo "| $file | PRECHECK FAIL |" >> "$OUT/summary.md"
    echo "STOP: app gagal dibuka. Tidak menandai semua flow FAIL."
    exit 5
  fi
  name="${file%.yaml}"
  mkdir -p "$OUT/artifacts/$name" "$OUT/debug/$name"
  if maestro --device="$DEVICE" --verbose test --format=JUNIT --output="$OUT/$name.xml" --test-output-dir="$OUT/artifacts/$name" --debug-output="$OUT/debug/$name" ".maestro/uts/$file" 2>&1 | tee "$OUT/$name.log"; then
    echo "| $file | PASS |" >> "$OUT/summary.md"
  else
    echo "| $file | FAIL — periksa $name.log |" >> "$OUT/summary.md"
    echo "STOP setelah FAIL pertama. Kirim: $OUT/$name.log"
    exit 1
  fi
done
echo "SUITE SELESAI. Laporan: $OUT/summary.md"
