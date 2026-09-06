# Unified HOS / OEM-Port `vendor_boot`

[Repository](../README.md) / [Documentation](README.md)

This document describes the region-agnostic OrangeFox HOS/OEM-port `vendor_boot` design for Xiaomi `rodin`, where runtime compatibility is selected by the running kernel family rather than a market-region profile.

<details>
<summary>On this page</summary>

- [Goal](#goal)
- [Final layout](#final-layout)
- [Unified PLATFORM](#unified-platform)
- [6.6.77 module tree](#667-module-tree)
- [6.6.89 module tree](#6689-module-tree)
- [Runtime selection](#runtime-selection)
- [Module metadata](#module-metadata)
- [OrangeFox-specific modules](#orangefox-specific-modules)
- [Why Zstandard is used](#why-zstandard-is-used)
- [AVB Enabled](#avb-enabled)
- [AVB Disabled](#avb-disabled)
- [AOSP is separate](#aosp-is-separate)
- [Runtime proof](#runtime-proof)
- [Release outputs](#release-outputs)
- [Developer workflow](#developer-workflow)

</details>

## Goal

Older rodin builds used a build-time firmware profile and produced region-specific HOS images.

The current design removes that requirement.

There is now one HOS/OEM-port image containing everything required for both verified kernel families.

## Final layout

The HOS `vendor_boot` uses header version 4 and contains:

```text
vendor_boot
├── PLATFORM  [Zstandard]
└── RECOVERY  [LZ4]
```

PLATFORM contains the first-stage Android environment.

RECOVERY contains OrangeFox.

## Unified PLATFORM

Pinned input:

`prebuilt/unified/vendor_ramdisk00`

SHA-256:

`dda9762619ee1cbe3019735103ddd25c62ebd9d2431e991303d5855520d93389`

The PLATFORM contains two complete module trees:

```text
/lib/modules/
├── 6.6.77-android15-8-gca30f3b4bef6-abogki440974771-4k/
└── 6.6.89-android15-8-g8e4be6b47e40-ab14134548-4k/
```

## 6.6.77 module tree

The 6.6.77 directory contains the complete matching Rodin stock module set plus the OrangeFox rodin-specific recovery modules required during recovery boot.

Verified 6.6.77 runtime kernel:

`6.6.77-android15-8-gca30f3b4bef6-abogki440974771-4k`

## 6.6.89 module tree

The 6.6.89 directory contains the complete matching Rodin stock module set plus the same OrangeFox rodin-specific recovery modules.

Verified 6.6.89 runtime kernel:

`6.6.89-android15-8-g8e4be6b47e40-ab14134548-4k`

The stock Global/MIXM and India PLATFORM ramdisks were compared directly.

Both contain:

- 485 files
- 244 stock kernel modules

Their complete module payloads are identical.

The stock module vermagic is:

`6.6.89-android15-8-g03fb7c87b0b5-4k`

This historical comparison proved that those regional stock packages share the same 6.6.89 module payload; runtime selection itself is kernel-based.

## Runtime selection

No region property is used.

No firmware selector script is used.

No custom Android service is used.

Android first-stage init already reads the running kernel release with `uname -r`.

When it finds an exact matching directory under `/lib/modules`, it uses that directory for module loading.

Therefore:

| Running kernel | Selected module tree |
| --- | --- |
| 6.6.77 | 6.6.77 module tree |
| 6.6.89 | 6.6.89 module tree |

The same `vendor_boot` automatically adapts to the running verified kernel family.

## Module metadata

Stock `modules.dep` originally used absolute paths such as:

`/lib/modules/foo.ko`

For the kernel-specific directory layout, dependency paths are relative to the selected module directory.

This allows Android `libmodprobe` to resolve dependencies inside the correct kernel ABI tree.

`modules.load.recovery` is preserved so first-stage recovery loading follows the verified rodin module sequence.

## OrangeFox-specific modules

The recovery-specific rodin modules include the modules required for touch, haptics, SCP interaction and related device functionality.

The same proven recovery module set is available in both kernel-release directories.

Runtime testing confirmed that the custom recovery modules load successfully under both verified kernel families.

## Why Zstandard is used

Keeping both complete stock module sets inside a single PLATFORM increased the uncompressed ramdisk substantially.

Using LZ4 for the entire combined PLATFORM left insufficient practical `vendor_boot` headroom.

Both verified kernels expose Zstandard initramfs support.

The unified PLATFORM is therefore compressed using Zstandard level 19.

No stock kernel modules need to be deleted.

No module debug/version metadata needs to be stripped.

The OrangeFox RECOVERY fragment remains LZ4.

## AVB Enabled

The pinned unified PLATFORM contains the normal stock first-stage fstab AVB configuration.

AVB Enabled uses this PLATFORM directly.

## AVB Disabled

The AVB Disabled builder:

1. decompresses the pinned unified PLATFORM,
2. removes only first-stage `avb` and `avb_keys` flags,
3. repacks a temporary Zstandard PLATFORM,
4. builds the disabled `vendor_boot`,
5. discards the temporary PLATFORM.

The pinned source input is never replaced with the disabled derivative.

## AOSP is separate

This design applies only to HOS/OEM-port recovery.

AOSP uses:

`prebuilt/aosp/vendor_ramdisk00`

and:

`prebuilt/aosp/bootconfig`

AOSP does not use the unified HOS PLATFORM and remains a separate vendor/recovery environment.

## Runtime proof

The first unified AVB-disabled prototype had SHA-256:

`57df845928e5716ae486f9d1be4e2e577006040fe432b274ba4b16384dfab2ad`

The exact same image booted OrangeFox with:

- Rodin 6.6.77 kernel
- Rodin 6.6.89 kernel

Verified under both included:

- correct stock module loading
- OrangeFox touch modules
- haptics
- userdata mapping
- recovery boot
- Fastbootd

Fastbootd reported:

```text
is-userspace: yes
product: rodin
```

## Release outputs

The unified design reduces the old region-specific release matrix to four images:

```text
Release images
├── HOS / OEM-Port
│   ├── AVB Enabled
│   └── AVB Disabled
└── AOSP
    ├── AVB Enabled
    └── AVB Disabled
```

There are no market-region-specific HOS release images.

## Developer workflow

Developers do not manually merge ramdisks or modules.

From `device/xiaomi/rodin`:

```bash
./build-release.sh
```

The unified PLATFORM is a pinned build input and the release tooling handles packaging automatically.

---

[Back to documentation](README.md)
