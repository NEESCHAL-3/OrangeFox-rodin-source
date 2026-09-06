#!/usr/bin/env bash

PATCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TREE="${1:-${ANDROID_BUILD_TOP:-$(pwd)}}"

apply_one() {
    repo_rel="$1"
    patch="$2"
    repo="$TREE/$repo_rel"

    if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "ERROR: not a git repo: $repo"
        return 1
    fi

    if git -C "$repo" apply --reverse --check "$patch" >/dev/null 2>&1; then
        echo "[already applied] $repo_rel :: $(basename "$patch")"
        return 0
    fi

    echo "[apply] $repo_rel :: $(basename "$patch")"

    git -C "$repo" apply --check "$patch" || return 1
    git -C "$repo" apply "$patch" || return 1
}

echo "===== SYSTEM/CORE RUNTIME FIXES ====="
for patch in     "$PATCH_ROOT/patches/system-core/0001-fs_mgr-fix-virtual-ab-image-cleanup-in-recovery.patch"     "$PATCH_ROOT/patches/system-core/0002-fs_mgr-support-file-backed-virtual-ab-cows-in-recovery.patch"; do
    [ -f "$patch" ] || {
        echo "ERROR: missing runtime patch: $patch"
        exit 1
    }
    apply_one system/core "$patch" || exit 1
done

echo
echo "===== BOOTABLE/RECOVERY RUNTIME FIXES ====="
for patch in     "$PATCH_ROOT/patches/bootable-recovery/0002-recovery-fix-broken-legacy-fde-decrypt-watchdog.patch"     "$PATCH_ROOT/patches/bootable-recovery/0003-recovery-fix-rodin-adb-sideload-and-ab-ota.patch"     "$PATCH_ROOT/patches/bootable-recovery/0004-recovery-use-rodin-calibrated-haptic-strength.patch"; do
    [ -f "$patch" ] || {
        echo "ERROR: missing runtime patch: $patch"
        exit 1
    }
    apply_one bootable/recovery "$patch" || exit 1
done

echo
echo "Rodin runtime patch stack applied successfully."
