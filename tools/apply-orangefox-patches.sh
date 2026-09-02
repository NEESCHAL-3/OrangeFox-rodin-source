#!/usr/bin/env bash
set -euo pipefail

DEVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TOP_DIR="${1:-$(cd -- "${DEVICE_DIR}/../../.." && pwd -P)}"
RECOVERY_DIR="${TOP_DIR}/bootable/recovery"
BUILD_DIR="${TOP_DIR}/build/make"
HARDWARE_INTERFACES_DIR="${TOP_DIR}/hardware/interfaces"
SYSTEM_CORE_DIR="${TOP_DIR}/system/core"

RECOVERY_PATCH="${DEVICE_DIR}/patches/bootable-recovery/rodin-complete.patch"
BUILD_PATCH="${DEVICE_DIR}/patches/build-make/rodin-complete.patch"
BOOTCONTROL_PATCH="${DEVICE_DIR}/patches/hardware-interfaces/rodin-fastbootd-bootcontrol-nonblocking.patch"
FASTBOOTD_PATCH="${DEVICE_DIR}/patches/system-core/rodin-fastbootd-optional-hals-nonblocking.patch"

apply_patch_once() {
    local repository="$1" patch_file="$2" label="$3"

    if ! git -C "${repository}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "${label} repository not found: ${repository}" >&2
        exit 1
    fi
    if [[ ! -s "${patch_file}" ]]; then
        echo "Patch file not found: ${patch_file}" >&2
        exit 1
    fi

    if git -C "${repository}" apply --whitespace=nowarn --reverse --check "${patch_file}" 2>/dev/null; then
        echo "${label} patch is already applied"
    else
        git -C "${repository}" apply --whitespace=nowarn --check "${patch_file}"
        git -C "${repository}" apply --whitespace=nowarn "${patch_file}"
        echo "Applied ${patch_file}"
    fi
}

# These two patches are universal rodin fastbootd fixes.
# They must be applied before building fastbootd.
apply_patch_once "${HARDWARE_INTERFACES_DIR}" "${BOOTCONTROL_PATCH}" "BootControl non-blocking lookup"
apply_patch_once "${SYSTEM_CORE_DIR}" "${FASTBOOTD_PATCH}" "fastbootd non-blocking HAL lookup"

apply_patch_once "${BUILD_DIR}" "${BUILD_PATCH}" "OrangeFox build/make"
apply_patch_once "${RECOVERY_DIR}" "${RECOVERY_PATCH}" "OrangeFox recovery"

ENGLISH_LANGUAGE="${RECOVERY_DIR}/gui/theme/common/languages/en.xml"

if [[ ! -f "${ENGLISH_LANGUAGE}" ]]; then
    echo "Missing OrangeFox English language resource: ${ENGLISH_LANGUAGE}" >&2
    exit 1
fi

if command -v xmllint >/dev/null 2>&1; then
    xmllint --noout "${ENGLISH_LANGUAGE}"
fi

"${DEVICE_DIR}/tools/verify-build-inputs.sh" "${TOP_DIR}"
echo "OrangeFox rodin source patches and device inputs are ready"
