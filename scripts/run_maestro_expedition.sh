#!/usr/bin/env bash
set -euo pipefail
echo "PERINGATAN: 50 flow lama kebanyakan navigasi dan dilaporkan FAIL." >&2
echo "Dialihkan ke paket fungsional baru (18 flow), bukan mengulang 50 lama." >&2
echo "Baca .maestro/functional/README.md untuk detail." >&2
exec bash scripts/run_maestro_functional.sh "${@:-smoke}"
