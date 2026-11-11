#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-doctor}"
DEVICE="${MAESTRO_DEVICE_ID:-nnzxea79ayypnzzx}"
APP="com.fauzibondanp.shopmart"

case "$MODE" in
  doctor|smoke|auth|all) ;;
  *) echo "Mode: doctor | smoke | auth | all" >&2; exit 2 ;;
esac

command -v adb >/dev/null || { echo "ERROR: adb tidak ditemukan"; exit 127; }
if [[ "$MODE" != "doctor" ]]; then
  command -v maestro >/dev/null || { echo "ERROR: Maestro tidak ditemukan"; exit 127; }
fi

OUT="build/uts-maestro-$(date +%Y%m%d-%H%M%S)-$MODE"
mkdir -p "$OUT/artifacts" "$OUT/debug"
echo "DEVICE: $DEVICE | MODE: $MODE | HASIL: $OUT"

adb -s "$DEVICE" get-state >/dev/null 2>&1 || {
  echo "PRECHECK FAIL: HP offline. Cek adb devices."
  exit 3
}

installed="$(adb -s "$DEVICE" shell pm path "$APP" 2>&1 | tr -d '\r')"
if [[ "$installed" != *"package:"* ]]; then
  echo "PRECHECK FAIL: APK $APP belum terpasang di HP."
  echo "$installed"
  exit 4
fi

# Preflight hanya SATU kali sebelum satu proses Maestro.
adb -s "$DEVICE" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
adb -s "$DEVICE" shell am force-stop "$APP"
launch_message="$(adb -s "$DEVICE" shell monkey -p "$APP" -c android.intent.category.LAUNCHER 1 2>&1)" || {
  echo "PRECHECK FAIL: gagal membuka aplikasi melalui ADB"
  echo "$launch_message"
  exit 5
}
printf '%s\n' "$launch_message" > "$OUT/launch.log"

running=0
for ((attempt=0; attempt<15; attempt++)); do
  if adb -s "$DEVICE" shell pidof "$APP" 2>/dev/null | grep -Eq '[0-9]'; then
    running=1
    break
  fi
  sleep 1
done
if [[ "$running" -ne 1 ]]; then
  echo "PRECHECK FAIL: proses KKMP Kerten tidak hidup setelah launch."
  exit 5
fi
adb -s "$DEVICE" exec-out screencap -p > "$OUT/preflight.png" || true
echo "PRECHECK OK (proses hidup). Lihat HP atau $OUT/preflight.png untuk pastikan UI siap."
if [[ "$MODE" == "doctor" ]]; then
  echo "DOCTOR selesai; belum ada flow Maestro dijalankan."
  exit 0
fi

# Satu invocation Maestro untuk semua flow yang dipilih. Mengurangi
# pengulangan install/initialize driver di Xiaomi/MIUI.
case "$MODE" in
  smoke) flows=(01_startup.yaml 02_navigasi_pencarian.yaml 05_validasi_pencarian.yaml) ;;
  auth) flows=(03_cart_create_read.yaml 04_checkout_quote.yaml 06_validasi_alamat.yaml) ;;
  all) flows=(01_startup.yaml 02_navigasi_pencarian.yaml 03_cart_create_read.yaml 04_checkout_quote.yaml 05_validasi_pencarian.yaml 06_validasi_alamat.yaml) ;;
esac
selected=()
for file in "${flows[@]}"; do
  selected+=(".maestro/uts/$file")
done
printf 'DAFTAR FLOW (%s):\n' "${#selected[@]}"
printf ' - %s\n' "${selected[@]}"
echo "Menjalankan 1 proses Maestro; MIUI mungkin meminta persetujuan driver sekali per run."

maestro --device="$DEVICE" --verbose test \
  --format=JUNIT \
  --output="$OUT/junit.xml" \
  --test-output-dir="$OUT/artifacts" \
  --debug-output="$OUT/debug" \
  "${selected[@]}" 2>&1 | tee "$OUT/terminal.log"

echo "Selesai. PASS/FAIL: $OUT/junit.xml"
echo "Log: $OUT/terminal.log"
echo "Screenshot/debug: $OUT/artifacts dan $OUT/debug"
