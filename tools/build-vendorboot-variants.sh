#!/usr/bin/env bash
set -euo pipefail

DEVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TOP_DIR="$(cd -- "${DEVICE_DIR}/../../.." && pwd -P)"
PRODUCT_OUT="${1:-${OUT_DIR:-${TOP_DIR}/out}/target/product/rodin}"

HOS_BUILDER="${DEVICE_DIR}/tools/build-system-compatible-vendor-boot.sh"
AOSP_BUILDER="${DEVICE_DIR}/tools/build-aosp-compatible-vendor-boot.sh"

HOS_ENABLED="${PRODUCT_OUT}/OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-ENABLED.img"
HOS_DISABLED="${PRODUCT_OUT}/OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-DISABLED.img"

AOSP_ENABLED="${PRODUCT_OUT}/OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-ENABLED.img"
AOSP_DISABLED="${PRODUCT_OUT}/OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-DISABLED.img"

for f in "$HOS_BUILDER" "$AOSP_BUILDER"; do
    test -x "$f" || {
        echo "missing builder: $f" >&2
        exit 1
    }
done

echo "===== HOS / AVB ENABLED ====="
RODIN_FIRMWARE_VARIANT=india \
RODIN_AVB_MODE=enabled \
"$HOS_BUILDER" "$PRODUCT_OUT" "$HOS_ENABLED"

echo
echo "===== HOS / AVB DISABLED ====="
RODIN_FIRMWARE_VARIANT=india \
RODIN_AVB_MODE=disabled \
"$HOS_BUILDER" "$PRODUCT_OUT" "$HOS_DISABLED"

echo
echo "===== AOSP / AVB ENABLED ====="
RODIN_AVB_MODE=enabled \
"$AOSP_BUILDER" "$PRODUCT_OUT" "$AOSP_ENABLED"

echo
echo "===== AOSP / AVB DISABLED ====="
RODIN_AVB_MODE=disabled \
"$AOSP_BUILDER" "$PRODUCT_OUT" "$AOSP_DISABLED"

# Preserve the existing default behavior.
cp -fp "$HOS_ENABLED" "${PRODUCT_OUT}/vendor_boot.img"

echo
echo "============================================================"
echo " RODIN ORANGEFOX — FOUR VARIANTS COMPLETE"
echo "============================================================"

for image in \
    "$HOS_ENABLED" \
    "$HOS_DISABLED" \
    "$AOSP_ENABLED" \
    "$AOSP_DISABLED"; do
    test -f "$image" || {
        echo "missing output: $image" >&2
        exit 1
    }
    sha256sum "$image"
done

echo
echo "default vendor_boot.img -> HOS AVB ENABLED"
