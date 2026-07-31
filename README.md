# OrangeFox Recovery for POCO X7 Pro / Redmi Turbo 4 (rodin)

Official release documentation and binary distribution for OrangeFox Recovery R12.0 Unofficial Stable on the POCO X7 Pro / Redmi Turbo 4 (`rodin`).

---

## Build Information

- **Device:** POCO X7 Pro / Redmi Turbo 4
- **Codename:** rodin
- **Release Version:** R12.0
- **Release Channel:** Unofficial Stable
- **Build Date:** 2026-07-31
- **Base Firmware:** OS3.0.301.0.WOJINXM
- **Image File:** `OrangeFox-R12.0-Rodin-UNOFFICIAL-STABLE-20260731.img`
- **Image Size:** 67,108,864 bytes (64 MiB)
- **SHA-256 Checksum:** `2c7cfc7416914cd6e3833eed461280514bae37d518dd4528c512c079547e1359`

---

## Key Features and Technical Highlights

### Safe A/B Recovery Preservation
- Resolves recovery loss after OTA or system ROM updates on A/B partitioned layouts.
- Identifies active and target OTA slots dynamically.
- Replaces only the recovery ramdisk fragment within target `vendor_boot`.
- Preserves target ROM platform vendor ramdisk, DTB, bootconfig, cmdline, and kernel header.

### Virtual A/B Format Data Compatibility
- Unmaps recovery-created logical device-mapper partitions prior to snapshot handling.
- Targets active slot partitions exclusively, leaving target OTA snapshots under `SnapshotManager` control.
- Prevents resource-busy errors and duplicate mapping collisions.

### Metadata-Encrypted Userdata Handling
- Resolves F2FS format errors caused by stale mapper references (`Error: In use by the system!`).
- Direct integration with `libdm` API to remove `/dev/block/mapper/userdata` without reliance on external binaries.
- Ensures clean format sequence and filesystem creation.

### Hardware & Subsystem Compatibility
- **USB OTG:** Corrected DTB property parsing for USB host mode stability.
- **Fastbootd & BootControl:** Implemented UFS boot-region mapping via `/dev/ufs-bsg0` (Boot LUN 1 to slot A, Boot LUN 2 to slot B).
- **Storage & Decryption:** Verified FBE, keystore compatibility, and direct `/mi_ext` mounting.

---

## Installation Guide

### Prerequisites
- Unlocked bootloader on POCO X7 Pro / Redmi Turbo 4 (`rodin`).
- Android SDK Platform-Tools (`fastboot` and `adb`) installed.

### Flashing via Fastboot

1. Reboot the device into Fastboot mode:
   ```bash
   adb reboot bootloader
   ```

2. Flash the recovery image to the `vendor_boot` partition:
   ```bash
   fastboot flash vendor_boot OrangeFox-R12.0-Rodin-UNOFFICIAL-STABLE-20260731.img
   ```

3. Reboot into recovery mode:
   ```bash
   fastboot reboot recovery
   ```

---

## Integrity Verification

Verify the integrity of downloaded release files using SHA-256:

```bash
sha256sum -c SHA256SUMS
```

Expected output:
```text
OrangeFox-R12.0-Rodin-UNOFFICIAL-STABLE-20260731.img: OK
```

---

## Credits and Acknowledgments

- **[woshimaniubi8](https://github.com/woshimaniubi8):** Special thanks for source tree references, base recovery components, and the USB OTG DTB fix implementation.
- **OrangeFox Recovery Project:** Core recovery environment and UI framework.
- **Android Open Source Project (AOSP):** Virtual A/B and libdm infrastructure.

---

## License

This project incorporates components from the OrangeFox Recovery Project and Android Open Source Project. Hardware modification and custom software installation carry inherent risks; maintain proper backups prior to installation.
