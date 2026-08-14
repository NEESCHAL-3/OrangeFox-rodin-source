#!/usr/bin/env bash
set -euo pipefail

DEVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TOP_DIR="${1:-$(cd -- "${DEVICE_DIR}/../../.." && pwd -P)}"
failures=0

fail() {
    echo "ERROR: $*" >&2
    failures=$((failures + 1))
}

case "${RODIN_FIRMWARE_VARIANT:-india}" in
    india) ;;
    *) fail "unsupported RODIN_FIRMWARE_VARIANT: ${RODIN_FIRMWARE_VARIANT} (expected india)" ;;
esac

for command_name in bash cut file git grep python3 sed sha256sum sort stat; do
    command -v "${command_name}" >/dev/null 2>&1 || \
        fail "required host command not found: ${command_name}"
done

search_tree() {
    local marker="$1" directory="$2"

    if command -v rg >/dev/null 2>&1; then
        rg -q --fixed-strings -- "$marker" "$directory"
    else
        grep -RqsF -- "$marker" "$directory"
    fi
}

check_file() {
    [[ -f "$1" ]] || fail "missing file: $1"
}

check_size() {
    local path="$1" expected="$2" actual
    check_file "$path"
    [[ -f "$path" ]] || return
    actual="$(stat -c %s "$path")"
    [[ "$actual" == "$expected" ]] || fail "unexpected size for $path: $actual (expected $expected)"
}

check_sha256() {
    local path="$1" expected="$2" actual
    check_file "$path"
    [[ -f "$path" ]] || return
    actual="$(sha256sum "$path" | cut -d' ' -f1)"
    [[ "$actual" == "$expected" ]] || fail "unexpected SHA-256 for $path: $actual"
}

check_revision() {
    local repository="$1" expected="$2" label="$3" actual

    if ! git -C "$repository" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        fail "$label repository not found: $repository"
        return
    fi
    actual="$(git -C "$repository" rev-parse HEAD)"
    [[ "$actual" == "$expected" ]] || \
        fail "$label revision is $actual (expected $expected)"
}

check_contains() {
    local path="$1" marker="$2" description="$3"

    check_file "$path"
    [[ -f "$path" ]] || return
    grep -qF -- "$marker" "$path" || fail "$description: $path"
}

[[ -f "${TOP_DIR}/build/envsetup.sh" ]] || fail "not an OrangeFox source root: ${TOP_DIR}"
check_file "${DEVICE_DIR}/patches/bootable-recovery/rodin-complete.patch"
check_file "${DEVICE_DIR}/patches/build-make/rodin-complete.patch"
check_file "${DEVICE_DIR}/manifests/device-blobs.sha256"
check_file "${DEVICE_DIR}/manifests/orangefox-fox_14.1-pinned.xml"
check_sha256 "${DEVICE_DIR}/patches/build-make/rodin-complete.patch" 5f2d3f43a4d78eee6d560a4a169df30fc95de6fa2ed294e3210e684a641a8329
check_sha256 "${DEVICE_DIR}/patches/bootable-recovery/rodin-complete.patch" 7a9e58bd9ac062bf93c67c080ba3ec397ce3b06530283b4eb07031e6163dc763
check_sha256 "${DEVICE_DIR}/manifests/device-blobs.sha256" 9d341097f1b2a3ddafd1c64564242ebec0f423a181b778e57ed5ee6b74ac6404

if [[ "${RODIN_ALLOW_UNPINNED_SOURCE:-0}" != "1" ]]; then
    if ! python3 "${DEVICE_DIR}/tools/verify-source-manifest.py" "${TOP_DIR}" \
            "${DEVICE_DIR}/manifests/orangefox-fox_14.1-pinned.xml"; then
        fail "OrangeFox source tree differs from the pinned manifest"
    fi
    check_revision "${TOP_DIR}/vendor/recovery" \
        0d7959e6538db5ddfff892cf7dfe207c68b0b753 "OrangeFox vendor/recovery"
fi

while IFS= read -r relative; do
    [[ -n "$relative" ]] && check_file "${DEVICE_DIR}/${relative}"
done < <(sed -n 's#.*$(DEVICE_PATH)/\([^:[:space:]]*\):.*#\1#p' "${DEVICE_DIR}/device.mk" | sort -u)

check_size "${DEVICE_DIR}/prebuilt/dtbo.img" 8388608
check_size "${DEVICE_DIR}/prebuilt/dtb/mt6899-rodin.dtb" 444841
check_sha256 "${DEVICE_DIR}/prebuilt/kernel" 55caa83bf1dd1ab5e34521f1faa18532a6110a065123577a1a62d80ee5178569
check_sha256 "${DEVICE_DIR}/prebuilt/dtb/mt6899-rodin.dtb" 38369239c984fc191e36d043d19ccbea4c1cd09ee6c80f8646d9493f650a30ae
check_sha256 "${DEVICE_DIR}/prebuilt/dtbo.img" ccd008dc7336301b7cc6fab7b59400b3debd2866f055f085e61696dbc7c0f298
check_size "${DEVICE_DIR}/prebuilt/india/vendor_ramdisk00" 29235084
check_sha256 "${DEVICE_DIR}/prebuilt/india/vendor_ramdisk00" c1b5ad776c93f89c6bf227ffecbf21ff3338236833d424446b388bb9819587a6
check_sha256 "${DEVICE_DIR}/recovery/root/lib/modules/scp.ko" ebae9554467e148256cfbab90f0b6d7943d2818ae0cf09bad8aec650bbd99310
check_sha256 "${DEVICE_DIR}/recovery/root/lib/modules/goodix_core_rodin.ko" 3c2fe7db061743134b715e5a7c361690c3fa36cfacb9c15c1e0bb122e51ac966
check_sha256 "${DEVICE_DIR}/recovery/root/lib/modules/focaltech_touch_rodin.ko" da967ce3f94ecc81153ee91f7e06a2b48eda0526b857688016ef660844bc70b2
check_sha256 "${DEVICE_DIR}/proprietary/odm/lib64/libtouchreport_alg_fts.so" e7cfb2b4299f0ed317225d53987b6cf9157fb4956b6ff7d42966c101faf3f1e4
check_sha256 "${DEVICE_DIR}/proprietary/fonts/MiSans.ttf" db6151d5ab2de091fbd8450df9bee1ffcde396c5a359b1030c3c58a952d81be9

# FocalTech support spans binary blobs, module metadata, product copy rules,
# init links, and the runtime readiness check. Validate every layer so a new
# source checkout cannot silently build a Goodix-only image.
check_contains "${DEVICE_DIR}/device.mk" \
    'focaltech_touch_rodin.ko:recovery/root/lib/modules/focaltech_touch_rodin.ko' \
    "FocalTech module copy rule missing"
check_contains "${DEVICE_DIR}/device.mk" \
    'libtouchreport_alg_fts.so:recovery/root/system/lib64/rodin-touch/libtouchreport_alg_fts.so' \
    "FocalTech algorithm copy rule missing"
check_contains "${DEVICE_DIR}/device.mk" \
    'rodin_fts_thp_config.ini:recovery/root/system/etc/rodin-touch/rodin_fts_thp_config.ini' \
    "FocalTech TouchReport config copy rule missing"
check_contains "${DEVICE_DIR}/recovery/root/lib/modules/modules.load.recovery" \
    'focaltech_touch_rodin.ko' "FocalTech module load entry missing"
check_contains "${DEVICE_DIR}/recovery/root/lib/modules/modules.dep" \
    '/lib/modules/focaltech_touch_rodin.ko:' "FocalTech dependency metadata missing"
check_contains "${DEVICE_DIR}/recovery/root/init.recovery.mt6899.rc" \
    'libtouchreport_alg_fts.so /vendor/odm/lib64/libtouchreport_alg_fts.so' \
    "FocalTech algorithm runtime link missing"
check_contains "${DEVICE_DIR}/recovery/root/init.recovery.mt6899.rc" \
    'rodin_fts_thp_config.ini /vendor/odm/firmware/rodin_fts_thp_config.ini' \
    "FocalTech config runtime link missing"
check_contains "${DEVICE_DIR}/recovery/root/system/bin/load-touch-modules.sh" \
    'load_module focaltech_touch_rodin.ko' "FocalTech runtime loader entry missing"
check_contains "${DEVICE_DIR}/recovery/root/system/bin/wait-touch-service.sh" \
    'goodix_ts|focaltech_ts|fts_ts)' "FocalTech input readiness names missing"
check_contains "${DEVICE_DIR}/fox_callback.sh" \
    'focaltech_touch_rodin.ko|goodix_core_rodin.ko' \
    "FocalTech module is not retained in the final ramdisk"
check_contains "${DEVICE_DIR}/Android.bp" \
    'name: "rodin_android.hardware.secure_element-V1-ndk"' \
    "Recovery secure-element prebuilt module is missing"
check_contains "${DEVICE_DIR}/Android.bp" \
    'name: "rodin_android.se.omapi-V1-ndk"' \
    "Recovery OMAPI prebuilt module is missing"
check_contains "${DEVICE_DIR}/Android.bp" \
    '"rodin_android.se.omapi-V1-ndk"' \
    "OMAPI bridge is not linked against the recovery prebuilt"
check_contains "${DEVICE_DIR}/Android.bp" \
    '"android.hardware.secure_element-V1-ndk-source"' \
    "Secure-element AIDL generated headers are missing"
check_contains "${DEVICE_DIR}/Android.bp" \
    '"android.se.omapi-V1-ndk-source"' \
    "OMAPI AIDL generated headers are missing"
check_contains "${DEVICE_DIR}/Android.bp" \
    '"librodin_libcxx_compat"' \
    "OMAPI bridge is not linked against the libc++ compatibility shim"
check_contains "${DEVICE_DIR}/tools/build-system-compatible-vendor-boot.sh" \
    'RODIN_FIRMWARE_VARIANT' \
    "firmware profile selector missing from vendor_boot repacker"
check_contains "${DEVICE_DIR}/recovery/root/init.recovery.keymint.rc" \
    'service rodin.omapi_bridge /system/bin/rodin_omapi_bridge' \
    "OMAPI bridge service definition missing"
check_contains "${DEVICE_DIR}/recovery/root/init.recovery.keymint.rc" \
    'setenv LD_LIBRARY_PATH /vendor/lib64:/system/lib64' \
    "OMAPI bridge cannot search vendor libraries"
check_contains "${DEVICE_DIR}/recovery/root/init.recovery.keymint.rc" \
    'start vendor.weaver_nxp' \
    "Weaver is not started with the TEE services"

if [[ -f "${DEVICE_DIR}/manifests/device-blobs.sha256" ]] && \
        ! (cd "${TOP_DIR}" && sha256sum --check --quiet "${DEVICE_DIR}/manifests/device-blobs.sha256"); then
    fail "one or more device blobs differ from manifests/device-blobs.sha256"
fi

for script in \
    "${DEVICE_DIR}/build-lowmem.sh" \
    "${DEVICE_DIR}/fox_callback.sh" \
    "${DEVICE_DIR}/tools/apply-orangefox-patches.sh" \
    "${DEVICE_DIR}/tools/build-system-compatible-vendor-boot.sh" \
    "${DEVICE_DIR}/tools/collect-compat-report.sh" \
    "${DEVICE_DIR}/tools/patch-recovery-touch-modules.sh" \
    "${DEVICE_DIR}/tools/verify-build-inputs.sh"; do
    check_file "$script"
    if [[ -f "$script" ]]; then
        bash -n "$script" || fail "shell syntax check failed: $script"
    fi
done

check_file "${DEVICE_DIR}/tools/verify-source-manifest.py"
if [[ -f "${DEVICE_DIR}/tools/verify-source-manifest.py" ]]; then
    python3 "${DEVICE_DIR}/tools/verify-source-manifest.py" --help >/dev/null || \
        fail "Python syntax check failed: tools/verify-source-manifest.py"
fi

if [[ -d "${TOP_DIR}/bootable/recovery" ]]; then
    for marker in \
        OF_SKIP_POST_DECRYPT_THEME_RELOAD \
        OF_LOAD_DEFAULT_LANGUAGE_BEFORE_DECRYPT \
        fallback_face \
        processKeyChord; do
        search_tree "$marker" "${TOP_DIR}/bootable/recovery" || \
            fail "OrangeFox source patch marker missing: $marker"
    done
    for language in en; do
        check_file "${TOP_DIR}/bootable/recovery/gui/theme/common/languages/${language}.xml"
    done

    customization="${TOP_DIR}/bootable/recovery/gui/theme/portrait_hdpi/pages/customization.xml"
    theme_fonts="${TOP_DIR}/bootable/recovery/gui/theme/portrait_hdpi/themes/font.xml"
    check_file "${customization}"
    check_file "${theme_fonts}"
    if [[ -f "${customization}" ]] && grep -Eq \
            '<listitem name="(Roboto|Roboto Slab|Google Sans|Euclid Flex|Fira Code|Exo 2|Inter Display)"' \
            "${customization}"; then
        fail "customization still exposes fonts removed from the recovery image"
    fi
    if [[ -f "${theme_fonts}" ]] && ! grep -q \
            '<variable name="theme_font" value="MiSans"/>' "${theme_fonts}"; then
        fail "OrangeFox primary theme font is not MiSans"
    fi
    if [[ -f "${theme_fonts}" ]] && ! grep -q \
            '<variable name="theme_sec_font" value="MiSans"/>' "${theme_fonts}"; then
        fail "OrangeFox secondary theme font is not MiSans"
    fi
fi

if ! grep -q '\[ -n "$input" \]' \
        "${DEVICE_DIR}/recovery/root/system/bin/wait-touch-service.sh"; then
    fail "touch readiness check is not controller-independent"
fi

if [[ -d "${TOP_DIR}/build/make" ]]; then
    for marker in \
        Fox_Before_Recovery_Image \
        orangefox_envsetup \
        BUILD_BROKEN_PLUGIN_VALIDATION; do
        search_tree "$marker" "${TOP_DIR}/build/make" || \
            fail "OrangeFox build/make patch marker missing: $marker"
    done
    if search_tree COMPRESSION_COMMANDR "${TOP_DIR}/build/make"; then
        fail "OrangeFox build/make contains misspelled COMPRESSION_COMMANDR"
    fi
fi

if command -v file >/dev/null 2>&1 && [[ -f "${DEVICE_DIR}/proprietary/fonts/MiSans.ttf" ]]; then
    file "${DEVICE_DIR}/proprietary/fonts/MiSans.ttf" | grep -q 'TrueType Font data' || \
        fail "MiSans must use TrueType glyf outlines, not CFF"
fi

if (( failures > 0 )); then
    echo "Preflight failed with ${failures} error(s)" >&2
    exit 1
fi

echo "rodin build input verification passed"
echo "OrangeFox top: ${TOP_DIR}"
echo "Device tree:   ${DEVICE_DIR}"
