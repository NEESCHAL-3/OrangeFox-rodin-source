#!/usr/bin/env bash
set -euo pipefail

DEVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TOP_DIR="${1:-$(cd -- "${DEVICE_DIR}/../../.." && pwd -P)}"
RECOVERY_DIR="${TOP_DIR}/bootable/recovery"
BUILD_DIR="${TOP_DIR}/build/make"
RECOVERY_PATCH="${DEVICE_DIR}/patches/orangefox-recovery.patch"
BUILD_PATCH="${DEVICE_DIR}/patches/orangefox-build-make.patch"

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

apply_patch_once "${BUILD_DIR}" "${BUILD_PATCH}" "OrangeFox build/make"
apply_patch_once "${RECOVERY_DIR}" "${RECOVERY_PATCH}" "OrangeFox recovery"

for language in es_ES hu_HU zh_CN zh_TW; do
    source_file="${RECOVERY_DIR}/gui/theme/extra-languages/languages/${language}.xml"
    target_file="${RECOVERY_DIR}/gui/theme/common/languages/${language}.xml"
    if [[ ! -f "${source_file}" ]]; then
        echo "Missing OrangeFox language source: ${source_file}" >&2
        exit 1
    fi
    cp -fp "${source_file}" "${target_file}"
done

if command -v xmllint >/dev/null 2>&1; then
    xmllint --noout \
        "${RECOVERY_DIR}/gui/theme/common/languages/es_ES.xml" \
        "${RECOVERY_DIR}/gui/theme/common/languages/hu_HU.xml" \
        "${RECOVERY_DIR}/gui/theme/common/languages/ja_JP.xml" \
        "${RECOVERY_DIR}/gui/theme/common/languages/zh_CN.xml" \
        "${RECOVERY_DIR}/gui/theme/common/languages/zh_TW.xml"
fi

"${DEVICE_DIR}/tools/verify-build-inputs.sh" "${TOP_DIR}"
echo "OrangeFox rodin source patches and device inputs are ready"
