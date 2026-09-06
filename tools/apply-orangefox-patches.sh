#!/usr/bin/env bash
set -euo pipefail

DEVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TOP_DIR="${1:-${RODIN_TOP_DIR:-$(cd -- "${DEVICE_DIR}/../fox_14.1" && pwd -P)}}"
RECOVERY_DIR="${TOP_DIR}/bootable/recovery"
BUILD_DIR="${TOP_DIR}/build/make"
HARDWARE_INTERFACES_DIR="${TOP_DIR}/hardware/interfaces"
SYSTEM_CORE_DIR="${TOP_DIR}/system/core"
UPDATE_ENGINE_DIR="${TOP_DIR}/system/update_engine"
VOLD_DIR="${TOP_DIR}/system/vold"
VENDOR_TWRP_DIR="${TOP_DIR}/vendor/twrp"

RECOVERY_PATCH="${DEVICE_DIR}/patches/bootable-recovery/rodin-complete.patch"
BUILD_PATCH="${DEVICE_DIR}/patches/build-make/rodin-complete.patch"
BOOTCONTROL_PATCH="${DEVICE_DIR}/patches/hardware-interfaces/rodin-fastbootd-bootcontrol-nonblocking.patch"
FASTBOOTD_PATCH="${DEVICE_DIR}/patches/system-core/rodin-fastbootd-optional-hals-nonblocking.patch"
UPDATE_ENGINE_PATCH="${DEVICE_DIR}/patches/system-update-engine/0001-update-engine-fix-rodin-ab-recovery-installation.patch"
VOLD_PATCH="${DEVICE_DIR}/patches/system-vold/0001-vold-restore-orangefox-decryption-support.patch"
VENDOR_TWRP_PATCH="${DEVICE_DIR}/patches/vendor-twrp/0001-twrp-fix-rodin-orangefox-build-configuration.patch"

recovery_complete_markers_present() {
    local marker

    for marker in \
        OF_SKIP_POST_DECRYPT_THEME_RELOAD \
        OF_LOAD_DEFAULT_LANGUAGE_BEFORE_DECRYPT \
        fallback_face \
        processKeyChord; do
        grep -RqsF -- "${marker}" "${RECOVERY_DIR}" || return 1
    done

    return 0
}

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

if recovery_complete_markers_present; then
    echo "OrangeFox recovery patch is already integrated (verified source markers)"
else
    apply_patch_once "${RECOVERY_DIR}" "${RECOVERY_PATCH}" "OrangeFox recovery"
fi

apply_patch_once "${UPDATE_ENGINE_DIR}" "${UPDATE_ENGINE_PATCH}" "update_engine A/B recovery support"
apply_patch_once "${VOLD_DIR}" "${VOLD_PATCH}" "OrangeFox vold decryption support"
apply_patch_once "${VENDOR_TWRP_DIR}" "${VENDOR_TWRP_PATCH}" "OrangeFox vendor/twrp configuration"

# NEES_RUNTIME_FIXES
#
# Apply the proven recovery OTA / Virtual A/B fixes before source
# verification so every build path validates the final source state.
NEES_PATCH_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$NEES_PATCH_TOOLS_DIR/apply-runtime-fixes.sh" "${TOP_DIR}" || exit 1

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
