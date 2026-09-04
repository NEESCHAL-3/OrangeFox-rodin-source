#!/usr/bin/env bash
set -euo pipefail

DEVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
TOP_DIR="${RODIN_TOP_DIR:-$(cd -- "${DEVICE_DIR}/../fox_14.1" && pwd -P)}"
PRODUCT_OUT="${OUT_DIR:-${TOP_DIR}/out}/target/product/rodin"

echo "============================================================"
echo " RODIN ORANGEFOX — RELEASE BUILD"
echo "============================================================"

echo
echo "===== APPLY PATCHES ====="
"${DEVICE_DIR}/tools/apply-orangefox-patches.sh"

echo
echo "===== VERIFY BUILD INPUTS ====="
"${DEVICE_DIR}/tools/verify-build-inputs.sh" "$TOP_DIR"

echo
echo "===== COMPILE ORANGEFOX ====="
"${DEVICE_DIR}/build-lowmem.sh" vendorbootimage

echo
echo "===== BUILD RELEASE VARIANTS ====="
"${DEVICE_DIR}/tools/build-vendorboot-variants.sh" "$PRODUCT_OUT"

echo
echo "============================================================"
echo " RELEASE COMPLETE"
echo "============================================================"

for image in \
    "${PRODUCT_OUT}/OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-ENABLED.img" \
    "${PRODUCT_OUT}/OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-DISABLED.img" \
    "${PRODUCT_OUT}/OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-ENABLED.img" \
    "${PRODUCT_OUT}/OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-DISABLED.img"; do

    test -f "$image" || {
        echo "MISSING: $image" >&2
        exit 1
    }

    sha256sum "$image"
done
