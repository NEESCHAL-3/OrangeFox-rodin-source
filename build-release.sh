#!/usr/bin/env bash

ROOT="/mnt/rodin-build"
FOX="$ROOT/fox_14.1"
REPO="$ROOT/OrangeFox-rodin-source"
RECOVERY="$FOX/bootable/recovery"
PRODUCT_OUT="$FOX/out/target/product/rodin"

STAMP="$(date +%Y%m%d-%H%M%S)"
FREEZE="$REPO/build-freezes/$STAMP"

echo "============================================================"
echo " RODIN ORANGEFOX — FINAL RELEASE BUILD"
echo "============================================================"
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
"$REPO/build-lowmem.sh" vendorbootimage
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

sha256sum "${images[@]}" \
    > "$PRODUCT_OUT/RODIN-ORANGEFOX-SHA256SUMS.txt"

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
