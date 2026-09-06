# Development Workflow

[Repository](../README.md) / [Documentation](README.md)

This document describes the supported contributor workflow for OrangeFox on Xiaomi `rodin`.

<details>
<summary>On this page</summary>

- [1. Source layout](#1-source-layout)
- [2. Canonical external patches](#2-canonical-external-patches)
- [3. Source verification](#3-source-verification)
- [4. Unified HOS development model](#4-unified-hos-development-model)
- [5. Unified PLATFORM maintenance](#5-unified-platform-maintenance)
- [6. AOSP development model](#6-aosp-development-model)
- [7. Building](#7-building)
- [8. Release matrix](#8-release-matrix)
- [9. Fastbootd development](#9-fastbootd-development)
- [10. Recovery module development](#10-recovery-module-development)
- [11. Runtime validation](#11-runtime-validation)
- [12. ROM-install preservation](#12-rom-install-preservation)
- [13. Patch maintenance](#13-patch-maintenance)

</details>

## 1. Source layout

The device tree must live inside the OrangeFox source tree at:

`device/xiaomi/rodin`

Expected layout:

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

The build and verification scripts derive the OrangeFox source root from this location.

Do not run release builds from a standalone copy of the device repository.

## 2. Canonical external patches

Rodin carries required source changes outside the device tree.

Canonical patch files are stored under:

```text
patches/
├── bootable-recovery/
├── build-make/
├── hardware-interfaces/
└── system-core/
```

They cover:

- OrangeFox/TWRP rodin recovery behavior
- build/make integration
- non-blocking BootControl lookup
- non-blocking optional Fastbootd HAL lookup

Release builds apply them automatically. For manual development source preparation, use:

```bash
tools/apply-orangefox-patches.sh
```

The helper is designed to tolerate an already-prepared development tree and must never blindly apply the complete recovery patch twice.

## 3. Source verification

For manual source verification, run:

```bash
tools/verify-build-inputs.sh <orangefox-root>
```

The verifier checks:

- the pinned OrangeFox source manifest
- intentionally patched external repositories
- canonical patch SHA-256 values
- device binary inputs
- required rodin source markers
- the unified HOS PLATFORM SHA-256
- shell/Python helper integrity

Untouched source projects must continue to match the pinned manifest.

Do not solve a verification failure by weakening or removing integrity checks.

## 4. Unified HOS development model

HOS/OEM-port recovery is region-agnostic. There are no India, Global, China, EEA, or other market-region build profiles.

There is one pinned unified PLATFORM:

`prebuilt/unified/vendor_ramdisk00`

SHA-256:

`dda9762619ee1cbe3019735103ddd25c62ebd9d2431e991303d5855520d93389`

It contains independent module trees for:

- Rodin 6.6.77 kernel family
- Rodin 6.6.89 kernel family

First-stage init selects the correct module directory from the running kernel release.

Do not add a market-region build variable back into the build system; runtime compatibility is determined by the kernel/vendor environment.

## 5. Unified PLATFORM maintenance

The unified PLATFORM is a pinned, verified build input.

Do not casually regenerate or modify it during unrelated recovery development.

Any intentional PLATFORM update must include:

1. documented donor inputs,
2. complete module-count verification,
3. module metadata validation,
4. first-stage fstab validation,
5. compression/size validation,
6. runtime testing on the supported kernel families,
7. a new SHA-256 in the verifier and documentation.

The stored PLATFORM is AVB-enabled.

The AVB-disabled HOS image is derived temporarily during packaging and must not overwrite the pinned PLATFORM.

## 6. AOSP development model

AOSP remains separate from HOS.

Pinned AOSP inputs are:

```text
prebuilt/aosp/
├── bootconfig
└── vendor_ramdisk00
```

Changes to unified HOS handling must not silently modify the AOSP build path.

Likewise, AOSP-specific changes should not add CN/HOS module content to the AOSP profile.

## 7. Building

For a complete release build, run from `device/xiaomi/rodin`:

```bash
./build-release.sh
```

This is the preferred public build entrypoint.

It performs:

```text
Apply complete canonical Rodin patch stack, including proven recovery OTA / Virtual A/B fixes
    │
    ▼
Verify source and binary inputs
    │
    ▼
Compile OrangeFox recovery
├── Unified HOS AVB Enabled
├── Unified HOS AVB Disabled
├── AOSP AVB Enabled
└── AOSP AVB Disabled
```

For lower-level development, `build-lowmem.sh vendorbootimage` can still be used when working on OrangeFox itself.

A final release must still be produced through the complete release workflow.

## 8. Release matrix

The supported release outputs are exactly:

```text
out/target/product/rodin/
├── OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-ENABLED.img
├── OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-DISABLED.img
├── OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-ENABLED.img
└── OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-DISABLED.img
```

Do not reintroduce market-region-specific HOS release files.

## 9. Fastbootd development

The working Fastbootd configuration depends on both:

- rodin recovery USB ConfigFS ownership
- non-blocking optional HAL/service lookup patches

Do not replace the proven USB recovery configuration or add competing ConfigFS owners without device evidence.

When testing Fastbootd, verify:

```bash
fastboot getvar is-userspace
fastboot getvar product
fastboot getvar current-slot
```

Expected userspace state:

```text
is-userspace: yes
product: rodin
```

## 10. Recovery module development

OrangeFox retains a small rodin-specific recovery module set for touch, haptics and related device functionality.

The unified HOS PLATFORM exposes these modules through both supported kernel-release module directories.

If changing recovery modules or module metadata, verify:

- module dependency resolution
- first-stage recovery load list
- touch
- haptics
- storage
- both supported HOS kernel families

Do not assume a module change is cross-kernel compatible without runtime evidence.

## 11. Runtime validation

At minimum, recovery changes should be checked for:

- OrangeFox boot
- ADB
- touch
- haptics
- userdata mapping
- FBE decryption when relevant
- MTP
- Fastbootd
- slot reporting
- USB OTG when USB/DT behavior changes

Changes touching the unified HOS PLATFORM require testing against both the 6.6.77 and 6.6.89 kernel families.

## 12. ROM-install preservation

Rodin recovery preservation during ROM installation is part of the verified recovery flow.

Changes to installer handling, vendor_boot repacking or recovery preservation must not overwrite the PLATFORM fragment with a recovery-only image.

The final result must remain a system-compatible vendor_boot.

## 13. Patch maintenance

When an external-source change is intentionally updated:

1. update the source implementation,
2. regenerate the corresponding canonical patch,
3. update its SHA-256 verification,
4. run `git diff --check`,
5. run the complete preflight verifier,
6. rebuild the release matrix,
7. perform relevant runtime tests,
8. document the new verified baseline.

Avoid accumulating undocumented local edits outside the canonical patch workflow.

---

[Back to documentation](README.md)
