#!/usr/bin/env bash
set -euo pipefail

DEVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if [ -n "${ORANGEFOX_TOP:-}" ]; then
    TOP_DIR="${ORANGEFOX_TOP}"
elif [ -f "${DEVICE_DIR}/../../../build/envsetup.sh" ]; then
    TOP_DIR="$(cd -- "${DEVICE_DIR}/../../.." && pwd -P)"
else
    TOP_DIR="${HOME}/fox_14.1"
fi

if [ ! -f "${TOP_DIR}/build/envsetup.sh" ]; then
    echo "OrangeFox source tree not found: ${TOP_DIR}" >&2
    echo "Set ORANGEFOX_TOP=/path/to/fox_14.1 and retry." >&2
    exit 1
fi

if [ "${TERM_PROGRAM:-}" = "vscode" ]; then
    echo "warning: run this from a normal Terminal, not the VS Code integrated terminal." >&2
    echo "warning: systemd-oomd can kill the whole VS Code scope during Soong spikes." >&2
fi

export OF_LOW_MEMORY_BUILD="${OF_LOW_MEMORY_BUILD:-1}"
export OF_BUILD_JOBS="${OF_BUILD_JOBS:-1}"
export ALLOW_MISSING_DEPENDENCIES="${ALLOW_MISSING_DEPENDENCIES:-true}"
export FOX_BUILD_DEVICE="${FOX_BUILD_DEVICE:-rodin}"
export FOX_AB_DEVICE="${FOX_AB_DEVICE:-1}"
export FOX_VIRTUAL_AB_DEVICE="${FOX_VIRTUAL_AB_DEVICE:-1}"
export OF_FORCE_PREBUILT_KERNEL="${OF_FORCE_PREBUILT_KERNEL:-1}"
export NINJA_ARGS="${NINJA_ARGS:--j${OF_BUILD_JOBS} -l${OF_BUILD_JOBS}}"
export SOONG_UI_NINJA_ARGS="${SOONG_UI_NINJA_ARGS:--j${OF_BUILD_JOBS} -l${OF_BUILD_JOBS}}"
export NINJA_HIGHMEM_NUM_JOBS="${NINJA_HIGHMEM_NUM_JOBS:-1}"
export GOMAXPROCS="${GOMAXPROCS:-1}"
export GOGC="${GOGC:-20}"
export GOMEMLIMIT="${GOMEMLIMIT:-6GiB}"
export _JAVA_OPTIONS="${_JAVA_OPTIONS:--Xmx1g}"
export LC_ALL="${LC_ALL:-C}"

swap_kb="$(awk '/^SwapTotal:/ { print $2 }' /proc/meminfo)"
swap_gb="$(awk -v kb="${swap_kb}" 'BEGIN { printf "%.1f GB", kb / 1024 / 1024 }')"
min_swap_kb=$((12 * 1024 * 1024))
if [ "${OF_SKIP_SWAP_CHECK:-0}" != "1" ] && [ "${swap_kb}" -lt "${min_swap_kb}" ]; then
    cat >&2 <<EOF
Swap is too small for this low-memory Android build.
Current swap: ${swap_gb}
Recommended: at least 12 GB, preferably 16 GB

Add temporary swap, then rerun:
  sudo fallocate -l 16G /swap-build.img
  sudo chmod 600 /swap-build.img
  sudo mkswap /swap-build.img
  sudo swapon /swap-build.img

To bypass this check anyway, set OF_SKIP_SWAP_CHECK=1.
EOF
    exit 1
fi

renice -n 15 -p "$$" >/dev/null 2>&1 || true
ionice -c3 -p "$$" >/dev/null 2>&1 || true

export OUT_DIR="${OUT_DIR:-${TOP_DIR}/out}"
LOG_DIR="${OUT_DIR}/logs"
mkdir -p "${LOG_DIR}"

TARGETS=("$@")
if [ "${#TARGETS[@]}" -eq 0 ]; then
    TARGETS=(adbd vendorbootimage)
fi

LOG_FILE="${LOG_DIR}/rodin-lowmem-$(date +%Y%m%d-%H%M%S).log"

cd "${TOP_DIR}"
set +u
source build/envsetup.sh
lunch twrp_rodin-ap2a-eng

if printf ' %s ' "${TARGETS[*]}" | grep -q ' vendorbootimage '; then
    # fox_callback.sh intentionally mutates the assembled recovery root (UPX,
    # pruning, and /sbin symlinks). Reusing that generated tree makes the next
    # OrangeFox pass try to overwrite dangling links and recompress UPX files.
    rm -rf "${OUT_DIR}/target/product/rodin/recovery"
    rm -f "${OUT_DIR}/target/product/rodin/obj/PACKAGING/recovery_intermediates/ramdisk_files-timestamp"
fi

echo "log: ${LOG_FILE}"
echo "targets: ${TARGETS[*]}"

set +e
mka -j"${OF_BUILD_JOBS}" "${TARGETS[@]}" 2>&1 | tee "${LOG_FILE}"
status=${PIPESTATUS[0]}
set -e

if [ "${status}" -ne 0 ]; then
    echo "build failed; see ${LOG_FILE}" >&2
elif printf ' %s ' "${TARGETS[*]}" | grep -q ' vendorbootimage '; then
    if ! "${DEVICE_DIR}/tools/build-system-compatible-vendor-boot.sh"; then
        echo "system-compatible vendor_boot repack failed" >&2
        status=1
    fi
fi

exit "${status}"
