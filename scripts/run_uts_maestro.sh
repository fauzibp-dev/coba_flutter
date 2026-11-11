#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-smoke}"
DEVICE="${MAESTRO_DEVICE_ID:-nnzxea79ayypnzzx}"
case "$MODE" in smoke|auth|all) ;; *) echo "Pilih: smoke | auth | all" >&2; exit 2 ;; esac
command -v adb >/dev/null || { echo "ADB belum tersedia di Mac" >&2; exit 127; }
command -v maestro >/dev/null || { echo "Maestro CLI belum tersedia di Mac" >&2; exit 127; }
adb -s "$DEVICE" get-state >/dev/null || { echo "HP $DEVICE belum terhubung (cek adb devices)." >&2; exit 3; }
adb -s "$DEVICE" shell pm path com.fauzibondanp.shopmart >/dev/null || { echo "KKMP Kerten belum terpasang di HP." >&2; exit 4; }

OUTPUT="build/uts-maestro-$(date +%Y%m%d-%H%M%S)-$MODE"
mkdir -p "$OUTPUT/screenshots" "$OUTPUT/debug"
echo "PERANGKAT : $DEVICE"
echo "SUITE     : $MODE"
echo "OUTPUT    : $OUTPUT"
echo "Catatan: flow auth memerlukan sesi login; transaction menambah item ke keranjang."

ARGS=(--device "$DEVICE" test --format junit --output "$OUTPUT/junit.xml" --test-output-dir "$OUTPUT/screenshots" --debug-output "$OUTPUT/debug")
if [[ "$MODE" != "all" ]]; then ARGS+=(--include-tags "uts-$MODE"); fi
ARGS+=(.maestro/uts)
maestro "${ARGS[@]}" 2>&1 | tee "$OUTPUT/terminal.log"
