#!/usr/bin/env bash
set -euo pipefail

INPUT_PNG="${1:-}"
OUTPUT_PNG="${2:-}"

if [[ -z "${INPUT_PNG}" || -z "${OUTPUT_PNG}" ]]; then
  echo "Usage: scripts/prepare-icon-source.sh <z.png> <output.png>" >&2
  exit 2
fi

if [[ ! -f "${INPUT_PNG}" ]]; then
  echo "Input png not found: ${INPUT_PNG}" >&2
  exit 2
fi

mkdir -p "$(dirname "${OUTPUT_PNG}")"

W="$(/usr/bin/sips -g pixelWidth "${INPUT_PNG}" | awk '/pixelWidth/ {print $2}')"
H="$(/usr/bin/sips -g pixelHeight "${INPUT_PNG}" | awk '/pixelHeight/ {print $2}')"

if [[ -z "${W}" || -z "${H}" ]]; then
  echo "Failed to read image size." >&2
  exit 2
fi

SIZE="${W}"
if [[ "${H}" -lt "${W}" ]]; then
  SIZE="${H}"
fi

/usr/bin/sips -s format png "${INPUT_PNG}" --out "${OUTPUT_PNG}" >/dev/null
if [[ "${W}" -ne "${H}" ]]; then
  /usr/bin/sips --cropToHeightWidth "${SIZE}" "${SIZE}" "${OUTPUT_PNG}" --out "${OUTPUT_PNG}" >/dev/null
fi
/usr/bin/sips -z 1024 1024 "${OUTPUT_PNG}" --out "${OUTPUT_PNG}" >/dev/null

echo "Prepared: ${OUTPUT_PNG}"

