#!/usr/bin/env bash
set -euo pipefail

DEVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
if [[ -n "${ORANGEFOX_TOP:-}" ]]; then
    TOP_DIR="$(cd -- "${ORANGEFOX_TOP}" && pwd -P)"
elif [[ -n "${RODIN_TOP_DIR:-}" ]]; then
    TOP_DIR="$(cd -- "${RODIN_TOP_DIR}" && pwd -P)"
elif [[ -f "${DEVICE_DIR}/../../../build/envsetup.sh" ]]; then
    TOP_DIR="$(cd -- "${DEVICE_DIR}/../../.." && pwd -P)"
elif [[ -f "${DEVICE_DIR}/../fox_14.1/build/envsetup.sh" ]]; then
    TOP_DIR="$(cd -- "${DEVICE_DIR}/../fox_14.1" && pwd -P)"
else
    echo "ERROR: OrangeFox 14.1 source tree not found." >&2
    echo "Place this repository at device/xiaomi/rodin inside the OrangeFox tree," >&2
    echo "keep it beside fox_14.1, or set ORANGEFOX_TOP." >&2
    exit 1
fi
PRODUCT_OUT="${1:-${OUT_DIR:-${TOP_DIR}/out}/target/product/rodin}"

HOS_BUILDER="${DEVICE_DIR}/tools/build-system-compatible-vendor-boot.sh"
AOSP_BUILDER="${DEVICE_DIR}/tools/build-aosp-compatible-vendor-boot.sh"

HOS_ENABLED="${PRODUCT_OUT}/OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-ENABLED.img"
HOS_DISABLED="${PRODUCT_OUT}/OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-DISABLED.img"

AOSP_ENABLED="${PRODUCT_OUT}/OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-ENABLED.img"
AOSP_DISABLED="${PRODUCT_OUT}/OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-DISABLED.img"

for builder in "$HOS_BUILDER" "$AOSP_BUILDER"; do
    test -x "$builder" || {
        echo "missing builder: $builder" >&2
        exit 1
    }
done

echo "===== UNIFIED HOS / AVB ENABLED ====="
RODIN_AVB_MODE=enabled \
"$HOS_BUILDER" "$PRODUCT_OUT" "$HOS_ENABLED"

echo
echo "===== UNIFIED HOS / AVB DISABLED ====="
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

# Keep the ordinary output pointed at the universal HOS AVB-enabled image.
cp -fp "$HOS_ENABLED" "${PRODUCT_OUT}/vendor_boot.img"
cp -fp "$HOS_ENABLED" "${PRODUCT_OUT}/OrangeFox-R12.0-Unofficial-rodin.img"

md5sum "${PRODUCT_OUT}/OrangeFox-R12.0-Unofficial-rodin.img" \
    > "${PRODUCT_OUT}/OrangeFox-R12.0-Unofficial-rodin.img.md5"

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
echo "Default vendor_boot.img -> unified HOS AVB ENABLED"
