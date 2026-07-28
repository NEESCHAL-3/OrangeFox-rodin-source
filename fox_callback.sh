#!/bin/bash

set -e

ramdisk="$1"
phase="$2"
terminfo="$ramdisk/system/etc/terminfo"

if [ "$phase" != "--first-call" ]; then
    exit 0
fi

# relink_libraries is a phony Make target and may leave an older library in
# recovery/root after libminuitwrp is rebuilt. Refresh it immediately before
# OrangeFox packs the recovery fragment.
product_out="$(dirname "$(dirname "$ramdisk")")"
minuitwrp_src="$product_out/system/lib64/libminuitwrp.so"
minuitwrp_dst="$ramdisk/system/lib64/libminuitwrp.so"
if [ -f "$minuitwrp_src" ]; then
    echo "-- Refreshing recovery libminuitwrp.so from the current build output"
    cp -fp "$minuitwrp_src" "$minuitwrp_dst"
fi

# The system-compatible image preserves the stock platform fragment's
# first-stage runtime and modules while pruning its duplicate recovery
# userspace. Recovery therefore only needs modules that are absent from stock
# or deliberately patched for recovery. modules.load.recovery remains intact
# and resolves the other modules from the platform fragment at boot.
if [ -d "$ramdisk/lib/modules" ]; then
    find "$ramdisk/lib/modules" -maxdepth 1 -type f -name '*.ko' -print0 |
        while IFS= read -r -d '' module; do
            case "$(basename "$module")" in
                focaltech_touch_rodin.ko|goodix_core_rodin.ko|nxp_i2c.ko|p73.ko|scp.ko|si_haptic.ko|xiaomi_touch_rodin.ko)
                    ;;
                *)
                    rm -f "$module"
                    ;;
            esac
        done
fi

# Keep one CJK-capable UI font. Rewrite every theme font reference before
# pruning so a missing optional font cannot abort GUI resource loading.
if [ -d "$ramdisk/twres/fonts" ]; then
    find "$ramdisk/twres" -type f -name '*.xml' -print0 |
        xargs -0 sed -Ei 's/filename="[^"]+\.(ttf|otf|ttc)"/filename="MiSans.ttf"/g'
    find "$ramdisk/twres/fonts" -maxdepth 1 -type f \
        ! -iname 'MiSans.ttf' \
        ! -iname '*Noto*.ttf' \
        ! -iname '*Noto*.otf' \
        ! -iname '*Noto*.ttc' \
        -delete
fi

# Keep the built-in languages that are actively maintained for this device.
if [ -d "$ramdisk/twres/languages" ]; then
    find "$ramdisk/twres/languages" -maxdepth 1 -type f \
        ! -name en.xml \
        ! -name es_ES.xml \
        ! -name hu_HU.xml \
        ! -name ja_JP.xml \
        ! -name zh_CN.xml \
        ! -name zh_TW.xml \
        -delete
fi

# lpdumpd is a diagnostic daemon, not the lptools implementation used for
# dynamic-partition operations. Its large snapshot/protobuf dependency chain
# is omitted while lptools, fastbootd, and update_engine_sideload are retained.
rm -f \
    "$ramdisk/system/bin/lpdump" \
    "$ramdisk/system/bin/lpdumpd" \
    "$ramdisk/system/etc/init/lpdumpd.rc" \
    "$ramdisk/system/lib64/liblpdump.so" \
    "$ramdisk/system/lib64/liblpdump_interface-cpp.so" \
    "$ramdisk/system/lib64/libprotobuf-cpp-full.so" \
    "$ramdisk/system/lib64/libsnapshot.so"

# Mini debug sections are not used on-device and are already compressed data,
# so LZ4 cannot reduce them further.
objcopy_bin="prebuilts/clang/host/linux-x86/clang-r510928/bin/llvm-objcopy"
readelf_bin="prebuilts/clang/host/linux-x86/clang-r510928/bin/llvm-readelf"
if [ ! -x "$objcopy_bin" ] || [ ! -x "$readelf_bin" ]; then
    echo "missing LLVM ELF tools" >&2
    exit 1
fi
while IFS= read -r -d '' binary; do
    if file "$binary" | grep -q ELF && \
            "$readelf_bin" -SW "$binary" 2>/dev/null | grep -q '\.gnu_debugdata'; then
        "$objcopy_bin" --remove-section=.gnu_debugdata "$binary"
    fi
done < <(find "$ramdisk/system" -type f -print0)

# UPX is an OrangeFox-supported size reduction. Limit it to binaries verified
# during the host-side layout test; first-stage init, linker, adbd, service
# managers, proprietary security HALs, and terminal binaries stay untouched.
upx_bin="vendor/recovery/tools/upx"
if [ ! -x "$upx_bin" ]; then
    echo "missing UPX: $upx_bin" >&2
    exit 1
fi
upx_binaries=(
    avbctl awk bc bootctl bu charger create_pl_dev dump_image e2fsck
    e2fsdroid erase_image exfat-fuse fastbootd fatlabel flash_image fsck.exfat
    fsck.f2fs fsck.fat fscryptpolicyget grep keystore2 keystore_cli_v2 logcat
    logd lptools lzma make_f2fs minadbd mke2fs mkexfatfs mkfs.fat nano
    ozip_decrypt pigz reboot recovery resetprop resize2fs rodin_omapi_bridge
    sgdisk simg2img sload_f2fs tune2fs twrp update_engine_sideload
    vendor.xiaomi.hw.touchfeature-service-recovery vold_prepare_subdirs
    watchdogd ziptool android.hardware.boot@1.2-service
)
for name in "${upx_binaries[@]}"; do
    binary="$ramdisk/system/bin/$name"
    if [ ! -f "$binary" ]; then
        echo "missing selected UPX binary: $binary" >&2
        exit 1
    fi
    chmod 0755 "$binary"
    "$upx_bin" -q --lzma "$binary" >/dev/null
    "$upx_bin" -q -t "$binary" >/dev/null
done

# Modern fs_config assigns unknown /sbin files mode 0644. Place the actual
# terminal tools and helper scripts under /system/bin (which receives 0755)
# and retain their historical /sbin paths as compatibility symlinks.
while IFS= read -r -d '' source; do
    name="$(basename "$source")"
    target="$ramdisk/system/bin/$name"
    if [ "$name" = nano ] && [ -f "$target" ]; then
        rm -f "$source"
    else
        rm -f "$target"
        mv "$source" "$target"
    fi
    ln -s "/system/bin/$name" "$source"
done < <(find "$ramdisk/sbin" -maxdepth 1 -type f -print0)

if [ -d "$terminfo" ]; then
    keep_dir=$(mktemp -d)
    trap 'rm -rf "$keep_dir"' EXIT

    for entry in a/ansi l/linux v/vt100 x/xterm x/xterm-256color; do
        if [ -f "$terminfo/$entry" ]; then
            mkdir -p "$keep_dir/$(dirname "$entry")"
            cp -p "$terminfo/$entry" "$keep_dir/$entry"
        fi
    done

    rm -rf "$terminfo"
    mv "$keep_dir" "$terminfo"
    trap - EXIT
fi

# These are build-debug manifests and are not consumed by recovery at runtime.
rm -f "$ramdisk/ramdisk-files.txt" "$ramdisk/ramdisk-files.sha256sum"
