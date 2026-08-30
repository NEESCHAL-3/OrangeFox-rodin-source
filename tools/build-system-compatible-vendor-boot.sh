#!/usr/bin/env bash
set -euo pipefail

DEVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TOP_DIR="$(cd -- "${DEVICE_DIR}/../../.." && pwd -P)"
PRODUCT_OUT="${1:-${OUT_DIR:-${TOP_DIR}/out}/target/product/rodin}"
FIRMWARE_VARIANT="${RODIN_FIRMWARE_VARIANT:-india}"
AVB_MODE="${RODIN_AVB_MODE:-enabled}"
case "$AVB_MODE" in
    enabled|disabled) ;;
    *) echo "unsupported RODIN_AVB_MODE: $AVB_MODE (expected enabled or disabled)" >&2; exit 1 ;;
esac


case "${FIRMWARE_VARIANT}" in
    india)
        STOCK_RAMDISK="${DEVICE_DIR}/prebuilt/india/vendor_ramdisk00"
        STOCK_RAMDISK_SHA256="c1b5ad776c93f89c6bf227ffecbf21ff3338236833d424446b388bb9819587a6"
        DEFAULT_OUTPUT_IMAGE="${PRODUCT_OUT}/OrangeFox-R12.0-NEESCHAL-rodin-india-system-compatible.img"
        ;;
    *)
        echo "unsupported RODIN_FIRMWARE_VARIANT: ${FIRMWARE_VARIANT} (expected india)" >&2
        exit 1
        ;;
esac

OUTPUT_IMAGE="${2:-${DEFAULT_OUTPUT_IMAGE}}"
STOCK_DTB="${DEVICE_DIR}/prebuilt/dtb/mt6899-rodin.dtb"
RECOVERY_HOST_DTB_TOOL="${DEVICE_DIR}/tools/make-recovery-host-dtb.py"
RECOVERY_LZ4="${PRODUCT_OUT}/obj/PACKAGING/vendor_ramdisk_fragments_intermediates/recovery.cpio.lz4"
LZ4="${PRODUCT_OUT%/target/product/rodin}/host/linux-x86/bin/lz4"
MKBOOTIMG="${PRODUCT_OUT%/target/product/rodin}/host/linux-x86/bin/mkbootimg"
MKBOOTFS="${PRODUCT_OUT%/target/product/rodin}/host/linux-x86/bin/mkbootfs"
AVBTOOL="${PRODUCT_OUT%/target/product/rodin}/host/linux-x86/bin/avbtool"

for file in "$STOCK_RAMDISK" "$STOCK_DTB" "$RECOVERY_HOST_DTB_TOOL" "$RECOVERY_LZ4" "$LZ4" "$MKBOOTIMG" "$MKBOOTFS" "$AVBTOOL"; do
    if [ ! -f "$file" ]; then
        echo "missing required build input: $file" >&2
        exit 1
    fi
done

for command_name in python3 dtc fdtget fdtput; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "missing required DTB command: $command_name" >&2
        exit 1
    fi
done

check_sha256() {
    local expected="$1"
    local file="$2"
    local actual
    actual="$(sha256sum "$file" | awk '{print $1}')"
    if [ "$actual" != "$expected" ]; then
        echo "firmware input hash mismatch: $file" >&2
        echo "expected $expected" >&2
        echo "actual   $actual" >&2
        exit 1
    fi
}

check_sha256 "$STOCK_RAMDISK_SHA256" "$STOCK_RAMDISK"
check_sha256 38369239c984fc191e36d043d19ccbea4c1cd09ee6c80f8646d9493f650a30ae "$STOCK_DTB"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/rodin-vendor-boot.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

recovery_cpio="${work_dir}/recovery.cpio"
platform_cpio="${work_dir}/platform.cpio"
platform_root="${work_dir}/platform-root"
platform_pruned_cpio="${work_dir}/platform-pruned.cpio"
platform_pruned_lz4="${work_dir}/platform-pruned.cpio.lz4"
unsigned_image="${work_dir}/vendor_boot.img"
recovery_host_dtb="${work_dir}/mt6899-rodin-recovery-host.dtb"

python3 "$RECOVERY_HOST_DTB_TOOL" "$STOCK_DTB" "$recovery_host_dtb"

"$LZ4" -d -f "$RECOVERY_LZ4" "$recovery_cpio" >/dev/null
"$LZ4" -d -f "$STOCK_RAMDISK" "$platform_cpio" >/dev/null

module_count="$(cpio -it --quiet < "$recovery_cpio" | awk '/^lib\/modules\/.*\.ko$/ { count++ } END { print count + 0 }')"
if [ "$module_count" -gt 7 ]; then
    echo "recovery fragment still contains $module_count modules; expected at most 7" >&2
    exit 1
fi

# The stock platform fragment also contains a complete stock-recovery
# userspace. Normal Android boot never uses these files after /system is
# mounted, and the OrangeFox recovery fragment supplies its own copies. Drop
# only that recovery-only payload while retaining stock first-stage init,
# linker/runtime, SELinux policy, fstab, firmware, and every kernel module.
mkdir -p "$platform_root"
(
    cd "$platform_root"
    cpio -idm --quiet --no-absolute-filenames < "$platform_cpio"
)
rm -rf "$platform_root/res"
rm -f \
    "$platform_root/miui.factoryreset.rc" \
    "$platform_root/system/bin/adbd" \
    "$platform_root/system/bin/fastbootd" \
    "$platform_root/system/bin/logcat" \
    "$platform_root/system/bin/logd" \
    "$platform_root/system/bin/recovery" \
    "$platform_root/system/bin/servicemanager" \
    "$platform_root/system/bin/sh" \
    "$platform_root/system/bin/toolbox" \
    "$platform_root/system/bin/toybox" \
    "$platform_root/system/bin/update_engine_sideload" \
    "$platform_root/system/bin/hw/android.hardware.boot-service.mtk_recovery" \
    "$platform_root/system/bin/hw/android.hardware.health-service.example_recovery" \
    "$platform_root/system/etc/init/android.hardware.boot-service.mtk_recovery.rc" \
    "$platform_root/system/etc/init/android.hardware.health-service.example_recovery.rc" \
    "$platform_root/system/etc/init/recovery-persist.rc" \
    "$platform_root/system/etc/init/recovery-refresh.rc" \
    "$platform_root/system/etc/init/servicemanager.recovery.rc" \
    "$platform_root/system/etc/recovery.fstab" \
    "$platform_root/system/etc/security/otacerts.zip" \
    "$platform_root/system/etc/vintf/manifest/android.hardware.boot-service.mtk.xml" \
    "$platform_root/system/etc/vintf/manifest/android.hardware.health-service.example.xml" \
    "$platform_root/system/lib64/librecovery_ui.so"

if find "$platform_root/system/etc/vintf/manifest" -maxdepth 1 -type f \
        -exec grep -l 'type="device"' {} + 2>/dev/null | grep -q .; then
    echo "pruned platform still contains a device VINTF fragment under /system" >&2
    exit 1
fi

for essential in \
    system/bin/init \
    system/bin/linker64 \
    system/lib64/libc.so \
    first_stage_ramdisk/fstab.mt6899 \
    lib/modules/modules.load; do
    if [ ! -f "$platform_root/$essential" ]; then
        echo "pruned platform is missing normal-boot file: $essential" >&2
        exit 1
    fi
done

platform_module_count="$(find "$platform_root/lib/modules" -maxdepth 1 -type f -name '*.ko' | wc -l)"
if [ "$platform_module_count" -ne 244 ]; then
    echo "pruned platform contains $platform_module_count modules; expected 244" >&2
    exit 1
fi

if [ "$AVB_MODE" = "disabled" ]; then
    fstab="${platform_root}/first_stage_ramdisk/fstab.mt6899"
    sed -E -i "s/,avb_keys=[^,[:space:]]+//g; s/,avb=[^,[:space:]]+//g; s/,avb,/,/g; s/,avb$//g; s/,avb / /g" "$fstab"
    if grep -qE "avb(=|,|$)|avb_keys=" "$fstab"; then echo "failed to remove first-stage AVB flags" >&2; exit 1; fi
fi
"$MKBOOTFS" -d "${PRODUCT_OUT}/system" "$platform_root" > "$platform_pruned_cpio"
"$LZ4" -l -12 --favor-decSpeed -f "$platform_pruned_cpio" "$platform_pruned_lz4" >/dev/null

total_ramdisk_size=$(( $(stat -c %s "$platform_pruned_lz4") + $(stat -c %s "$RECOVERY_LZ4") ))
if [ "$total_ramdisk_size" -ge 62000000 ]; then
    echo "combined vendor ramdisk is $total_ramdisk_size bytes; expected less than 62000000" >&2
    exit 1
fi

"$MKBOOTIMG" \
    --dtb "$recovery_host_dtb" \
    --base 0x3fff8000 \
    --pagesize 4096 \
    --vendor_cmdline "bootopt=64S3,32N2,64N2 erofs.reserved_pages=64" \
    --header_version 4 \
    --kernel_offset 0x00008000 \
    --ramdisk_offset 0x26f08000 \
    --tags_offset 0x07c88000 \
    --dtb_offset 0x07c88000 \
    --vendor_ramdisk "$platform_pruned_lz4" \
    --ramdisk_type RECOVERY \
    --ramdisk_name recovery \
    --vendor_ramdisk_fragment "$RECOVERY_LZ4" \
    --vendor_boot "$unsigned_image"

fingerprint="$(cat "${PRODUCT_OUT}/build_fingerprint.txt")"
"$AVBTOOL" add_hash_footer \
    --image "$unsigned_image" \
    --partition_size 67108864 \
    --partition_name vendor_boot \
    --prop "com.android.build.vendor_boot.fingerprint:${fingerprint}"

mkdir -p "$(dirname "$OUTPUT_IMAGE")"
mv -f "$unsigned_image" "$OUTPUT_IMAGE"
sha256sum "$OUTPUT_IMAGE" > "${OUTPUT_IMAGE}.sha256"

# OrangeFox creates these names before this post-build step. Replace both
# whole-image outputs so an ordinary vendorbootimage build cannot leave a
# recovery-only image that breaks Android boot. The installer ZIP still embeds
# the earlier recovery-only whole image, so withhold it until the installer is
# rebuilt after this system-compatible post-processing step.
cp -fp "$OUTPUT_IMAGE" "${PRODUCT_OUT}/vendor_boot.img"
cp -fp "$OUTPUT_IMAGE" "${PRODUCT_OUT}/OrangeFox-R12.0-Unofficial-rodin.img"
md5sum "${PRODUCT_OUT}/OrangeFox-R12.0-Unofficial-rodin.img" \
    > "${PRODUCT_OUT}/OrangeFox-R12.0-Unofficial-rodin.img.md5"
rm -f \
    "${PRODUCT_OUT}/OrangeFox-R12.0-Unofficial-rodin.zip" \
    "${PRODUCT_OUT}/OrangeFox-R12.0-Unofficial-rodin.zip.md5"

printf 'system-compatible vendor_boot: %s\n' "$OUTPUT_IMAGE"
printf 'firmware variant: %s\n' "$FIRMWARE_VARIANT"
printf 'pruned stock platform fragment: %s bytes (LZ4, %s stock modules)\n' \
    "$(stat -c %s "$platform_pruned_lz4")" "$platform_module_count"
printf 'recovery fragment: %s bytes (LZ4, %s modules)\n' "$(stat -c %s "$RECOVERY_LZ4")" "$module_count"
printf 'combined vendor ramdisk: %s bytes\n' "$total_ramdisk_size"
cat "${OUTPUT_IMAGE}.sha256"
