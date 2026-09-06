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

AVB_MODE="${RODIN_AVB_MODE:-enabled}"

case "$AVB_MODE" in
    enabled)
        DEFAULT_OUTPUT="${PRODUCT_OUT}/OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-ENABLED.img"
        ;;
    disabled)
        DEFAULT_OUTPUT="${PRODUCT_OUT}/OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-DISABLED.img"
        ;;
    *)
        echo "unsupported RODIN_AVB_MODE: $AVB_MODE" >&2
        exit 1
        ;;
esac

OUTPUT_IMAGE="${2:-$DEFAULT_OUTPUT}"

PLATFORM="${DEVICE_DIR}/prebuilt/unified/vendor_ramdisk00"
PLATFORM_SHA="dda9762619ee1cbe3019735103ddd25c62ebd9d2431e991303d5855520d93389"

DTB="${DEVICE_DIR}/prebuilt/dtb/mt6899-rodin.dtb"
DTB_SHA="38369239c984fc191e36d043d19ccbea4c1cd09ee6c80f8646d9493f650a30ae"

DTB_TOOL="${DEVICE_DIR}/tools/make-recovery-host-dtb.py"
RECOVERY="${PRODUCT_OUT}/obj/PACKAGING/vendor_ramdisk_fragments_intermediates/recovery.cpio.lz4"

HOST_OUT="${PRODUCT_OUT%/target/product/rodin}/host/linux-x86"
LZ4="${HOST_OUT}/bin/lz4"
MKBOOTFS="${HOST_OUT}/bin/mkbootfs"
MKBOOTIMG="${HOST_OUT}/bin/mkbootimg"
AVBTOOL="${HOST_OUT}/bin/avbtool"

for f in \
    "$PLATFORM" "$DTB" "$DTB_TOOL" "$RECOVERY" \
    "$LZ4" "$MKBOOTFS" "$MKBOOTIMG" "$AVBTOOL"; do
    test -f "$f" || {
        echo "missing build input: $f" >&2
        exit 1
    }
done

command -v zstd >/dev/null || {
    echo "missing host command: zstd" >&2
    exit 1
}

check_hash() {
    local file="$1"
    local expected="$2"
    local actual
    actual="$(sha256sum "$file" | awk '{print $1}')"
    test "$actual" = "$expected" || {
        echo "hash mismatch: $file" >&2
        echo "expected: $expected" >&2
        echo "actual:   $actual" >&2
        exit 1
    }
}

check_hash "$PLATFORM" "$PLATFORM_SHA"
check_hash "$DTB" "$DTB_SHA"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/rodin-unified-hos.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

ACTIVE_PLATFORM="$PLATFORM"

if [ "$AVB_MODE" = disabled ]; then
    mkdir -p "$WORK/platform"

    zstd -d -q -f \
        "$PLATFORM" \
        -o "$WORK/platform.cpio"

    (
        cd "$WORK/platform"
        cpio -idm --quiet --no-absolute-filenames \
            < "$WORK/platform.cpio"
    )

    FSTAB="$WORK/platform/first_stage_ramdisk/fstab.mt6899"

    sed -E -i \
        's/,avb_keys=[^,[:space:]]+//g;
         s/,avb=[^,[:space:]]+//g;
         s/,avb,/,/g;
         s/,avb$//g;
         s/,avb / /g' \
        "$FSTAB"

    if grep -qE 'avb(=|,|$)|avb_keys=' "$FSTAB"; then
        echo "failed to disable AVB in first-stage fstab" >&2
        exit 1
    fi

    "$MKBOOTFS" "$WORK/platform" \
        > "$WORK/platform-disabled.cpio"

    zstd -19 -T1 -q -f \
        "$WORK/platform-disabled.cpio" \
        -o "$WORK/platform-disabled.zst"

    ACTIVE_PLATFORM="$WORK/platform-disabled.zst"
fi

"$LZ4" -d -f \
    "$RECOVERY" \
    "$WORK/recovery.cpio" >/dev/null

RECOVERY_MODULES="$(
    cpio -it --quiet < "$WORK/recovery.cpio" |
    awk '/^lib\/modules\/.*\.ko$/ {n++} END {print n+0}'
)"

test "$RECOVERY_MODULES" -le 7 || {
    echo "recovery fragment contains $RECOVERY_MODULES modules; expected <= 7" >&2
    exit 1
}

PLATFORM_SIZE="$(stat -c %s "$ACTIVE_PLATFORM")"
RECOVERY_SIZE="$(stat -c %s "$RECOVERY")"
TOTAL=$((PLATFORM_SIZE + RECOVERY_SIZE))

test "$TOTAL" -lt 62000000 || {
    echo "combined vendor ramdisk too large: $TOTAL" >&2
    exit 1
}

python3 \
    "$DTB_TOOL" \
    "$DTB" \
    "$WORK/recovery-host.dtb"

"$MKBOOTIMG" \
    --dtb "$WORK/recovery-host.dtb" \
    --base 0x3fff8000 \
    --pagesize 4096 \
    --vendor_cmdline "bootopt=64S3,32N2,64N2 erofs.reserved_pages=64" \
    --header_version 4 \
    --kernel_offset 0x00008000 \
    --ramdisk_offset 0x26f08000 \
    --tags_offset 0x07c88000 \
    --dtb_offset 0x07c88000 \
    --vendor_ramdisk "$ACTIVE_PLATFORM" \
    --ramdisk_type RECOVERY \
    --ramdisk_name recovery \
    --vendor_ramdisk_fragment "$RECOVERY" \
    --vendor_boot "$WORK/vendor_boot.img"

FINGERPRINT="$(cat "${PRODUCT_OUT}/build_fingerprint.txt")"

"$AVBTOOL" add_hash_footer \
    --image "$WORK/vendor_boot.img" \
    --partition_size 67108864 \
    --partition_name vendor_boot \
    --prop "com.android.build.vendor_boot.fingerprint:${FINGERPRINT}"

mkdir -p "$(dirname "$OUTPUT_IMAGE")"
mv -f "$WORK/vendor_boot.img" "$OUTPUT_IMAGE"

sha256sum "$OUTPUT_IMAGE" > "${OUTPUT_IMAGE}.sha256"

cp -fp "$OUTPUT_IMAGE" "${PRODUCT_OUT}/vendor_boot.img"
cp -fp "$OUTPUT_IMAGE" "${PRODUCT_OUT}/OrangeFox-R12.0-Unofficial-rodin.img"

md5sum "${PRODUCT_OUT}/OrangeFox-R12.0-Unofficial-rodin.img" \
    > "${PRODUCT_OUT}/OrangeFox-R12.0-Unofficial-rodin.img.md5"

rm -f \
    "${PRODUCT_OUT}/OrangeFox-R12.0-Unofficial-rodin.zip" \
    "${PRODUCT_OUT}/OrangeFox-R12.0-Unofficial-rodin.zip.md5"

echo "===== UNIFIED HOS COMPLETE ====="
echo "AVB:      $AVB_MODE"
echo "PLATFORM: $PLATFORM_SIZE bytes Zstd"
echo "RECOVERY: $RECOVERY_SIZE bytes LZ4"
echo "TOTAL:    $TOTAL bytes"
echo "OUTPUT:   $OUTPUT_IMAGE"
cat "${OUTPUT_IMAGE}.sha256"
