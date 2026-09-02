# Legacy Edify Installer Compatibility

[Repository](../README.md) / [Documentation](README.md)

Rodin includes recovery-side compatibility work for older Edify-based ZIP installers.

<details>
<summary>On this page</summary>

- [Problem](#problem)
- [Fallback behavior](#fallback-behavior)
- [Restored Edify functions](#restored-edify-functions)
- [Validation](#validation)
- [Source](#source)

</details>

## Problem

Some older recovery ZIPs carry an ARM32 executable at:

`META-INF/com/google/android/update-binary`

The current rodin recovery userspace is ARM64. Executing an incompatible ARM32 updater directly is not reliable on this environment.

## Fallback behavior

The recovery patch detects the legacy ARM32 updater case and falls back to the built-in ARM64 updater at:

`/system/bin/updater`

The fallback updater is part of the recovery image and is built for the current recovery userspace.

## Restored Edify functions

The compatibility work restores the functions required by the tested legacy installer path, including:

- `delete`
- `delete_recursive`
- `package_extract_dir`
- `symlink`
- `set_perm`
- `set_perm_recursive`
- `set_metadata`
- `set_metadata_recursive`

The verified source also carries related applypatch/blockimg/repacker fixes in the runtime-verified baseline patch.

## Validation

A real legacy ARM32 Edify ZIP was successfully executed on-device through the ARM64 fallback path.

The verified fallback updater SHA-256 is:

`e531f3724bc3176dc21985fef0c1f14021fe65eae79baad3562dd262b1fec08b`

This validation proves the tested installer path. It does not guarantee that every old Edify ZIP or every historical updater extension is supported.

## Source

The primary fallback work is published as:

`patches/bootable-recovery/0004-recovery-add-ARM64-fallback-for-legacy-ARM32-Edify-i.patch`

Additional runtime-verified compatibility work is contained in patch 5 and in the complete recovery patch.

See [External Source Patches](PATCHES.md) for exact source bases, target commits and patch hashes.

---

[Back to documentation](README.md)
