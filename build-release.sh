#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if [[ -n "${ORANGEFOX_TOP:-}" ]]; then
    FOX="$(cd -- "${ORANGEFOX_TOP}" && pwd -P)"
elif [[ -n "${RODIN_TOP_DIR:-}" ]]; then
    FOX="$(cd -- "${RODIN_TOP_DIR}" && pwd -P)"
elif [[ -f "${REPO}/../../../build/envsetup.sh" ]]; then
    FOX="$(cd -- "${REPO}/../../.." && pwd -P)"
elif [[ -f "${REPO}/../fox_14.1/build/envsetup.sh" ]]; then
    FOX="$(cd -- "${REPO}/../fox_14.1" && pwd -P)"
else
    echo "ERROR: OrangeFox 14.1 source tree not found." >&2
    echo "Place this repository at device/xiaomi/rodin inside the OrangeFox tree," >&2
    echo "keep it beside fox_14.1, or set:" >&2
    echo "  ORANGEFOX_TOP=/path/to/fox_14.1" >&2
    exit 1
fi

RECOVERY="${FOX}/bootable/recovery"
PRODUCT_OUT="${FOX}/out/target/product/rodin"

STAMP="$(date +%Y%m%d-%H%M%S)"
FREEZE="$REPO/build-freezes/$STAMP"

export ORANGEFOX_TOP="$FOX"
export RODIN_TOP_DIR="$FOX"

echo "============================================================"
echo " RODIN ORANGEFOX — FINAL RELEASE BUILD"
echo "============================================================"
echo
echo "Device source:"
echo "  ${REPO}"
echo "OrangeFox tree:"
echo "  ${FOX}"
echo

echo "===== APPLY COMPLETE RODIN PATCH STACK ====="
"${REPO}/tools/apply-orangefox-patches.sh" "${FOX}"

echo
echo "===== FREEZE CURRENT WORK ====="
mkdir -p "$FREEZE"

cp -fp \
    "$RECOVERY/twrpRepacker.cpp" \
    "$FREEZE/twrpRepacker.cpp"

cp -fp \
    "$RECOVERY/orangefox.cpp" \
    "$FREEZE/orangefox.cpp"

cp -fp \
    "$RECOVERY/gui/theme/portrait_hdpi/pages/settings.xml" \
    "$FREEZE/settings.xml"

cp -fp \
    "$RECOVERY/gui/theme/portrait_hdpi/pages/fox.xml" \
    "$FREEZE/fox.xml"

cp -fp \
    "$REPO/tools/build-vendorboot-variants.sh" \
    "$FREEZE/build-vendorboot-variants.sh"

cp -fp \
    "$REPO/tools/build-system-compatible-vendor-boot.sh" \
    "$FREEZE/build-system-compatible-vendor-boot.sh"

cp -fp \
    "$REPO/tools/build-aosp-compatible-vendor-boot.sh" \
    "$FREEZE/build-aosp-compatible-vendor-boot.sh"

git -C "$RECOVERY" diff > \
    "$FREEZE/bootable-recovery-working.diff"

sha256sum \
    "$FREEZE/twrpRepacker.cpp" \
    "$FREEZE/orangefox.cpp" \
    "$FREEZE/settings.xml" \
    "$FREEZE/fox.xml" \
    "$FREEZE/build-vendorboot-variants.sh" \
    "$FREEZE/build-system-compatible-vendor-boot.sh" \
    "$FREEZE/build-aosp-compatible-vendor-boot.sh" \
    > "$FREEZE/SHA256SUMS"

echo "Frozen to:"
echo "  $FREEZE"
echo

echo "===== VERIFY BUILD INPUTS ====="
if [ -x "$REPO/tools/verify-build-inputs.sh" ]; then
    "$REPO/tools/verify-build-inputs.sh"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "ERROR: build input verification failed"
        exit "$rc"
    fi
fi

echo
echo "===== COMPILE ORANGEFOX ====="
RODIN_SKIP_POST_REPACK=1 "$REPO/build-lowmem.sh" vendorbootimage
rc=$?

if [ "$rc" -ne 0 ]; then
    echo "ERROR: OrangeFox compile failed"
    exit "$rc"
fi

echo
echo "===== BUILD ALL FOUR VENDOR_BOOT VARIANTS ====="
"$REPO/tools/build-vendorboot-variants.sh" "$PRODUCT_OUT"
rc=$?

if [ "$rc" -ne 0 ]; then
    echo "ERROR: four-variant build failed"
    exit "$rc"
fi

echo
echo "===== FINAL OUTPUTS ====="

images=(
    "$PRODUCT_OUT/OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-ENABLED.img"
    "$PRODUCT_OUT/OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-DISABLED.img"
    "$PRODUCT_OUT/OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-ENABLED.img"
    "$PRODUCT_OUT/OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-DISABLED.img"
)

for image in "${images[@]}"; do
    if [ ! -f "$image" ]; then
        echo "ERROR: missing output:"
        echo "  $image"
        exit 1
    fi

    ls -lh "$image"
    sha256sum "$image"
    echo
done

echo "===== SAVE RELEASE HASHES ====="

(
    cd "$PRODUCT_OUT"
    for image in "${images[@]}"; do
        sha256sum "$(basename -- "$image")"
    done
) > "$PRODUCT_OUT/RODIN-ORANGEFOX-SHA256SUMS.txt"

cp -fp \
    "$PRODUCT_OUT/RODIN-ORANGEFOX-SHA256SUMS.txt" \
    "$FREEZE/RODIN-ORANGEFOX-SHA256SUMS.txt"

echo
echo "============================================================"
echo " RELEASE BUILD COMPLETE"
echo "============================================================"
echo
echo "Working-source freeze:"
echo "  $FREEZE"
echo
echo "Hashes:"
cat "$PRODUCT_OUT/RODIN-ORANGEFOX-SHA256SUMS.txt"
