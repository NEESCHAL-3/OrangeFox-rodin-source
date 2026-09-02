# OrangeFox Recovery for Xiaomi rodin

Device tree and build support for OrangeFox Recovery on Xiaomi `rodin`.

Supported devices:

- POCO X7 Pro
- Redmi Turbo 4

Rodin uses an A/B `vendor_boot` recovery layout with dynamic partitions and Virtual A/B. There is no standalone recovery partition.

## Release profiles

This source produces four release images:

- HOS / OEM-Port — AVB Enabled
- HOS / OEM-Port — AVB Disabled
- AOSP — AVB Enabled
- AOSP — AVB Disabled

### Unified HOS / OEM-Port

The HOS build is one universal image for supported CN, Global/MIXM and India firmware.

The unified PLATFORM contains separate kernel-module trees for:

- CN: `6.6.77-android15-8-gca30f3b4bef6-abogki440974771-4k`
- Global/MIXM and India: `6.6.89-android15-8-g8e4be6b47e40-ab14134548-4k`

Android first-stage init selects the matching `/lib/modules/<kernel-release>` directory from the running kernel. There is no firmware-region build selector.

The pinned unified HOS PLATFORM is:

`prebuilt/unified/vendor_ramdisk00`

SHA-256:

`dda9762619ee1cbe3019735103ddd25c62ebd9d2431e991303d5855520d93389`

### AOSP

AOSP remains a separate profile because its PLATFORM ramdisk and bootconfig differ from the OEM/HOS environment.

AOSP uses:

- `prebuilt/aosp/vendor_ramdisk00`
- `prebuilt/aosp/bootconfig`

The AOSP profile does not use the CN HOS module tree.

## Build

Clone this repository into an OrangeFox 14.1 source tree as:

`device/xiaomi/rodin`

Then build from the device-tree directory:

```bash
./build-release.sh
```

The release script:

1. applies the canonical rodin external-source patches,
2. verifies pinned source revisions and binary inputs,
3. compiles OrangeFox,
4. builds all four release variants.

Outputs are written to `out/target/product/rodin/`:

```text
out/target/product/rodin/
├── OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-ENABLED.img
├── OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-DISABLED.img
├── OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-ENABLED.img
└── OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-DISABLED.img
```

`vendor_boot.img` defaults to the unified HOS AVB-enabled image.

See [BUILDING.md](BUILDING.md) for the complete source setup and build procedure.

## AVB variants

Use AVB Enabled when the installed ROM uses its normal signed AVB configuration.

Use AVB Disabled when the ROM or installation requires first-stage AVB flags to remain disabled.

The HOS AVB Disabled image is generated from the same unified PLATFORM by removing only the first-stage `avb` / `avb_keys` fstab flags before repacking.

## Flashing

Flash the final 64 MiB image to the intended slot, for example:

```bash
fastboot flash vendor_boot_a <image>.img
fastboot reboot recovery
```

Valid partition names are:

- `vendor_boot_a`
- `vendor_boot_b`

Do not use `vendor_boot_ab`.

Do not flash an intermediate recovery-only `vendor_boot` created before the rodin post-build packaging step.

## Verified functionality

The current source has been validated for:

- OrangeFox boot
- touch input
- haptics
- MTP and ADB
- FBE user-data decryption
- Fastbootd
- A/B slot switching
- ROM-install recovery preservation
- Format Data workflow
- USB OTG preservation
- legacy ARM32 Edify installer fallback through the ARM64 updater path

The unified HOS architecture has been runtime-tested with both:

- CN 6.6.77 kernel family
- Global 6.6.89 kernel family

The same unified HOS `vendor_boot` successfully loaded the correct stock module set, OrangeFox device modules, userdata mapping and Fastbootd on both kernel families.

## Documentation

Developer documentation is under [`docs/`](docs/README.md).

Key references:

- [Building](BUILDING.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Unified HOS design](docs/UNIFIED-HOS.md)
- [Compatibility](docs/COMPATIBILITY.md)
- [Development workflow](docs/DEVELOPMENT.md)
- [Verified baseline](docs/VERIFIED-BASELINE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [External patches](docs/PATCHES.md)

## Source integrity

The build workflow verifies:

- the pinned OrangeFox source manifest,
- intentionally patched external repositories,
- canonical patch SHA-256 values,
- pinned device binary inputs,
- the unified HOS PLATFORM SHA-256,
- required rodin build and runtime markers.

Build verification must pass before release images are distributed.
