# Notice

This repository combines open-source recovery/device integration with device-specific binary inputs required to build OrangeFox for Xiaomi `rodin`.

## Source licensing

No single repository-wide license is intended to replace the licenses or copyright notices already attached to individual upstream files.

Source originating from OrangeFox, TWRP, AOSP or other upstream projects remains subject to the license terms and notices provided by those projects and by the individual files.

Device-tree modifications and published patches should be read together with the copyright and license headers present in the source they modify.

## Proprietary binary inputs

Files under `prebuilt/` and other device-specific binary components may originate from Xiaomi, MediaTek or other hardware/software vendors.

Their inclusion in this source tree is for device compatibility and reproducible recovery builds. They are not relicensed by this repository.

In particular, do not assume that proprietary firmware, kernel modules, Trusted Applications, vendor HALs, ramdisk fragments or other binary components are covered by an open-source license merely because they are stored beside open-source files.

## Firmware profiles

The public HOS/OEM-port build is region-agnostic. It does not use a market-region firmware selector. Runtime compatibility is determined by the running kernel family and unified PLATFORM module layout.

The unified HOS/OEM-port PLATFORM is selected by the running Rodin kernel family rather than by a firmware-region profile. The repository intentionally does not ship a generic stock `vendor_boot` fallback image.

## External source patches

Exact device-specific modifications to `bootable/recovery` and `build/make` are published under `patches/`.

The base commits, verified target commits, target tree hashes and patch SHA-256 values are documented in `docs/PATCHES.md`.

## Trademarks and project status

OrangeFox, Xiaomi, POCO, Redmi, MediaTek and other product or project names belong to their respective owners.

This repository and its published recovery images are unofficial and are not represented as an official OrangeFox, Xiaomi, POCO, Redmi or MediaTek release.
