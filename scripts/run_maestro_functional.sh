#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-smoke}"
DEVICE="${MAESTRO_DEVICE_ID:-nnzxea79ayypnzzx}"
case "$MODE" in smoke|customer|superadmin|validation|all) ;; *) echo "Mode: smoke | customer | superadmin | validation | all" >&2; exit 2 ;; esac
command -v maestro >/dev/null || { echo "Maestro CLI tidak ditemukan" >&2; exit 127; }
command -v adb >/dev/null || { echo "ADB tidak ditemukan" >&2; exit 127; }
adb -s "$DEVICE" get-state >/dev/null || { adb devices; echo "HP $DEVICE tidak terhubung" >&2; exit 3; }
OUT="build/maestro-functional-$(date +%Y%m%d-%H%M%S)-$MODE"
mkdir -p "$OUT/artifacts" "$OUT/debug"
echo "TEST: $MODE | DEVICE: $DEVICE | OUT: $OUT"
ARGS=(--device "$DEVICE" --verbose test --format junit --output "$OUT/report.xml" --test-output-dir "$OUT/artifacts" --debug-output "$OUT/debug")
if [[ "$MODE" != "all" ]]; then ARGS+=(--include-tags "$MODE"); fi
ARGS+=(.maestro/functional)
maestro "${ARGS[@]}" 2>&1 | tee "$OUT/terminal.log"
echo "Report: $OUT/report.xml"
