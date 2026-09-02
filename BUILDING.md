# Building OrangeFox for Xiaomi rodin

[Repository](README.md) / [Documentation](docs/README.md)

This document describes the supported public build workflow for Xiaomi `rodin`.

The device tree must be located at:

`device/xiaomi/rodin`

inside a compatible OrangeFox 14.1 source tree.

<details>
<summary>On this page</summary>

- [1. Required host tools](#1-required-host-tools)
- [2. Device tree](#2-device-tree)
- [3. Pinned external patches](#3-pinned-external-patches)
- [4. Source verification](#4-source-verification)
- [5. Unified HOS PLATFORM](#5-unified-hos-platform)
- [6. AOSP profile](#6-aosp-profile)
- [7. Build all release variants](#7-build-all-release-variants)
- [8. Release outputs](#8-release-outputs)
- [9. AVB behavior](#9-avb-behavior)
- [10. Flashing a test build](#10-flashing-a-test-build)
- [11. Build verification](#11-build-verification)

</details>

## 1. Required host tools

In addition to the normal Android/OrangeFox build dependencies, the rodin build workflow requires:

- `bash`
- `python3`
- `git`
- `cpio`
- `zstd`
- `dtc`
- `fdtget`
- `fdtput`
- `sha256sum`

The build preflight checks required tools and pinned inputs before compilation.

## 2. Device tree

Clone or place this repository at:

`device/xiaomi/rodin`

Example source layout:

```text
<orangefox-root>/
├── bootable/
│   └── recovery/
├── build/
│   └── make/
├── device/
│   └── xiaomi/
│       └── rodin/
├── hardware/
│   └── interfaces/
├── system/
│   └── core/
└── vendor/
    └── recovery/
```

Do not run the release build from a standalone copy of this repository outside the Android source tree.

## 3. Pinned external patches

Rodin requires canonical changes outside the device tree for:

- `bootable/recovery`
- `build/make`
- `hardware/interfaces`
- `system/core`

These include the rodin recovery changes and the non-blocking Fastbootd HAL lookup fixes.

The release build automatically runs:

`tools/apply-orangefox-patches.sh`

The patch helper is safe to rerun on an already prepared source tree. It verifies an already-applied recovery patch through known source markers instead of blindly applying it twice.

## 4. Source verification

The build verifies the pinned OrangeFox source manifest.

Repositories intentionally modified by rodin patches are validated separately from the untouched pinned projects.

The verified patched development revisions are:

| External repository | Verified development revision |
| --- | --- |
| `bootable/recovery` | `eaa1bf3d2c71b4c8c2ecccdb24f1170b0fe4d8e7` |
| `hardware/interfaces` | `61f0bcd25bdbf2b6d4d978fdfa348bf01078a8f8` |
| `system/core` | `d4add349bc23456cd137d73b1acbcd789aaa5ed0` |

Binary and patch SHA-256 values are also checked by `tools/verify-build-inputs.sh`.

## 5. Unified HOS PLATFORM

HOS/OEM-port builds do not use a firmware-region build selector.

The pinned unified PLATFORM is:

`prebuilt/unified/vendor_ramdisk00`

SHA-256:

`dda9762619ee1cbe3019735103ddd25c62ebd9d2431e991303d5855520d93389`

It contains separate module trees for:

| Firmware family | Verified kernel release |
| --- | --- |
| CN | `6.6.77-android15-8-gca30f3b4bef6-abogki440974771-4k` |
| Global/MIXM and India | `6.6.89-android15-8-g8e4be6b47e40-ab14134548-4k` |

First-stage init automatically selects the module directory matching the running kernel.

The HOS PLATFORM uses Zstandard compression.

## 6. AOSP profile

AOSP remains independent from the unified HOS PLATFORM.

Its pinned inputs are:

```text
prebuilt/aosp/
├── bootconfig
└── vendor_ramdisk00
```

Do not replace the AOSP PLATFORM with the HOS unified PLATFORM.

## 7. Build all release variants

From:

`device/xiaomi/rodin`

run:

```bash
./build-release.sh
```

The script performs the complete workflow:

1. apply canonical external-source patches,
2. verify the pinned source and device inputs,
3. compile OrangeFox,
4. build the unified HOS AVB Enabled image,
5. build the unified HOS AVB Disabled image,
6. build the AOSP AVB Enabled image,
7. build the AOSP AVB Disabled image.

No firmware-region environment variable is required.

## 8. Release outputs

Successful builds produce:

```text
out/target/product/rodin/
├── OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-ENABLED.img
├── OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-DISABLED.img
├── OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-ENABLED.img
└── OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-DISABLED.img
```

The ordinary `vendor_boot.img` output is restored to the unified HOS AVB Enabled image after the release matrix is complete.

## 9. AVB behavior

HOS AVB Enabled uses the pinned unified PLATFORM unchanged.

HOS AVB Disabled temporarily unpacks the same PLATFORM, removes only the first-stage `avb` and `avb_keys` fstab flags, repacks the PLATFORM, and builds the disabled image.

The pinned unified PLATFORM itself remains unchanged.

AOSP AVB Enabled and Disabled are handled by the dedicated AOSP builder.

## 10. Flashing a test build

Rodin uses slot-specific vendor boot partitions.

Example:

```bash
fastboot flash vendor_boot_a <image>.img
fastboot reboot recovery
```

Valid partitions are:

```text
vendor_boot_a
vendor_boot_b
```

Do not use `vendor_boot_ab`.

For development tests, modify only the intended slot unless there is a specific reason to change both slots.

## 11. Build verification

Before publishing a build, verify that:

- all four expected images exist,
- SHA-256 files are recorded,
- HOS uses the unified Zstd PLATFORM,
- AOSP uses the dedicated AOSP PLATFORM,
- Fastbootd enters userspace mode,
- recovery touch and storage work,
- the intended AVB variant boots on the target ROM.

See [Verified Runtime Baseline](docs/VERIFIED-BASELINE.md) for the current runtime-verified baseline.

---

[Back to documentation](docs/README.md)
