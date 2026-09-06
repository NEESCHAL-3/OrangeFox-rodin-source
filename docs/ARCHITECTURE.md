# Rodin OrangeFox Architecture

[Repository](../README.md) / [Documentation](README.md)

This document describes the final recovery and `vendor_boot` architecture used by OrangeFox on Xiaomi `rodin`.

<details>
<summary>On this page</summary>

- [1. Recovery location](#1-recovery-location)
- [2. Vendor ramdisk layout](#2-vendor-ramdisk-layout)
- [3. Unified HOS PLATFORM](#3-unified-hos-platform)
- [4. Automatic module selection](#4-automatic-module-selection)
- [5. Historical Global and India equivalence](#5-historical-global-and-india-equivalence)
- [6. 6.6.77 stock-baseline relationship](#6-667-stock-baseline-relationship)
- [7. OrangeFox device modules](#7-orangefox-device-modules)
- [8. Compression](#8-compression)
- [9. Recovery DTB](#9-recovery-dtb)
- [10. Fastbootd](#10-fastbootd)
- [11. AVB variants](#11-avb-variants)
- [12. AOSP architecture](#12-aosp-architecture)
- [13. Build flow](#13-build-flow)
- [14. Runtime validation](#14-runtime-validation)

</details>

## 1. Recovery location

Rodin has no standalone recovery partition.

Recovery is carried inside the slot-specific `vendor_boot` partition:

- `vendor_boot_a`
- `vendor_boot_b`

The image uses vendor boot header version 4.

## 2. Vendor ramdisk layout

The final HOS/OEM-port `vendor_boot` contains two vendor ramdisk fragments:

- type 1: PLATFORM
- type 2: RECOVERY

The PLATFORM fragment supplies the first-stage Android environment required by both normal boot and recovery boot.

The RECOVERY fragment contains OrangeFox.

Conceptually:

```text
vendor_boot
├── PLATFORM
│   ├── first-stage init
│   ├── fstab
│   ├── SELinux/runtime files
│   ├── firmware
│   └── kernel modules
└── RECOVERY
    └── OrangeFox
```

A recovery-only `vendor_boot` image is not suitable for normal Android boot on rodin.

## 3. Unified HOS PLATFORM

HOS/OEM-port recovery uses one pinned unified PLATFORM:

`prebuilt/unified/vendor_ramdisk00`

SHA-256:

`dda9762619ee1cbe3019735103ddd25c62ebd9d2431e991303d5855520d93389`

The PLATFORM uses Zstandard compression.

It contains two complete kernel-module trees:

```text
/lib/modules/
├── 6.6.77-android15-8-gca30f3b4bef6-abogki440974771-4k/
└── 6.6.89-android15-8-g8e4be6b47e40-ab14134548-4k/
```

The 6.6.77 tree is a proven Rodin stock module baseline.

The 6.6.89 tree is a proven Rodin stock module baseline.

There is no build-time firmware-region selector.

## 4. GKI/KMI compatibility and module loading

The 6.6.77 and 6.6.89 module payloads retained in the unified PLATFORM are proven stock baselines, not an exact kernel-version whitelist.

Rodin HOS/OEM-port recovery follows the Android15-6.6 GKI/KMI model. Compatible 6.6.x GKI kernels do not need to match one of those stored patchlevels exactly when the required KMI/vendor ABI remains compatible.

Runtime validation has confirmed OrangeFox on:

- stock `6.6.77-android15-8-gca30f3b4bef6-abogki440974771-4k`
- stock `6.6.89-android15-8-g8e4be6b47e40-ab14134548-4k`
- stock EEA `6.6.118-android15-8-ge56cf6b09cca-ab15511674-4k`
- custom `6.6.142-EVONIX-COS-V3.5`

The stock 6.6.118 recovery session loaded 551 modules. The custom 6.6.142 session loaded 247 modules, including Rodin touch, haptics and SCP modules.

Module sources and mount visibility can differ between recovery environments, so compatibility does not depend on one `/lib/modules/<uname -r>` path or one `vendor_dlkm` mount state.

No firmware-region selector is required.

## 5. Historical Global and India equivalence

The stock Global/MIXM and India PLATFORM ramdisks were compared directly.

Their complete file layouts match.

Their 244-module payloads are identical and use the same 6.6.89 module ABI.

The observed differences outside the module payload were limited to regional/build-property data and `system/etc/copylib.txt`.

That comparison established one common 6.6.89 stock module payload. It is retained as a proven baseline and is not an exact running-kernel patchlevel requirement.

## 6. 6.6.77 stock-baseline relationship

The retained Rodin 6.6.77 stock baseline carries a module payload distinct from the 6.6.89 stock baseline.

Its complete stock module set is retained independently in the unified PLATFORM.

The two kernel-family module trees remain independent; modules are never mixed across ABI trees at runtime.

## 7. OrangeFox device modules

OrangeFox retains its rodin-specific recovery modules, including the touch, haptics and secure-element related modules needed by recovery.

The proven device-specific recovery modules are retained with the stock baseline payloads. Runtime compatibility is not tied to an exact kernel-directory-name match.

The same recovery module set was runtime-tested successfully under both supported kernel families.

## 8. Compression

The final HOS layout uses:

| Ramdisk fragment | Compression |
| --- | --- |
| PLATFORM | Zstandard |
| RECOVERY | LZ4 |

Both verified rodin kernel families support Zstandard initramfs decompression.

The unified design was introduced because carrying both complete regional module sets with the previous LZ4 PLATFORM exceeded the practical `vendor_boot` size budget.

Zstandard provides enough space to retain both complete module sets without stripping module metadata or pruning stock kernel modules.

## 9. Recovery DTB

The final image uses the pinned rodin DTB as the build input.

During packaging, `tools/make-recovery-host-dtb.py` creates the recovery-host DTB used by the final `vendor_boot`.

The recovery-specific DTB transformation removes only the targeted USB offload property required for the working recovery USB/OTG behavior.

Fastbootd does not rely on additional DT replacement hacks.

## 10. Fastbootd

Rodin Fastbootd uses the recovery USB ConfigFS setup together with two external-source fixes:

- non-blocking BootControl service lookup in `hardware/interfaces`
- non-blocking optional HAL lookup in `system/core/fastbootd`

These prevent Fastbootd from blocking indefinitely when optional services are unavailable in recovery.

Runtime verification confirmed:

```text
is-userspace: yes
product: rodin
```

under both supported HOS kernel families.

## 11. AVB variants

The HOS AVB Enabled image uses the pinned unified PLATFORM unchanged.

The HOS AVB Disabled image is derived from that same PLATFORM during packaging.

Only the first-stage `avb` and `avb_keys` fstab flags are removed.

The pinned unified PLATFORM stored in the source tree remains AVB-enabled and immutable.

## 12. AOSP architecture

AOSP remains a separate profile.

It uses:

- `prebuilt/aosp/vendor_ramdisk00`
- `prebuilt/aosp/bootconfig`

The AOSP builder does not use the unified HOS PLATFORM and remains a separate vendor/recovery environment.

This separation is intentional because the AOSP vendor environment differs from the OEM/HOS environment.

## 13. Build flow

The public release entrypoint is:

```bash
./build-release.sh
```

The flow is:

```text
Apply canonical external patches
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

The default `vendor_boot.img` is restored to the unified HOS AVB Enabled image after all release variants are generated.

## 14. Runtime validation

The unified HOS architecture has been boot-tested with:

- Rodin 6.6.77 kernel
- Rodin 6.6.89 kernel

The same unified `vendor_boot` successfully provided:

- the correct kernel-family stock module tree
- OrangeFox device modules
- touch
- haptics
- userdata block mapping
- recovery boot
- Fastbootd

This runtime behavior is the compatibility baseline for the unified HOS design.

---

[Back to documentation](README.md)
