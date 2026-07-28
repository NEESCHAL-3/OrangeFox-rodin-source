#!/usr/bin/env bash
set -euo pipefail

DEVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TOP_DIR="$(cd -- "${DEVICE_DIR}/../../.." && pwd -P)"
UNPACK_BOOTIMG="${TOP_DIR}/system/tools/mkbootimg/unpack_bootimg.py"

EXPECTED_VENDOR_BOOT_SIZE=67108864
EXPECTED_VENDOR_BOOT_SHA256="72b8ae7637af1924de8312855790de91f99abbc9c8c8ab6003ddce14abc4d956"
EXPECTED_PLATFORM_SIZE=29235080
EXPECTED_PLATFORM_SHA256="349cc6598f70ae401afe3071abed6de00815af39c5aded3551cff23364208731"
EXPECTED_DTB_SHA256="38369239c984fc191e36d043d19ccbea4c1cd09ee6c80f8646d9493f650a30ae"
DESTINATION="${DEVICE_DIR}/prebuilt/global/vendor_ramdisk00"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

check_size() {
    local path="$1" expected="$2" actual
    actual="$(stat -c %s "$path")"
    [[ "$actual" == "$expected" ]] || \
        die "unexpected size for $path: $actual (expected $expected)"
}

check_sha256() {
    local path="$1" expected="$2" actual
    actual="$(sha256sum "$path" | awk '{print $1}')"
    [[ "$actual" == "$expected" ]] || \
        die "unexpected SHA-256 for $path: $actual"
}

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 /path/to/rodin_global_images_OS3.0.301.0.WOJMIXM_16.0/images/vendor_boot.img" >&2
    exit 2
fi

INPUT_VENDOR_BOOT="$1"
[[ -f "$INPUT_VENDOR_BOOT" ]] || die "vendor_boot image not found: $INPUT_VENDOR_BOOT"
[[ -f "$UNPACK_BOOTIMG" ]] || die "unpack_bootimg.py not found: $UNPACK_BOOTIMG"

for command_name in mktemp python3 sha256sum stat awk install mv; do
    command -v "$command_name" >/dev/null 2>&1 || die "required host command not found: $command_name"
done

# This importer is intentionally pinned to the Global 3.0.301 release. Kernel
# modules in its platform ramdisk differ from the CN 3.0.303 base and cannot be
# safely substituted with a fragment from another firmware revision.
check_size "$INPUT_VENDOR_BOOT" "$EXPECTED_VENDOR_BOOT_SIZE"
check_sha256 "$INPUT_VENDOR_BOOT" "$EXPECTED_VENDOR_BOOT_SHA256"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/rodin-global-vendor-boot.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT
python3 "$UNPACK_BOOTIMG" --boot_img "$INPUT_VENDOR_BOOT" --out "$work_dir"

platform_ramdisk="${work_dir}/vendor_ramdisk00"
dtb="${work_dir}/dtb"
[[ -f "$platform_ramdisk" ]] || die "missing type-1 platform fragment after unpacking"
[[ -f "$dtb" ]] || die "missing DTB after unpacking"
check_size "$platform_ramdisk" "$EXPECTED_PLATFORM_SIZE"
check_sha256 "$platform_ramdisk" "$EXPECTED_PLATFORM_SHA256"
check_sha256 "$dtb" "$EXPECTED_DTB_SHA256"

destination_dir="$(dirname "$DESTINATION")"
mkdir -p "$destination_dir"
temporary_destination="${destination_dir}/.vendor_ramdisk00.$$"
trap 'rm -rf "$work_dir" "$temporary_destination"' EXIT
install -m 0644 "$platform_ramdisk" "$temporary_destination"
check_sha256 "$temporary_destination" "$EXPECTED_PLATFORM_SHA256"
mv -f "$temporary_destination" "$DESTINATION"

echo "Imported Global OS3.0.301.0.WOJMIXM platform ramdisk: $DESTINATION"
sha256sum "$DESTINATION"
