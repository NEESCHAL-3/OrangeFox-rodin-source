# Unified HOS / OEM-Port `vendor_boot`

[Repository](../README.md) / [Documentation](README.md)

This document describes the region-agnostic OrangeFox HOS/OEM-port `vendor_boot` design for Xiaomi `rodin`, where runtime compatibility is selected by the running kernel family rather than a market-region profile.

<details>
<summary>On this page</summary>

- [Goal](#goal)
- [Final layout](#final-layout)
- [Unified PLATFORM](#unified-platform)
- [6.6.77 stock module baseline](#667-stock-module-baseline)
- [6.6.89 stock module baseline](#6689-stock-module-baseline)
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

There is now one HOS/OEM-port image designed around the compatible Android15-6.6 GKI/KMI and Rodin vendor environment rather than a fixed kernel patchlevel.

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

## 6.6.77 stock module baseline

The 6.6.77 directory contains the complete matching Rodin stock module set plus the OrangeFox rodin-specific recovery modules required during recovery boot.

Verified 6.6.77 runtime kernel:

`6.6.77-android15-8-gca30f3b4bef6-abogki440974771-4k`

## 6.6.89 stock module baseline

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

This historical comparison proved that those regional stock packages share the same 6.6.89 module payload. That payload is retained as a stock baseline rather than an exact kernel-patchlevel requirement.

## GKI/KMI runtime compatibility

No market-region property, firmware selector script, or custom Android region service is used.

The retained 6.6.77 and 6.6.89 module payloads are proven stock baselines, not an exact kernel-version whitelist.

Rodin HOS/OEM-port OrangeFox has been runtime-tested with:

- stock `6.6.77-android15-8-gca30f3b4bef6-abogki440974771-4k`
- stock `6.6.89-android15-8-g8e4be6b47e40-ab14134548-4k`
- stock EEA `6.6.118-android15-8-ge56cf6b09cca-ab15511674-4k`
- custom `6.6.142-EVONIX-COS-V3.5`

The same recovery therefore is not tied to one 6.6.x patchlevel. Compatibility depends on a usable Android15-6.6 GKI/vendor-module environment rather than an exact `uname -r` directory match.

## Module metadata

Stock `modules.dep` originally used absolute paths such as:

`/lib/modules/foo.ko`

For the stored stock-baseline layout, module dependency metadata remains internally consistent with its payload.

Android module loading resolves dependencies from the available compatible module environment; an exact running-kernel directory-name match is not the compatibility boundary.

`modules.load.recovery` is preserved so first-stage recovery loading follows the verified rodin module sequence.

## OrangeFox-specific modules

The recovery-specific rodin modules include the modules required for touch, haptics, SCP interaction and related device functionality.

The proven recovery module payload is retained with both stock baselines.

Runtime testing confirmed that the Rodin recovery modules load successfully across the tested Android15-6.6 GKI environments, including stock 6.6.118 and custom 6.6.142.

## Why Zstandard is used

Keeping both complete stock module sets inside a single PLATFORM increased the uncompressed ramdisk substantially.

Using LZ4 for the entire combined PLATFORM left insufficient practical `vendor_boot` headroom.

The stock baseline kernels used to construct the unified PLATFORM support Zstandard initramfs decompression.

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
