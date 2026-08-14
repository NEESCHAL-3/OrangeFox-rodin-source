# OrangeFox Recovery for Xiaomi rodin

Private, runtime-verified OrangeFox Recovery source for Xiaomi **rodin**.

> **Devices:** POCO X7 Pro / Redmi Turbo 4
> **Build profile:** India
> **Recovery layout:** A/B `vendor_boot`
> **Maintainer:** NEESCHAL

## Status

| Area | Status |
|---|---|
| Recovery boot | Verified |
| Touch | Verified |
| FBE / decryption | Verified |
| MTP | Verified |
| Fastbootd | Verified |
| A/B preservation | Verified |
| Format Data | Verified |
| USB OTG | Verified |
| Legacy Edify fallback | Verified |
| System-compatible `vendor_boot` | Verified |

## Engineering highlights

- deterministic Fastbootd USB handling
- UFS boot-LUN switching through BSG
- A/B recovery preservation and Format Data fixes
- recovery UI, input and font improvements
- ARM64 fallback updater for legacy ARM32 Edify installers
- legacy `applypatch` / `blockimg` compatibility
- touch and FBE recovery integration
- runtime OTG DTB patching during recovery auto-reflash
- system-compatible `vendor_boot` generation
- verified India platform ramdisk integration

## Verified firmware input

`prebuilt/india/vendor_ramdisk00`

SHA-256:

```text
c1b5ad776c93f89c6bf227ffecbf21ff3338236833d424446b388bb9819587a6
```

This repository intentionally maintains the **India firmware profile only**.

## Build

From the OrangeFox source root:

```bash
export RODIN_FIRMWARE_VARIANT=india
device/xiaomi/rodin/build-lowmem.sh vendorbootimage
```

See [BUILDING.md](BUILDING.md) for the complete procedure.

## Repository map

- `recovery/` — recovery ramdisk and device integration
- `prebuilt/` — kernel, DTB, DTBO and India platform ramdisk
- `proprietary/` — required recovery-side binaries
- `tools/` — verification and `vendor_boot` tooling
- `patches/bootable-recovery/` — OrangeFox recovery patches
- `patches/build-make/` — Android build-system patches
- `manifests/` — reproducibility hashes
- `docs/` — technical documentation

## Integrity

Verify canonical patches:

```bash
sha256sum -c patches/SHA256SUMS
```

Device inputs are tracked in `manifests/device-blobs.sha256`.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Compatibility](docs/COMPATIBILITY.md)
- [USB / OTG](docs/USB-OTG.md)
- [Legacy Edify](docs/LEGACY-EDIFY.md)
- [Patch layout](docs/PATCHES.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## Development policy

Runtime changes must be validated on-device before promotion to the verified branch. Canonical patch files and binary inputs are checksum-tracked and should not be reformatted or replaced without intentional revalidation.

## Credits

Built on OrangeFox Recovery Project, Team Win Recovery Project, AOSP, and prior rodin recovery work by KSN2redawew and woshimaniubi8.

Current rodin integration, fixes and runtime validation: **NEESCHAL**.

See [CREDITS.md](CREDITS.md) and [NOTICE.md](NOTICE.md).
