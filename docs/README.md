# OrangeFox Rodin Documentation

[Repository](../README.md) / Documentation

Build, understand, validate, and troubleshoot OrangeFox Recovery for Xiaomi `rodin` (POCO X7 Pro / Redmi Turbo 4).

## Start here

| Task | Guide |
| --- | --- |
| Check the supported ROM profiles and kernel families | [Compatibility](COMPATIBILITY.md) |
| Set up the source tree and build release images | [Building](../BUILDING.md) |
| Understand the recovery and `vendor_boot` layout | [Architecture](ARCHITECTURE.md) |
| Diagnose a build, boot, or recovery issue | [Troubleshooting](TROUBLESHOOTING.md) |

## Documentation tree

```text
docs/
├── README.md
├── ARCHITECTURE.md
├── COMPATIBILITY.md
├── DEVELOPMENT.md
├── LEGACY-EDIFY.md
├── PATCHES.md
├── RODIN_RECOVERY_OTA_PROVEN_2026-09-06.md
├── TROUBLESHOOTING.md
├── UNIFIED-HOS.md
├── USB-OTG.md
└── VERIFIED-BASELINE.md
```

The [build guide](../BUILDING.md) and [contribution guidelines](../CONTRIBUTING.md) live at the repository root.

## Guides by topic

### Architecture and compatibility

| Guide | Scope |
| --- | --- |
| [Architecture](ARCHITECTURE.md) | Recovery placement, vendor ramdisks, module loading, and build flow |
| [Unified HOS / OEM-Port](UNIFIED-HOS.md) | Region-agnostic unified PLATFORM and runtime kernel-family selection |
| [Compatibility](COMPATIBILITY.md) | HOS/AOSP profiles, AVB variants, and verified firmware families |

### Development and validation

| Guide | Scope |
| --- | --- |
| [Building](../BUILDING.md) | Complete source setup and release build workflow |
| [Development workflow](DEVELOPMENT.md) | Contributor workflow, PLATFORM maintenance, and runtime validation |
| [External source patches](PATCHES.md) | Recovery, build/make, Fastbootd, and proven OTA/Virtual A/B patches |
| [Proven recovery OTA](RODIN_RECOVERY_OTA_PROVEN_2026-09-06.md) | End-to-end ADB sideload, update_engine, snapshot/COW, and target-slot boot validation |
| [Verified runtime baseline](VERIFIED-BASELINE.md) | Pinned revisions, SHA-256 values, and runtime-tested state |

### Recovery behavior and troubleshooting

| Guide | Scope |
| --- | --- |
| [Troubleshooting](TROUBLESHOOTING.md) | Build, boot, storage, USB, and recovery diagnostics |
| [USB OTG](USB-OTG.md) | Recovery USB/OTG handling and automatic preservation |
| [Legacy Edify](LEGACY-EDIFY.md) | Legacy ARM32 installer compatibility through the ARM64 updater |

## Release model

The release matrix contains four images:

| Profile | AVB Enabled | AVB Disabled |
| --- | --- | --- |
| Unified HOS / OEM-Port | Available | Available |
| AOSP | Available | Available |

HOS/OEM-port uses one region-agnostic unified PLATFORM. Runtime module selection follows the running kernel family; AOSP remains a separate profile.

## Build entrypoint

From `device/xiaomi/rodin`, run:

```bash
./build-release.sh
```

The release workflow applies canonical external patches, verifies pinned inputs, compiles OrangeFox, and generates all four release images. See [Building](../BUILDING.md) for the complete workflow.

## Verified HOS kernel families

| Firmware family | Verified kernel release |
| --- | --- |
| 6.6.77 family | `6.6.77-android15-8-gca30f3b4bef6-abogki440974771-4k` |
| 6.6.89 family | `6.6.89-android15-8-g8e4be6b47e40-ab14134548-4k` |

See [Unified HOS](UNIFIED-HOS.md) for module selection details and [Verified Runtime Baseline](VERIFIED-BASELINE.md) for pinned inputs and validation results.
