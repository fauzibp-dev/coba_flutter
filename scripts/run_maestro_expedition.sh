#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-smoke}"
DEVICE="${MAESTRO_DEVICE_ID:-nnzxea79ayypnzzx}"
case "$MODE" in
  smoke|customer|superadmin|validation|all) ;;
  *) echo "Mode: smoke | customer | superadmin | validation | all" >&2; exit 2 ;;
esac

for command_name in adb maestro; do
  command -v "$command_name" >/dev/null || { echo "$command_name belum terpasang" >&2; exit 127; }
done
adb -s "$DEVICE" get-state >/dev/null || { echo "HP $DEVICE tidak terhubung. Cek adb devices." >&2; exit 3; }

RUN_DIR="build/maestro-expedition-$(date +%Y%m%d-%H%M%S)-$MODE"
mkdir -p "$RUN_DIR/artifacts" "$RUN_DIR/debug"
echo "Perangkat: $DEVICE"
echo "Kelompok:  $MODE"
echo "Hasil:     $RUN_DIR"

ARGS=(--device "$DEVICE" test --format junit --output "$RUN_DIR/report.xml" --test-output-dir "$RUN_DIR/artifacts" --debug-output "$RUN_DIR/debug")
if [[ "$MODE" != "all" ]]; then
  ARGS+=(--include-tags "$MODE")
fi
ARGS+=(.maestro/expedition)
maestro "${ARGS[@]}" 2>&1 | tee "$RUN_DIR/terminal.log"
echo "Selesai. Buka $RUN_DIR/report.xml dan $RUN_DIR/artifacts."
