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

The HOS/OEM-port build is one region-agnostic image for supported Rodin firmware environments. There is no market-region build selector.

The unified HOS/OEM-port PLATFORM retains module payloads from the proven stock baselines:

- `6.6.77-android15-8-gca30f3b4bef6-abogki440974771-4k`
- `6.6.89-android15-8-g8e4be6b47e40-ab14134548-4k`

These are stock module baselines, not an exact kernel-version whitelist. Recovery compatibility follows the Android15-6.6 GKI/KMI contract and compatible vendor environment, so compatible later 6.6.x GKI patchlevels do not require an exact version match.

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

The AOSP profile does not use the unified HOS PLATFORM and remains a separate vendor/recovery environment.

## Build

From the OrangeFox 14.1 source root:

```bash
cd /path/to/fox_14.1
mkdir -p device/xiaomi
git clone https://github.com/NEESCHAL-3/OrangeFox-rodin-source.git device/xiaomi/rodin
cd device/xiaomi/rodin
./build-release.sh
```

For the normal in-tree workflow, no `ORANGEFOX_TOP`, `RODIN_TOP_DIR`, manual patching, or manual repacking is required.

The release script:

1. resolves the OrangeFox source root automatically,
2. applies or verifies the canonical rodin patch stack and proven OTA / Virtual A/B fixes,
3. verifies pinned source revisions and binary inputs,
4. creates a working-source freeze,
5. compiles OrangeFox once,
6. builds all four release variants and saves their SHA-256 hashes.

Outputs are written to `out/target/product/rodin/`:

```text
out/target/product/rodin/
├── OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-ENABLED.img
├── OrangeFox-R12.0-NEESCHAL-rodin-HOS-AVB-DISABLED.img
├── OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-ENABLED.img
├── OrangeFox-R12.0-NEESCHAL-rodin-AOSP-AVB-DISABLED.img
└── RODIN-ORANGEFOX-SHA256SUMS.txt
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

- stock Android15-6.6 GKI kernels, runtime-tested through 6.6.118
- compatible custom Android15-6.6 GKI kernels, runtime-tested with `6.6.142-EVONIX-COS-V3.5`

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

## Auto-DFE

OrangeFox includes an optional Auto-DFE backend for disabling forced encryption after ROM installation.

- Auto-DFE is OFF by default.
- It patches only the ROM target slot vendor_boot.
- It does not automatically format /data or /metadata.
- The first encrypted-to-unencrypted transition still requires Format Data once.
- vendor_boot v4 PLATFORM fragments are located through the ramdisk table rather than compression end-marker scanning.
- Legacy LZ4 and Zstd PLATFORM ramdisks are supported.
- Compression is detected from the PLATFORM fragment itself, independent of HOS or AOSP.
- Zstd PLATFORM ramdisks are decompressed and recompressed through libzstd.
- The rebuilt PLATFORM must fit inside the existing allocation.
- The real rebuilt PLATFORM size is written back into the vendor ramdisk table.
- RECOVERY, DTB and bootconfig remain at their existing offsets.
- Auto-DFE retains its backup, rollback and safe-failure behavior.

The unified HOS Zstd PLATFORM path has been verified with the Auto-DFE dry-run mechanism before enabling normal post-ROM operation.

<!-- RODIN-CURRENT-SOURCE-START -->

## Current source and build workflow

This repository contains the canonical OrangeFox source configuration for Xiaomi `rodin`.

### Build profiles

Four `vendor_boot` variants are generated:

| Profile | PLATFORM | AVB |
| --- | --- | --- |
| HOS / OEM-Port | Unified region-agnostic PLATFORM | Enabled |
| HOS / OEM-Port | Unified region-agnostic PLATFORM | Disabled |
| AOSP | Dedicated AOSP PLATFORM | Enabled |
| AOSP | Dedicated AOSP PLATFORM | Disabled |

The HOS/OEM and AOSP PLATFORM layouts are intentionally different and must not be merged.

### Canonical source patches

The current build uses:

- `patches/bootable-recovery/rodin-complete.patch`
- `patches/build-make/rodin-complete.patch`
- `patches/system-update-engine/0001-update-engine-fix-rodin-ab-recovery-installation.patch`
- `patches/system-vold/0001-vold-restore-orangefox-decryption-support.patch`
- `patches/vendor-twrp/0001-twrp-fix-rodin-orangefox-build-configuration.patch`

Normal release builds apply the complete canonical patch stack automatically through `./build-release.sh`. Manual patch application is only needed for lower-level development and can be run with:

    ./tools/apply-orangefox-patches.sh

### Verify source and build inputs

Verification is also automatic during `./build-release.sh`. For manual development verification, run:

    ./tools/verify-build-inputs.sh

The verifier checks the pinned OrangeFox source state, canonical patch hashes,
device blobs, kernel, DTB/DTBO, HOS/AOSP PLATFORM inputs, and other required
build inputs.

### Build

Place this repository at:

    device/xiaomi/rodin

inside the OrangeFox 14.1 source tree.

From `device/xiaomi/rodin`, run:

    ./build-release.sh

This automatically applies the complete Rodin patch stack, verifies source and build inputs, builds OrangeFox, and generates all four HOS/AOSP × AVB Enabled/Disabled `vendor_boot` images.

For a constrained builder:

    ./build-lowmem.sh vendorbootimage

Final images are generated under:

    out/target/product/rodin/

### Included rodin recovery work

The current canonical source includes the rodin implementations and fixes for:

- A/B target-slot handling
- Auto Metadata
- Auto-Reflash
- target ROM PLATFORM preservation
- stock-recovery userspace sanitization
- vendor_boot size optimization and safety checks
- vendor_boot AVB descriptor refresh
- Auto-DFE / Disable Forced Encryption
- persistent DFE DTB/fstab carriers
- LZ4, Zstd, and nested PLATFORM handling
- Virtual A/B OTA workspace preparation
- `/metadata/ota/snapshots`
- `/metadata/gsi/ota`
- `/data/gsi/ota`
- update_engine recovery flashing
- recovery decryption
- EXT4/F2FS handling
- fastbootd
- USB/ADB/MTP
- legacy ARM32 Edify compatibility
- separate HOS/OEM-Port and AOSP recovery profiles

The maintainer theme asset is stored under `assets/theme/` and can be synced
with `tools/sync-neeschal-theme.sh`.

<!-- RODIN-CURRENT-SOURCE-END -->
