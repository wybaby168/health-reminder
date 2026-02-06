#!/usr/bin/env bash
set -euo pipefail

INPUT_PNG="${1:-}"
OUTPUT_ASSETSCAR="${2:-}"

if [[ -z "${INPUT_PNG}" || -z "${OUTPUT_ASSETSCAR}" ]]; then
  echo "Usage: scripts/generate-appicon-assets.sh <origin.png> <Assets.car>" >&2
  exit 2
fi

if [[ ! -f "${INPUT_PNG}" ]]; then
  echo "Input png not found: ${INPUT_PNG}" >&2
  exit 2
fi

WORK_DIR="$(mktemp -d)"
ASSETS_DIR="${WORK_DIR}/Assets.xcassets"
APPICON_DIR="${ASSETS_DIR}/AppIcon.appiconset"
mkdir -p "${APPICON_DIR}"

write_icon() {
  local size="$1"
  local filename="$2"
  sips -s format png "${INPUT_PNG}" --out "${APPICON_DIR}/${filename}" >/dev/null
  sips -z "${size}" "${size}" "${APPICON_DIR}/${filename}" --out "${APPICON_DIR}/${filename}" >/dev/null
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

cat > "${APPICON_DIR}/Contents.json" <<'EOF'
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

mkdir -p "$(dirname "${OUTPUT_ASSETSCAR}")"

xcrun actool \
  --output-format human-readable-text \
  --notices \
  --warnings \
  --platform macosx \
  --target-device mac \
  --minimum-deployment-target 13.0 \
  --output-partial-info-plist "${WORK_DIR}/partial.plist" \
  --compile "$(dirname "${OUTPUT_ASSETSCAR}")" \
  --app-icon AppIcon \
  "${ASSETS_DIR}"

if [[ ! -f "$(dirname "${OUTPUT_ASSETSCAR}")/Assets.car" ]]; then
  echo "actool did not produce Assets.car" >&2
  exit 1
fi

mv "$(dirname "${OUTPUT_ASSETSCAR}")/Assets.car" "${OUTPUT_ASSETSCAR}"
echo "Generated: ${OUTPUT_ASSETSCAR}"
