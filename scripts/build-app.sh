#!/usr/bin/env bash
set -euo pipefail

PRODUCT_NAME="HealthReminder"
BUNDLE_ID="com.wangyu.healthreminder"
VERSION="1.0"
BUILD_CONFIGURATION="debug"

ICON_PNG="icons/app-icon.png"
ICON_ICNS=".build/AppIcon.icns"
ASSETS_CAR=".build/Assets.car"
ICON_SOURCE_PNG=".build/AppIconSource.png"

swift build --disable-sandbox -c "${BUILD_CONFIGURATION}"

if [[ -f "${ICON_PNG}" ]]; then
  ./scripts/prepare-icon-source.sh "${ICON_PNG}" "${ICON_SOURCE_PNG}"
  ./scripts/generate-appicon.sh "${ICON_SOURCE_PNG}" "${ICON_ICNS}"
  ./scripts/generate-appicon-assets.sh "${ICON_SOURCE_PNG}" "${ASSETS_CAR}"
fi

ARCH_DIR=".build/arm64-apple-macosx/${BUILD_CONFIGURATION}"
BIN_PATH="${ARCH_DIR}/${PRODUCT_NAME}"
APP_PATH=".build/${PRODUCT_NAME}.app"

if [[ ! -f "${BIN_PATH}" ]]; then
  echo "Binary not found: ${BIN_PATH}" >&2
  exit 1
fi

rm -rf "${APP_PATH}"
mkdir -p "${APP_PATH}/Contents/MacOS" "${APP_PATH}/Contents/Resources"
cp "${BIN_PATH}" "${APP_PATH}/Contents/MacOS/${PRODUCT_NAME}"

if [[ -f "${ICON_ICNS}" ]]; then
  cp "${ICON_ICNS}" "${APP_PATH}/Contents/Resources/AppIcon.icns"
fi

if [[ -f "${ASSETS_CAR}" ]]; then
  cp "${ASSETS_CAR}" "${APP_PATH}/Contents/Resources/Assets.car"
fi

cat > "${APP_PATH}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${PRODUCT_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>健康提醒</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${PRODUCT_NAME}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon.icns</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleSignature</key>
  <string>????</string>
  <key>CFBundleSupportedPlatforms</key>
  <array>
    <string>MacOSX</string>
  </array>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
EOF

echo -n "APPL????" > "${APP_PATH}/Contents/PkgInfo"

chmod +x "${APP_PATH}/Contents/MacOS/${PRODUCT_NAME}"
codesign --force --deep --sign - "${APP_PATH}" >/dev/null 2>&1 || true

echo "Built: ${APP_PATH}"
