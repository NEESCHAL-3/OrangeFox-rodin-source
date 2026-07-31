# OrangeFox Recovery for rodin

## Final Development Milestone — 2026-07-31

Device:
- POCO X7 Pro / Redmi Turbo 4
- Codename: rodin

Final system-compatible image:
- `OrangeFox-R12.0-NEESCHAL-rodin-india-system-compatible.img`
- Size: `67108864` bytes
- SHA-256: `2c7cfc7416914cd6e3833eed461280514bae37d518dd4528c512c079547e1359`

Packed recovery binary:
- SHA-256: `883e1d0997315d66bdb8753a5f2f20d70339a67a55833c0b468d6fc340316372`

---

## Major fixes

### Safe A/B OrangeFox preservation

- Fixed OrangeFox reinstallation after flashing an A/B ROM.
- Recovery now checks the actual OTA target slot instead of the currently booted slot.
- Removed the broken hardcoded `/dev/block/bootdevice/by-name` path.
- Uses the real `/dev/block/by-name/vendor_boot_a` and `vendor_boot_b` paths.
- Preserves the target ROM's platform vendor ramdisk.
- Preserves the target ROM's DTB, bootconfig, cmdline, and vendor boot header.
- Replaces only the target recovery ramdisk fragment.
- Prevents copying an entire vendor_boot image from one slot to another.
- Restores temporary partition-manager slot overrides safely.
- Verified automatic OrangeFox injection from slot A into a newly installed ROM on slot B.
- Verified final image flashing completed with `operation_end - status=0`.

### Virtual A/B Format Data handling

- Fixed Format Data failure after installing a Virtual A/B ROM.
- Unmaps recovery-created logical partitions before SnapshotManager handles the pending update.
- Unmaps only logical partitions belonging to the currently booted slot.
- Removes matching COW devices only when present.
- Removed the unsafe generic sweep of every `/dev/block/mapper` device.
- Leaves target-slot snapshots and COW devices under SnapshotManager control.
- Uses normal recovery SnapshotManager initialization.
- Handles pending snapshot state and forward merge before formatting userdata.
- Fixed `Device or resource busy` failures caused by duplicate logical mappings.
- Verified pending Virtual A/B state completed successfully.

### Metadata-encrypted userdata formatting

- Fixed F2FS Format Data failure with:
  `Error: In use by the system!`
- Identified stale `/dev/block/mapper/userdata` metadata-encryption mapping.
- Added direct in-process `libdm` cleanup.
- Removes only the `userdata` device-mapper target.
- Does not depend on missing `dmctl` or `dmsetup` binaries.
- Verifies the mapper is gone before starting filesystem formatting.
- Avoids fixed sleeps and shell-based mapper deletion.
- Verified `make_f2fs` formatted the full userdata partition successfully.
- Verified filesystem checks completed successfully.
- Verified Format Data ended with `operation_end - status=0`.
- Verified the newly installed ROM booted successfully afterward.

### System-compatible vendor_boot image

- Added a rodin-specific system-compatible vendor_boot generation flow.
- Preserves the stock platform vendor ramdisk.
- Adds the OrangeFox recovery ramdisk as the recovery fragment.
- Preserves stock kernel modules required by the platform.
- Supports India firmware selection through:
  `RODIN_FIRMWARE_VARIANT=india`
- Produces a correctly padded 64 MiB vendor_boot image.

### USB OTG

- Fixed USB OTG by sanitizing only the problematic DTB property:
  `mediatek,usb-offload`
- Preserves the rest of the stock DTB unchanged.
- Verifies that the semantic DTB change is target-property-only.
- Physical USB OTG operation verified.

### Fastbootd

- Fixed fastbootd startup by making optional HAL lookups non-blocking.
- Corrected userspace fastboot USB configuration.
- Verified USB identity and userspace-fastboot operation.
- Kept unrelated BootControl behavior unchanged.

### BootControl

- Added correct rodin UFS boot-region handling.
- Uses `/dev/ufs-bsg0`.
- Maps slot A to boot LUN 1.
- Maps slot B to boot LUN 2.
- Preserves the combined BootControl wrapper result.
- Verified slot activation and slot reporting.

### APEX

- Fixed recovery APEX loading by seeking back to the start of the generated file before closing it.
- Verified runtime APEX loading through:
  `twrp.apex.loaded=true`

### mi_ext

- Added direct `/mi_ext` mounting support.
- Added paired EROFS and EXT4 fstab entries.
- Updated overlay paths to use `/mi_ext`.
- Avoided unstable loop or indirect mounting approaches.

### Ramdisk integrity

- Regenerates the runtime ramdisk file manifest after pruning, moving files, and UPX compression.
- Includes regular files, directories, and symbolic links.
- Excludes mutable runtime-generated files.
- Verified the final runtime manifest with:
  `manifest_rc=0`

### General recovery functionality

- Touchscreen working.
- User interface working.
- English language defaults working.
- ADB working.
- MTP working.
- Data decryption working.
- Android reboot targets working.
- Backup functions working.
- Startup vibration/module-loading order corrected.

---

## Final end-to-end validation

The following complete sequence was tested successfully:

1. Boot OrangeFox from slot A.
2. Flash Project Infinity through ADB sideload.
3. Install ROM payload to inactive slot B.
4. Detect target `vendor_boot_b` replacement.
5. Preserve the ROM platform vendor ramdisk.
6. Inject the newest OrangeFox recovery fragment into slot B.
7. Boot OrangeFox from slot B.
8. Confirm booted slot B, current slot 1, and active slot 1.
9. Handle pending Virtual A/B snapshot state.
10. Remove the stale metadata-encrypted userdata mapper.
11. Format userdata as F2FS.
12. Complete Format Data with status 0.
13. Boot the installed Android ROM successfully.

## Status

All critical recovery installation, A/B preservation, Virtual A/B Format Data,
userdata formatting, and Android boot paths are runtime-proven.
