# OrangeFox Recovery for Rodin

## R12.0 — Unofficial Stable

**Release date:** 2026-08-07  
**Device:** POCO X7 Pro / Redmi Turbo 4  
**Codename:** rodin  
**Base firmware:** OS3.0.301.0.WOJINXM  
**Release channel:** Unofficial Stable  

## Release image

`OrangeFox-R12.0-Rodin-UNOFFICIAL-STABLE-20260807.img`

SHA-256:

`fa4c59e0f3713b42aa20d6316243fc1dd629e8899d461160411d52c4c2ff124e`

Size:

`67108864 bytes`

## Changelog (2026-08-07)

### Legacy ARM32 Edify & ZIP compatibility
- Added support for legacy ARM32 Edify ZIP installers on ARM64 recovery.
- Added ARM64 fallback updater at `/system/bin/updater`.
- Added legacy Edify compatibility for `delete`, `delete_recursive`, `package_extract_dir`, `symlink`, `set_perm`, `set_perm_recursive`, `set_metadata`, and `set_metadata_recursive`.
- Fixed old ZIPs failing with "unknown function set_perm".
- Fixed legacy ARM32 ZIPs failing because the recovery updater was missing.
- Added automatic ARM32 update-binary detection with fallback to the built-in ARM64 updater.

### USB OTG
- Fixed USB OTG not working after flashing a ROM.
- Fixed OTG being lost after OrangeFox automatically reinstalls itself.

## Major fixes

### Safe A/B recovery preservation

- Fixed OrangeFox preservation after installing A/B ROMs.
- Detects the actual OTA target slot.
- Replaces only the recovery ramdisk fragment.
- Preserves the target ROM platform vendor ramdisk.
- Preserves the target ROM DTB, bootconfig, cmdline and vendor boot header.
- Removed unsafe whole-image copying between slots.
- Fixed hardcoded and invalid vendor_boot block-device paths.
- Verified automatic OrangeFox injection from slot A into slot B.
- Verified target vendor_boot flashing with status 0.

### Virtual A/B Format Data

- Fixed Format Data after installing Virtual A/B ROMs.
- Unmaps recovery-created logical partitions before snapshot handling.
- Unmaps only partitions belonging to the booted slot.
- Leaves OTA target snapshots under SnapshotManager control.
- Safely handles matching COW devices.
- Removed the unsafe generic `/dev/block/mapper` sweep.
- Fixed duplicate logical mapping and resource-busy failures.
- Verified pending Virtual A/B state handling successfully.

### Metadata-encrypted userdata

- Fixed F2FS formatting failure:
  `Error: In use by the system!`
- Detects the stale `/dev/block/mapper/userdata` mapping.
- Removes the userdata mapper using the direct libdm API.
- Does not depend on dmctl or dmsetup binaries.
- Verifies mapper deletion before formatting.
- Does not use fixed delays.
- Verified successful F2FS formatting and filesystem checks.
- Verified Format Data completed with status 0.
- Verified Android boot after formatting.

### System-compatible vendor_boot

- Added a rodin-specific vendor_boot generation flow.
- Preserves the stock platform vendor ramdisk.
- Adds OrangeFox as the recovery ramdisk fragment.
- Preserves required stock kernel modules.
- Supports firmware-specific vendor_boot build inputs.
- Produces a correctly padded 64 MiB image.

### USB OTG

- Fixed physical USB OTG support.
- Removes only the problematic `mediatek,usb-offload` DTB property.
- Preserves all unrelated DTB contents.
- Verifies that the semantic DTB change is target-property-only.

### Fastbootd and BootControl

- Fixed userspace fastboot startup.
- Made optional HAL lookups non-blocking.
- Corrected the userspace fastboot USB configuration.
- Added rodin UFS boot-region support through `/dev/ufs-bsg0`.
- Correctly maps slot A to Boot LUN 1 and slot B to Boot LUN 2.
- Verified slot activation and reporting.

### Decryption and storage

- Improved FBE and metadata-encryption handling.
- Improved keystore and Weaver compatibility.
- Added direct `/mi_ext` mounting.
- Added paired EROFS and EXT4 mi_ext fstab entries.
- MTP and ADB verified.
- Data decryption verified.
- Backup functionality verified.

### Recovery runtime

- Fixed recovery APEX loading.
- Regenerates the runtime ramdisk integrity manifest after build processing.
- Supports regular files, directories and symbolic links.
- Excludes mutable runtime files.
- Runtime manifest verified with `manifest_rc=0`.
- Improved touch input, graphics and TrueType font rendering.
- Fixed startup vibration module-loading order.

## End-to-end validation

The complete installation flow was tested successfully:

1. Boot OrangeFox from slot A.
2. Install Project Infinity through ADB sideload.
3. Write the ROM payload to inactive slot B.
4. Detect the newly written target vendor_boot.
5. Preserve the ROM platform vendor ramdisk.
6. Inject OrangeFox into the target recovery fragment.
7. Boot OrangeFox from slot B.
8. Handle the pending Virtual A/B snapshot state.
9. Remove the userdata metadata-encryption mapper.
10. Format userdata successfully as F2FS.
11. Complete Format Data with status 0.
12. Boot Android successfully.

## Expected Format Data message

On FBE ROMs, OrangeFox may display:

`OrangeFox will not recreate /data/media on an FBE device.`

This is expected. Android creates the fresh encrypted data and internal-storage structure during the first system boot.

## Credits and Acknowledgments

- **[woshimaniubi8](https://github.com/woshimaniubi8):** Source tree references, base recovery components, and USB OTG DTB fix implementation.
- **OrangeFox Recovery Project:** Core recovery project and UI framework.
