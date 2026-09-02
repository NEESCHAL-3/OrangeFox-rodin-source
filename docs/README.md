# Developer Documentation

Documentation for OrangeFox Recovery on Xiaomi `rodin`.

## Start here

- [Building](../BUILDING.md) — complete public build workflow
- [Architecture](ARCHITECTURE.md) — vendor_boot and recovery architecture
- [Unified HOS](UNIFIED-HOS.md) — CN + Global/MIXM + India unified PLATFORM design
- [Compatibility](COMPATIBILITY.md) — HOS/AOSP profiles and verified firmware families
- [Development](DEVELOPMENT.md) — contributor workflow
- [Verified Baseline](VERIFIED-BASELINE.md) — pinned hashes and runtime-tested state
- [External Patches](PATCHES.md) — recovery, build/make and Fastbootd source patches
- [Troubleshooting](TROUBLESHOOTING.md) — build and runtime debugging
- [USB OTG](USB-OTG.md) — rodin recovery USB/OTG handling
- [Legacy Edify](LEGACY-EDIFY.md) — ARM32 installer compatibility

## Release model

The current release matrix contains four images:

- unified HOS / OEM-Port — AVB Enabled
- unified HOS / OEM-Port — AVB Disabled
- AOSP — AVB Enabled
- AOSP — AVB Disabled

HOS uses one unified PLATFORM for supported CN, Global/MIXM and India firmware.

AOSP remains a separate profile.

## Build entrypoint

From `device/xiaomi/rodin` run:

`./build-release.sh`

The release workflow applies canonical external patches, verifies pinned inputs, compiles OrangeFox and generates all four release images.

## Verified HOS kernel families

CN:

`6.6.77-android15-8-gca30f3b4bef6-abogki440974771-4k`

Global/MIXM and India:

`6.6.89-android15-8-g8e4be6b47e40-ab14134548-4k`

See [Unified HOS](UNIFIED-HOS.md) for details.
