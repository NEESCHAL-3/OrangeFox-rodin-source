# Troubleshooting

[Repository](../README.md) / [Documentation](README.md)

Diagnose build, boot, and recovery issues against the verified Xiaomi `rodin` baseline.

<details>
<summary>On this page</summary>

- [Do not flash the intermediate vendor_boot](#do-not-flash-the-intermediate-vendor_boot)
- [Build fails before compilation](#build-fails-before-compilation)
- [Source patch application fails](#source-patch-application-fails)
- [Wrong recovery profile](#wrong-recovery-profile)
- [Android or recovery does not boot after flashing](#android-or-recovery-does-not-boot-after-flashing)
- [Unified HOS kernel mismatch](#unified-hos-kernel-mismatch)
- [Fastbootd does not appear](#fastbootd-does-not-appear)
- [Touch problems](#touch-problems)
- [Haptics problems](#haptics-problems)
- [Storage or userdata problems](#storage-or-userdata-problems)
- [FBE decryption problems](#fbe-decryption-problems)
- [OTG disappears after installing a ROM](#otg-disappears-after-installing-a-rom)
- [Format Data after ROM installation](#format-data-after-rom-installation)
- [AVB Enabled vs Disabled](#avb-enabled-vs-disabled)
- [Build output size](#build-output-size)
- [Patch integrity](#patch-integrity)
- [Recovery logs](#recovery-logs)

</details>

## Do not flash the intermediate vendor_boot

Rodin recovery lives inside `vendor_boot`.

The Android build first produces an intermediate recovery-oriented image. The rodin post-build packaging step combines the required PLATFORM fragment with OrangeFox and creates the final system-compatible 64 MiB image.

Only flash the final release image.

Do not flash an intermediate recovery-only `vendor_boot`.

## Build fails before compilation

Run the verifier directly:

```bash
tools/verify-build-inputs.sh <orangefox-root>
```

The verifier checks:

- pinned source revisions
- intentionally patched repositories
- external patch hashes
- device blobs
- unified HOS PLATFORM hash
- required source markers
- helper-script syntax

Fix the reported mismatch instead of bypassing the verifier.

## Source patch application fails

Use:

```bash
tools/apply-orangefox-patches.sh
```

The helper supports an already-prepared development tree.

Expected behavior on an already-patched source is similar to:

```text
BootControl non-blocking lookup patch is already applied
fastbootd non-blocking HAL lookup patch is already applied
OrangeFox build/make patch is already applied
OrangeFox recovery patch is already applied (verified markers)
```

If a patch is neither applicable nor already represented by the verified source state, stop and inspect the source tree instead of forcing the patch.

## Wrong recovery profile

There is no India, Global, China, EEA, or other market-region HOS build selector. HOS/OEM-port recovery is region-agnostic.

For HyperOS/OEM-port environments use the unified HOS image.

For supported AOSP-based ROMs use the AOSP image.

The release matrix is:

```text
Release images
├── HOS / OEM-Port
│   ├── AVB Enabled
│   └── AVB Disabled
└── AOSP
    ├── AVB Enabled
    └── AVB Disabled
```

Do not use the HOS image merely because the physical device is rodin if the installed ROM uses the separate AOSP vendor environment.

## Android or recovery does not boot after flashing

First confirm that the correct profile was flashed:

- HOS/OEM-port ROM -> HOS image
- supported AOSP ROM -> AOSP image

Then confirm the intended AVB variant.

If the ROM requires first-stage AVB disabled, use the matching AVB Disabled image.

If the ROM uses its normal signed AVB configuration, prefer AVB Enabled.

Also confirm that only the intended slot was modified.

Useful commands:

```bash
fastboot getvar current-slot
fastboot getvar product
```

## Unified HOS kernel mismatch

The verified HOS kernel families are:

| Firmware family | Verified kernel release |
| --- | --- |
| 6.6.77 kernel family | `6.6.77-android15-8-gca30f3b4bef6-abogki440974771-4k` |
| 6.6.89 kernel family | `6.6.89-android15-8-g8e4be6b47e40-ab14134548-4k` |

The unified PLATFORM selects modules using the exact running kernel release; firmware market region is not part of selection.

If a substantially different kernel release is used, it may fall outside the verified module ABI baseline.

Check in recovery:

```bash
adb shell uname -r
```

## Fastbootd does not appear

From OrangeFox:

```bash
adb reboot fastboot
```

Then verify:

```bash
fastboot devices
fastboot getvar is-userspace
fastboot getvar product
fastboot getvar current-slot
```

Expected:

```text
is-userspace: yes
product: rodin
```

Rodin Fastbootd depends on the recovery USB ConfigFS setup and the non-blocking BootControl / optional-HAL lookup fixes.

Do not reintroduce competing ConfigFS ownership or remove the Fastbootd source patches without device evidence.

## Touch problems

Check that the rodin-specific touch modules loaded:

```bash
adb shell "cat /proc/modules | grep -E 'goodix|focal|xiaomi_touch|scp'"
```

The unified HOS PLATFORM makes the OrangeFox device modules available in both supported kernel-release module directories.

If touch fails after changing modules or metadata, verify the exact running kernel, module dependency metadata and `modules.load.recovery`.

## Haptics problems

Check:

```bash
adb shell "cat /proc/modules | grep si_haptic"
```

If `si_haptic` is not loaded, inspect the recovery module tree and the haptics loader before changing unrelated vibration framework files.

## Storage or userdata problems

Confirm the userdata block mapping:

```bash
adb shell ls -l /dev/block/by-name/userdata
```

Also check mounted filesystems and recovery logs.

Do not modify or format `/metadata` automatically while debugging a storage issue.

## FBE decryption problems

Collect:

```bash
adb shell getprop
adb shell mount
adb shell dmesg
```

and the OrangeFox recovery log.

Do not assume every decryption failure is caused by the unified PLATFORM; confirm the installed ROM, encryption state and key-management services first.

## OTG disappears after installing a ROM

Rodin recovery uses a recovery-host DTB transformation for the working USB/OTG configuration.

The final builder removes only the targeted MediaTek USB offload property from the recovery-host DTB.

If OTG disappears after a ROM install, confirm that OrangeFox recovery preservation restored the final system-compatible vendor_boot rather than a recovery-only intermediate image.

## Format Data after ROM installation

Use the verified OrangeFox Format Data workflow.

Do not add automatic `/metadata` formatting as a workaround.

If Format Data behavior changes after recovery modifications, compare against the verified baseline before changing partition handling.

## AVB Enabled vs Disabled

HOS AVB Enabled uses the pinned unified PLATFORM unchanged.

HOS AVB Disabled is generated from the same PLATFORM by removing only first-stage `avb` and `avb_keys` fstab flags.

The pinned PLATFORM itself should never be overwritten with the disabled derivative.

If an AVB-enabled image bootloops on a ROM known to require AVB disabled, use the matching disabled image.

## Build output size

The rodin HOS builder rejects a combined vendor ramdisk size at or above:

`62000000 bytes`

The verified unified HOS packaging remains below this limit.

If the limit is exceeded after adding recovery content, reduce unnecessary recovery payload rather than deleting stock regional kernel modules from the unified PLATFORM.

## Patch integrity

Canonical external patches are verified by SHA-256.

If verification fails, compare the patch in the live device tree with the canonical repository copy.

Do not silently replace or edit a pinned patch without also updating its documented source baseline and verification hash.

## Recovery logs

Useful data when reporting a problem:

```bash
adb shell uname -r
adb shell cat /proc/modules
adb shell getprop
adb shell dmesg
adb shell ls -l /dev/block/by-name
```

Also include:

- flashed recovery profile
- AVB mode
- current slot
- installed ROM family
- exact kernel release

---

[Back to documentation](README.md)
