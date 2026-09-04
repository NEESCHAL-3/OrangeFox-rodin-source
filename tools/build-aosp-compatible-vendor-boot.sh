#!/usr/bin/env bash
set -euo pipefail

DEVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TOP_DIR="${RODIN_TOP_DIR:-$(cd -- "${DEVICE_DIR}/../fox_14.1" && pwd -P)}"
PRODUCT_OUT="${1:-${OUT_DIR:-${TOP_DIR}/out}/target/product/rodin}"
AVB_MODE="${RODIN_AVB_MODE:-enabled}"

case "$AVB_MODE" in
    enabled|disabled) ;;
    *)
        echo "unsupported RODIN_AVB_MODE: $AVB_MODE" >&2
        exit 1
        ;;
esac

AOSP_RAMDISK="${DEVICE_DIR}/prebuilt/aosp/vendor_ramdisk00"
AOSP_BOOTCONFIG="${DEVICE_DIR}/prebuilt/aosp/bootconfig"
STOCK_DTB="${DEVICE_DIR}/prebuilt/dtb/mt6899-rodin.dtb"

AOSP_RAMDISK_SHA256="44713e36fb3dc9ec6d50c71570a43be1fafe1260cd5cc090f565e670983bd0b3"
AOSP_BOOTCONFIG_SHA256="2545ea616b81794569f66d0fb40e9ae712446f52e4711d25bd9c1c683a5f93a1"
STOCK_DTB_SHA256="38369239c984fc191e36d043d19ccbea4c1cd09ee6c80f8646d9493f650a30ae"

RECOVERY_HOST_DTB_TOOL="${DEVICE_DIR}/tools/make-recovery-host-dtb.py"
RECOVERY_LZ4="${PRODUCT_OUT}/obj/PACKAGING/vendor_ramdisk_fragments_intermediates/recovery.cpio.lz4"

HOST_OUT="${PRODUCT_OUT%/target/product/rodin}/host/linux-x86/bin"
LZ4="${HOST_OUT}/lz4"
MKBOOTIMG="${HOST_OUT}/mkbootimg"
MKBOOTFS="${HOST_OUT}/mkbootfs"
AVBTOOL="${HOST_OUT}/avbtool"

case "$AVB_MODE" in
    enabled)
        DEFAULT_OUTPUT="${PRODUCT_OUT}/OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-ENABLED.img"
        ;;
    disabled)
        DEFAULT_OUTPUT="${PRODUCT_OUT}/OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-DISABLED.img"
        ;;
esac

OUTPUT_IMAGE="${2:-$DEFAULT_OUTPUT}"

for f in \
    "$AOSP_RAMDISK" \
    "$AOSP_BOOTCONFIG" \
    "$STOCK_DTB" \
    "$RECOVERY_HOST_DTB_TOOL" \
    "$RECOVERY_LZ4" \
    "$LZ4" \
    "$MKBOOTIMG" \
    "$MKBOOTFS" \
    "$AVBTOOL"; do
    test -f "$f" || {
        echo "missing required input: $f" >&2
        exit 1
    }
done

check_sha256() {
    local expected="$1"
    local file="$2"
    local actual
    actual="$(sha256sum "$file" | awk '{print $1}')"

    if [ "$actual" != "$expected" ]; then
        echo "hash mismatch: $file" >&2
        echo "expected $expected" >&2
        echo "actual   $actual" >&2
        exit 1
    fi
}

check_sha256 "$AOSP_RAMDISK_SHA256" "$AOSP_RAMDISK"
check_sha256 "$AOSP_BOOTCONFIG_SHA256" "$AOSP_BOOTCONFIG"
check_sha256 "$STOCK_DTB_SHA256" "$STOCK_DTB"

work="$(mktemp -d "${TMPDIR:-/tmp}/rodin-aosp-vendorboot.XXXXXX")"
trap 'rm -rf "$work"' EXIT

platform_ramdisk="$AOSP_RAMDISK"
recovery_host_dtb="${work}/recovery-host.dtb"
unsigned="${work}/vendor_boot.img"

python3 "$RECOVERY_HOST_DTB_TOOL" \
    "$STOCK_DTB" \
    "$recovery_host_dtb"

if [ "$AVB_MODE" = "disabled" ]; then
    platform_cpio="${work}/platform.cpio"
    platform_root="${work}/platform"
    patched_cpio="${work}/platform-patched.cpio"
    patched_lz4="${work}/platform-patched.cpio.lz4"

    mkdir -p "$platform_root"

    "$LZ4" -d -f "$AOSP_RAMDISK" "$platform_cpio" >/dev/null

    (
        cd "$platform_root"
        cpio -idm --quiet --no-absolute-filenames < "$platform_cpio"
    )

    fstab="${platform_root}/first_stage_ramdisk/system/etc/fstab.mt6899"

    test -f "$fstab" || {
        echo "AOSP first-stage fstab missing: $fstab" >&2
        exit 1
    }

    sed -E -i \
        's/,avb_keys=[^,[:space:]]+//g;
         s/,avb=[^,[:space:]]+//g;
         s/,avb,/,/g;
         s/,avb$//g;
         s/,avb / /g' \
        "$fstab"

    if grep -qE 'avb(=|,|$)|avb_keys=' "$fstab"; then
        echo "failed to remove AOSP AVB fs_mgr flags" >&2
        exit 1
    fi

    "$MKBOOTFS" -d "${PRODUCT_OUT}/system" \
        "$platform_root" > "$patched_cpio"

    "$LZ4" -l -12 --favor-decSpeed -f \
        "$patched_cpio" \
        "$patched_lz4" >/dev/null

    platform_ramdisk="$patched_lz4"
fi

total_size=$(( \
    $(stat -c %s "$platform_ramdisk") + \
    $(stat -c %s "$RECOVERY_LZ4") \
))

if [ "$total_size" -ge 62000000 ]; then
    echo "combined ramdisk too large: $total_size" >&2
    exit 1
fi

"$MKBOOTIMG" \
    --dtb "$recovery_host_dtb" \
    --base 0x3fff8000 \
    --pagesize 4096 \
    --vendor_cmdline "bootopt=64S3,32N2,64N2 kasan=off rcupdate.rcu_expedited=1 rcutree.enable_rcu_lazy bootconfig" \
    --header_version 4 \
    --kernel_offset 0x00008000 \
    --ramdisk_offset 0x26f08000 \
    --tags_offset 0x07c88000 \
    --dtb_offset 0x07c88000 \
    --vendor_ramdisk "$platform_ramdisk" \
    --ramdisk_type RECOVERY \
    --ramdisk_name recovery \
    --vendor_ramdisk_fragment "$RECOVERY_LZ4" \
    --vendor_bootconfig "$AOSP_BOOTCONFIG" \
    --vendor_boot "$unsigned"

fingerprint="$(cat "${PRODUCT_OUT}/build_fingerprint.txt")"

"$AVBTOOL" add_hash_footer \
    --image "$unsigned" \
    --partition_size 67108864 \
    --partition_name vendor_boot \
    --prop "com.android.build.vendor_boot.fingerprint:${fingerprint}"

mkdir -p "$(dirname "$OUTPUT_IMAGE")"
cp -fp "$unsigned" "$OUTPUT_IMAGE"

echo
echo "AOSP vendor_boot complete"
echo "AVB mode: $AVB_MODE"
echo "output: $OUTPUT_IMAGE"
sha256sum "$OUTPUT_IMAGE"
