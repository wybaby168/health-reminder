#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

./scripts/build-app.sh

APP_PATH=".build/HealthReminder.app"
INFO_PLIST="${APP_PATH}/Contents/Info.plist"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App not found: ${APP_PATH}" >&2
  exit 1
fi

VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "${INFO_PLIST}" 2>/dev/null || echo "1.0")"
BUILD="$(/usr/bin/plutil -extract CFBundleVersion raw -o - "${INFO_PLIST}" 2>/dev/null || echo "1")"

DIST_DIR="dist"
mkdir -p "${DIST_DIR}"

VOL_NAME="健康提醒"
DMG_NAME="HealthReminder-${VERSION}(${BUILD}).dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "${STAGING_DIR}"' EXIT

cp -R "${APP_PATH}" "${STAGING_DIR}/HealthReminder.app"
ln -s /Applications "${STAGING_DIR}/Applications"

cat > "${STAGING_DIR}/使用说明.txt" <<'EOF'
将 HealthReminder.app 拖拽到 Applications 文件夹安装。
首次运行请允许通知权限。
EOF

/usr/bin/hdiutil create \
  -volname "${VOL_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}" >/dev/null

echo "Built: ${DMG_PATH}"

