#!/usr/bin/env bash
set -euo pipefail
DEVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TOP_DIR="$(cd -- "${DEVICE_DIR}/../../.." && pwd -P)"
PRODUCT_OUT="${1:-${OUT_DIR:-${TOP_DIR}/out}/target/product/rodin}"
BUILDER="${DEVICE_DIR}/tools/build-system-compatible-vendor-boot.sh"
BASE="OrangeFox-R12.0-NEESCHAL-rodin-india"
ENABLED="${PRODUCT_OUT}/${BASE}-AVB-ENABLED.img"
DISABLED="${PRODUCT_OUT}/${BASE}-AVB-DISABLED.img"

echo "===== BUILD AVB ENABLED ====="
RODIN_FIRMWARE_VARIANT=india RODIN_AVB_MODE=enabled "$BUILDER" "$PRODUCT_OUT" "$ENABLED"

echo "===== BUILD AVB DISABLED ====="
RODIN_FIRMWARE_VARIANT=india RODIN_AVB_MODE=disabled "$BUILDER" "$PRODUCT_OUT" "$DISABLED"

echo "===== RESTORE ENABLED AS DEFAULT ====="
cp -fp "$ENABLED" "${PRODUCT_OUT}/vendor_boot.img"
cp -fp "$ENABLED" "${PRODUCT_OUT}/OrangeFox-R12.0-Unofficial-rodin.img"
md5sum "${PRODUCT_OUT}/OrangeFox-R12.0-Unofficial-rodin.img" > "${PRODUCT_OUT}/OrangeFox-R12.0-Unofficial-rodin.img.md5"

echo "===== FINAL VARIANTS ====="
ls -lh "$ENABLED" "$DISABLED"
sha256sum "$ENABLED" "$DISABLED"
