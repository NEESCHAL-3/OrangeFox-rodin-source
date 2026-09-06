# rodin prebuilts

Device-specific binary inputs used by the verified OrangeFox build for Xiaomi `rodin`.

## Firmware input

- `unified/vendor_ramdisk00` - unified HOS/OEM-port PLATFORM input

The public recovery build is region-agnostic. There is no India, Global, China, EEA, or other market-region build selector. The running kernel release selects the matching module tree at first-stage init.

## Shared inputs

- `kernel` - rodin recovery kernel
- `dtbo.img` - rodin DTBO image
- `dtb/mt6899-rodin.dtb` - rodin DTB

Expected hashes are recorded in `../manifests/device-blobs.sha256`.

No generic stock `vendor_boot` fallback image is bundled. If stock recovery must be restored, use `vendor_boot.img` from firmware matching the installed kernel/vendor environment.
