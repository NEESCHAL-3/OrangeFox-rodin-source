#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${1:-rodin-compat-$(date +%Y%m%d-%H%M%S)}"
IMAGE="${2:-}"

mkdir -p "${OUTPUT_DIR}"

capture_host() {
    local output="$1"
    shift
    "$@" >"${OUTPUT_DIR}/${output}" 2>&1 || true
}

capture_shell() {
    local output="$1" command="$2"
    adb shell "${command}" >"${OUTPUT_DIR}/${output}" 2>&1 || true
}

capture_host adb-devices.txt adb devices -l
if command -v fastboot >/dev/null 2>&1; then
    capture_host fastboot-devices.txt fastboot devices
    if command -v timeout >/dev/null 2>&1; then
        capture_host fastboot-vars.txt timeout 8 fastboot getvar all
    fi
fi

if [[ -n "${IMAGE}" ]]; then
    if [[ -f "${IMAGE}" ]]; then
        capture_host image-sha256.txt sha256sum "${IMAGE}"
        capture_host image-file.txt file "${IMAGE}"
    else
        printf 'image not found: %s\n' "${IMAGE}" >"${OUTPUT_DIR}/image-error.txt"
    fi
fi

if ! adb get-state >/dev/null 2>&1; then
    echo "No ADB device; saved the available host/fastboot information in ${OUTPUT_DIR}"
    exit 0
fi

capture_shell properties.txt '
for name in \
    ro.product.device ro.product.model ro.build.fingerprint \
    ro.vendor.build.fingerprint ro.vendor.build.version.incremental \
    ro.boot.slot_suffix ro.boot.hardware ro.boot.bootreason \
    ro.boot.verifiedbootstate ro.boot.vbmeta.device_state \
    vendor.touch.modules.ready vendor.touch.service.ready \
    init.svc.rodin-touch-loader init.svc.rodin-touchfeature \
    init.svc.rodin-touch-wait; do
    printf "%s=%s\n" "$name" "$(getprop "$name")"
done'
capture_shell kernel.txt 'uname -a; cat /proc/version; cat /proc/cmdline'
capture_shell modules.txt 'cat /proc/modules'
capture_shell touch-modules.txt '
cat /proc/modules | grep -E "goodix|focaltech|fts|xiaomi_touch|scp|tinysys" || true
for module in goodix_core_rodin focaltech_touch_rodin xiaomi_touch_rodin scp; do
    if [ -d "/sys/module/$module" ]; then
        echo "loaded: $module"
    fi
done'
capture_shell input-devices.txt '
for path in /sys/class/input/input*/name; do
    printf "%s: " "$path"
    cat "$path" 2>/dev/null
done
getevent -pl'
capture_shell touch-sysfs.txt '
for device in /sys/bus/spi/devices/*; do
    if [ -d "$device" ]; then
        echo "--- $device"
        printf "driver: "
        readlink -f "$device/driver" 2>/dev/null || true
        printf "modalias: "
        cat "$device/modalias" 2>/dev/null || true
    fi
done
for path in \
    /sys/devices/virtual/touch/touch_dev/enable_touch_raw \
    /sys/devices/virtual/touch/touch_dev/*vendor* \
    /sys/bus/spi/devices/*/modalias \
    /sys/bus/spi/devices/*/uevent; do
    if [ -e "$path" ]; then
        echo "--- $path"
        cat "$path" 2>/dev/null
    fi
done'
capture_shell touch-files.txt '
ls -l /lib/modules/*goodix* /lib/modules/*focal* /lib/modules/*touch* 2>/dev/null
sha256sum /lib/modules/goodix_core_rodin.ko \
    /lib/modules/focaltech_touch_rodin.ko \
    /lib/modules/xiaomi_touch_rodin.ko 2>/dev/null || true'
capture_shell block-layout.txt '
slot="$(getprop ro.boot.slot_suffix)"
ls -l /dev/block/by-name/vendor_boot* /dev/block/by-name/boot* \
    /dev/block/by-name/dtbo* 2>/dev/null
if [ -n "$slot" ] && [ -r "/dev/block/by-name/vendor_boot$slot" ]; then
    sha256sum "/dev/block/by-name/vendor_boot$slot"
fi'
capture_shell dmesg-touch.txt 'dmesg | grep -iE "goodix|focaltech|fts_ts|touch-spi|touchreport|scp|tinysys|ipi"'
capture_shell dmesg-full.txt 'dmesg'
capture_shell recovery-log.txt 'cat /tmp/recovery.log'
capture_shell logcat.txt 'logcat -b all -d'

mkdir -p "${OUTPUT_DIR}/pstore"
adb pull /sys/fs/pstore "${OUTPUT_DIR}/pstore" >"${OUTPUT_DIR}/pstore-pull.txt" 2>&1 || true

echo "Compatibility report saved to ${OUTPUT_DIR}"
echo "Review serial numbers and logs before sharing it publicly"
