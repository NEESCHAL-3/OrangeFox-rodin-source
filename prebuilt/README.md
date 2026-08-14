# rodin prebuilts

Device-specific binary inputs used by the verified OrangeFox build for Xiaomi `rodin`.

## Firmware input

- `india/vendor_ramdisk00` - verified India platform ramdisk input

This public source release is India-only.

## Shared inputs

- `kernel` - rodin recovery kernel
- `dtbo.img` - rodin DTBO image
- `dtb/mt6899-rodin.dtb` - rodin DTB

Expected hashes are recorded in `../manifests/device-blobs.sha256`.

No generic stock `vendor_boot` fallback image is bundled. Restore `vendor_boot.img` from the matching India firmware package if required.
