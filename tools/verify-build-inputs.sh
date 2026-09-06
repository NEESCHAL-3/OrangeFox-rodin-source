#!/usr/bin/env bash
set -euo pipefail

DEVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TOP_DIR="${1:-${RODIN_TOP_DIR:-$(cd -- "${DEVICE_DIR}/../fox_14.1" && pwd -P)}}"
failures=0

fail() {
    echo "ERROR: $*" >&2
    failures=$((failures + 1))
}

for command_name in bash cpio cut file git grep python3 sed sha256sum sort stat zstd; do
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
check_file "${DEVICE_DIR}/patches/hardware-interfaces/rodin-fastbootd-bootcontrol-nonblocking.patch"
check_file "${DEVICE_DIR}/patches/system-core/rodin-fastbootd-optional-hals-nonblocking.patch"
check_file "${DEVICE_DIR}/manifests/device-blobs.sha256"
check_file "${DEVICE_DIR}/manifests/orangefox-fox_14.1-pinned.xml"
check_sha256 "${DEVICE_DIR}/patches/build-make/rodin-complete.patch" 91f01d03733c66f54aa57be01eee4089efd37ec9c455618d1ef41e457ddbee36
check_sha256 "${DEVICE_DIR}/patches/bootable-recovery/rodin-complete.patch" 79ac7f1f769788b048ce5648a9bc94b8870cc1aa18da2436d546db2cdd433da5
check_sha256 "${DEVICE_DIR}/patches/hardware-interfaces/rodin-fastbootd-bootcontrol-nonblocking.patch" e10f789766f359d5d4b91d2fa7ee8418d5c39694f7c914d5cc02c6aa533755b8
check_sha256 "${DEVICE_DIR}/patches/system-core/rodin-fastbootd-optional-hals-nonblocking.patch" 740b10ad8cae477e8d387406b61594db869f83ab3fe0a15af46ec4ca6fc655e6
check_sha256 "${DEVICE_DIR}/manifests/device-blobs.sha256" 31a8dcf9d81db9262fc3d8d72bb7561391c1ad33623bfd0a6af4165d3ea7f532

if [[ "${RODIN_ALLOW_UNPINNED_SOURCE:-0}" != "1" ]]; then
    filtered_manifest="$(mktemp "${TMPDIR:-/tmp}/rodin-pinned-manifest.XXXXXX.xml")"

    python3 - \
        "${DEVICE_DIR}/manifests/orangefox-fox_14.1-pinned.xml" \
        "${filtered_manifest}" <<'PYXML'
import sys
import xml.etree.ElementTree as ET

src, dst = sys.argv[1], sys.argv[2]

excluded = {
    "bootable/recovery",
    "build/make",
    "hardware/interfaces",
    "system/core",
    "system/update_engine",
    "system/vold",
    "vendor/twrp",
}

tree = ET.parse(src)
root = tree.getroot()

for project in list(root.findall("project")):
    if project.get("path") in excluded:
        root.remove(project)

tree.write(dst, encoding="unicode")
PYXML

    if ! python3 "${DEVICE_DIR}/tools/verify-source-manifest.py" \
            "${TOP_DIR}" "${filtered_manifest}"; then
        fail "OrangeFox source tree differs from the pinned manifest"
    fi

    rm -f "${filtered_manifest}"

    check_revision "${TOP_DIR}/bootable/recovery" \
        73c82389541f3f79e9562ed0a278f604bedff920 \
        "patched bootable/recovery"

    check_revision "${TOP_DIR}/hardware/interfaces" \
        61f0bcd25bdbf2b6d4d978fdfa348bf01078a8f8 \
        "patched hardware/interfaces"

    check_revision "${TOP_DIR}/system/core" \
        d4add349bc23456cd137d73b1acbcd789aaa5ed0 \
        "patched system/core"

    check_revision "${TOP_DIR}/build/make" \
        927c3001c92c44ffd3f2b9c76ea140f23226d931 \
        "patched build/make"

    check_revision "${TOP_DIR}/system/update_engine" \
        41d967c9c323f74f7c803189e494da4c6b379217 \
        "patched system/update_engine"

    check_revision "${TOP_DIR}/system/vold" \
        e4a15a6f99e6c5c1fb2945e7be34b39aab5e7c40 \
        "patched system/vold"

    check_revision "${TOP_DIR}/vendor/twrp" \
        d7f3fe68cbb2997f888e6e807d44be1d50bcd42e \
        "patched vendor/twrp"

    check_revision "${TOP_DIR}/vendor/recovery" \
        af3d99b83adedf88fa9992d9320c5ce9811c6b08 \
        "OrangeFox vendor/recovery"
fi

# Confirm the universal fastbootd fix is actually present in the source tree.
check_contains "${TOP_DIR}/hardware/interfaces/boot/aidl/client/include/BootControlClient.h"     "TryGetService();"     "non-blocking BootControl API is missing"

check_contains "${TOP_DIR}/hardware/interfaces/boot/aidl/client/BootControlClient.cpp"     "BootControlClient::TryGetService()"     "non-blocking BootControl implementation is missing"

check_contains "${TOP_DIR}/system/core/fastboot/device/fastboot_device.cpp"     "AServiceManager_checkService(service_name.c_str())"     "fastbootd non-blocking AIDL lookup is missing"

check_contains "${TOP_DIR}/system/core/fastboot/device/fastboot_device.cpp"     "BootControlClient::TryGetService()"     "fastbootd non-blocking BootControl lookup is missing"

while IFS= read -r relative; do
    [[ -n "$relative" ]] && check_file "${DEVICE_DIR}/${relative}"
done < <(sed -n 's#.*$(DEVICE_PATH)/\([^:[:space:]]*\):.*#\1#p' "${DEVICE_DIR}/device.mk" | sort -u)

check_size "${DEVICE_DIR}/prebuilt/dtbo.img" 8388608
check_size "${DEVICE_DIR}/prebuilt/dtb/mt6899-rodin.dtb" 444841
check_sha256 "${DEVICE_DIR}/prebuilt/kernel" 55caa83bf1dd1ab5e34521f1faa18532a6110a065123577a1a62d80ee5178569
check_sha256 "${DEVICE_DIR}/prebuilt/dtb/mt6899-rodin.dtb" 38369239c984fc191e36d043d19ccbea4c1cd09ee6c80f8646d9493f650a30ae
check_sha256 "${DEVICE_DIR}/prebuilt/unified/vendor_ramdisk00" dda9762619ee1cbe3019735103ddd25c62ebd9d2431e991303d5855520d93389
check_size "${DEVICE_DIR}/prebuilt/aosp/vendor_ramdisk00" 15341278
check_size "${DEVICE_DIR}/prebuilt/aosp/bootconfig" 149
check_sha256 "${DEVICE_DIR}/prebuilt/aosp/vendor_ramdisk00" 44713e36fb3dc9ec6d50c71570a43be1fafe1260cd5cc090f565e670983bd0b3
check_sha256 "${DEVICE_DIR}/prebuilt/aosp/bootconfig" 2545ea616b81794569f66d0fb40e9ae712446f52e4711d25bd9c1c683a5f93a1
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
    'prebuilt/unified/vendor_ramdisk00' \
    "unified HOS PLATFORM input missing from vendor_boot builder"
check_contains "${DEVICE_DIR}/tools/build-system-compatible-vendor-boot.sh" \
    'RODIN_AVB_MODE' \
    "HOS AVB mode selector missing from vendor_boot builder"
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

if [[ -f "${DEVICE_DIR}/PATCHSET-RECOVERY-OTA.sha256" ]] && \
        ! (cd "${DEVICE_DIR}" && sha256sum --check --quiet PATCHSET-RECOVERY-OTA.sha256); then
    fail "one or more proven recovery OTA patches differ from PATCHSET-RECOVERY-OTA.sha256"
fi

for script in \
    "${DEVICE_DIR}/build-lowmem.sh" \
    "${DEVICE_DIR}/fox_callback.sh" \
    "${DEVICE_DIR}/tools/apply-orangefox-patches.sh" \
    "${DEVICE_DIR}/tools/apply-runtime-fixes.sh" \
    "${DEVICE_DIR}/build-release.sh" \
    "${DEVICE_DIR}/tools/build-system-compatible-vendor-boot.sh" \
    "${DEVICE_DIR}/tools/build-vendorboot-variants.sh" \
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

    check_file "${customization}"

    #
    # Rodin intentionally uses the stock OrangeFox theme/font setup.
    # Compare against origin/fox_14.1 without assuming where the font
    # variables live in the theme tree.
    #
    stock_customization="$(mktemp "${TMPDIR:-/tmp}/rodin-stock-customization.XXXXXX")"

    if ! git -C "${TOP_DIR}/bootable/recovery" \
            show origin/fox_14.1:gui/theme/portrait_hdpi/pages/customization.xml \
            > "${stock_customization}"; then
        fail "unable to read stock OrangeFox customization.xml"
    fi

    if ! cmp -s "${customization}" "${stock_customization}"; then
        fail "OrangeFox customization.xml differs from the intended stock theme"
    fi

    current_font_defs="$(
        grep -RhsE \
            '<variable name="theme_(sec_)?font"' \
            "${TOP_DIR}/bootable/recovery/gui/theme" 2>/dev/null \
        | sort -u
    )"

    stock_font_defs="$(
        git -C "${TOP_DIR}/bootable/recovery" \
            grep -h -E \
            '<variable name="theme_(sec_)?font"' \
            origin/fox_14.1 -- gui/theme 2>/dev/null \
        | sort -u
    )"

    if [[ "${current_font_defs}" != "${stock_font_defs}" ]]; then
        fail "OrangeFox theme font definitions differ from stock fox_14.1"
    fi

    rm -f "${stock_customization}"
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
