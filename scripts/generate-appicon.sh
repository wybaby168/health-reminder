#!/usr/bin/env bash
set -euo pipefail

INPUT_PNG="${1:-}"
OUTPUT_ICNS="${2:-}"

if [[ -z "${INPUT_PNG}" || -z "${OUTPUT_ICNS}" ]]; then
  echo "Usage: scripts/generate-appicon.sh <origin.png> <output.icns>" >&2
  exit 2
fi

if [[ ! -f "${INPUT_PNG}" ]]; then
  echo "Input png not found: ${INPUT_PNG}" >&2
  exit 2
fi

WORK_DIR="$(mktemp -d)"
ICONSET_DIR="${WORK_DIR}/AppIcon.iconset"
mkdir -p "${ICONSET_DIR}"

write_icon() {
  local size="$1"
  local filename="$2"
  sips -s format png "${INPUT_PNG}" --out "${ICONSET_DIR}/${filename}" >/dev/null
  sips -z "${size}" "${size}" "${ICONSET_DIR}/${filename}" --out "${ICONSET_DIR}/${filename}" >/dev/null
}

write_icon 16 "icon_16x16.png"
write_icon 32 "icon_16x16@2x.png"
write_icon 32 "icon_32x32.png"
write_icon 64 "icon_32x32@2x.png"
write_icon 128 "icon_128x128.png"
write_icon 256 "icon_128x128@2x.png"
write_icon 256 "icon_256x256.png"
write_icon 512 "icon_256x256@2x.png"
write_icon 512 "icon_512x512.png"
write_icon 1024 "icon_512x512@2x.png"

mkdir -p "$(dirname "${OUTPUT_ICNS}")"
iconutil -c icns "${ICONSET_DIR}" -o "${OUTPUT_ICNS}"

echo "Generated: ${OUTPUT_ICNS}"

