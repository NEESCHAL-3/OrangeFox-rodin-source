# Compatibility

[Repository](../README.md) / [Documentation](README.md)

This source targets Xiaomi `rodin`.

<details>
<summary>On this page</summary>

- [Supported devices](#supported-devices)
- [Release profiles](#release-profiles)
- [Unified HOS / OEM-Port compatibility](#unified-hos--oem-port-compatibility)
- [6.6.77 kernel family](#667-kernel-family)
- [6.6.89 kernel family](#6689-kernel-family)
- [Historical Global / India equivalence](#historical-global--india-equivalence)
- [AOSP compatibility](#aosp-compatibility)
- [AVB Enabled](#avb-enabled)
- [AVB Disabled](#avb-disabled)
- [Verified recovery functionality](#verified-recovery-functionality)
- [Fastbootd](#fastbootd)
- [Flashing](#flashing)
- [Recovery image selection](#recovery-image-selection)
- [Support boundary](#support-boundary)

</details>

## Supported devices

- POCO X7 Pro
- Redmi Turbo 4

Both devices use the rodin A/B `vendor_boot` recovery layout.

There is no standalone recovery partition.

## Release profiles

The release build produces two recovery profiles:

| Profile | Intended ROM environment | Firmware model |
| --- | --- | --- |
| HOS / OEM-Port | HyperOS and compatible OEM-port ROMs | Region-agnostic unified PLATFORM |
| AOSP | Supported AOSP-based ROMs | Separate AOSP profile |

Each profile is available as:

- AVB Enabled
- AVB Disabled

This results in four release images total.

## Unified HOS / OEM-Port compatibility

There is one HOS/OEM-port `vendor_boot`.

There are no market-region-specific HOS release images.

The unified HOS PLATFORM contains two complete module trees.

| Firmware family | Verified kernel release |
| --- | --- |
| 6.6.77 kernel family | `6.6.77-android15-8-gca30f3b4bef6-abogki440974771-4k` |
| 6.6.89 kernel family | `6.6.89-android15-8-g8e4be6b47e40-ab14134548-4k` |

First-stage init automatically selects the module directory matching the running kernel.

No market-region build variable is required. Runtime selection follows the running kernel family.

## 6.6.77 kernel family

The unified PLATFORM supports the Rodin 6.6.77 kernel family.

The unified PLATFORM carries the complete matching 6.6.77 stock module set independently from the 6.6.89 module set.

The unified HOS image has been runtime-tested under the Rodin 6.6.77 kernel family.

Verified behavior includes:

- recovery boot
- correct stock module loading
- OrangeFox device module loading
- touch
- haptics
- userdata block mapping
- Fastbootd

## 6.6.89 kernel family

The unified PLATFORM supports the Rodin 6.6.89 kernel family.

The unified HOS image has been runtime-tested under the Rodin 6.6.89 kernel family.

Verified behavior includes:

- recovery boot
- correct 6.6.89 stock module loading
- OrangeFox device module loading
- touch
- haptics
- userdata block mapping
- Fastbootd

## Historical Global / India equivalence

India and Global/MIXM stock PLATFORM ramdisks were directly compared.

Their complete 244-module payloads are identical and use the same 6.6.89 module ABI.

That comparison proved those stock regional packages share the same 6.6.89 module payload. Runtime image selection remains kernel-based, not region-based.

## AOSP compatibility

AOSP remains a separate build profile.

It uses:

- `prebuilt/aosp/vendor_ramdisk00`
- `prebuilt/aosp/bootconfig`

The AOSP profile does not use the unified HOS PLATFORM.

The AOSP image should be used only for supported AOSP-based ROM environments.

Do not flash the HOS/OEM-port profile merely because the device itself is rodin; the installed ROM environment matters.

## AVB Enabled

Use the AVB Enabled image when the installed ROM uses its normal signed AVB configuration.

This is the default HOS release output.

## AVB Disabled

Use the AVB Disabled image when the ROM or installation explicitly requires first-stage AVB flags to remain disabled.

The disabled HOS image is generated from the same unified PLATFORM with only first-stage `avb` and `avb_keys` fstab flags removed.

If an AVB Enabled image causes a bootloop on a ROM that requires AVB disabled, use the matching AVB Disabled profile instead.

## Verified recovery functionality

The current source has been validated for:

- OrangeFox boot
- touch input
- haptics
- MTP
- ADB
- FBE user-data decryption
- Fastbootd
- A/B slot switching
- ROM-install recovery preservation
- Format Data workflow
- USB OTG preservation
- legacy ARM32 Edify installer fallback through the ARM64 updater path

## Fastbootd

Fastbootd has been runtime-tested under both verified HOS kernel families.

Expected userspace Fastboot output includes:

```text
is-userspace: yes
product: rodin
```

The Fastbootd implementation includes the rodin non-blocking BootControl and optional-HAL lookup fixes.

## Flashing

Only flash the final 64 MiB `vendor_boot` image produced by the rodin build flow.

Valid partitions are:

```text
vendor_boot_a
vendor_boot_b
```

Do not use `vendor_boot_ab`.

For testing, flash only the intended slot unless modifying both slots is explicitly required.

## Recovery image selection

For OEM/HOS environments choose one of:

```text
OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-ENABLED.img
OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-DISABLED.img
```

For supported AOSP environments choose one of:

```text
OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-ENABLED.img
OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-DISABLED.img
```

There are no market-region-specific HOS release images.

## Support boundary

Compatibility claims are based on the verified Rodin kernel and vendor environments described above. Market-region labels do not select the recovery image.

Unrelated vendor environments, different kernel ABIs or substantially modified vendor boot layouts are outside the verified compatibility baseline.

---

[Back to documentation](README.md)
