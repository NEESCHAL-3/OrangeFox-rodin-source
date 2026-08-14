# Compatibility

This source release targets Xiaomi `rodin`.

## Devices

Supported device family:

- POCO X7 Pro
- Redmi Turbo 4

Both use the `rodin` platform and vendor_boot recovery layout.

## Firmware profiles

The published and runtime-verified firmware profile is India.

| Profile | Status | Input |
| --- | --- | --- |
| `india` | Verified / default | `prebuilt/india/vendor_ramdisk00` |

The selected platform ramdisk must match the intended India firmware release. Do not mix platform ramdisks or `vendor_boot` images from unrelated firmware packages.

## Recovery layout

Rodin uses:

- A/B slots
- dynamic partitions
- Virtual A/B
- vendor boot header v4
- a named type-2 recovery ramdisk fragment inside `vendor_boot`

There is no standalone recovery partition for this build.

## Verified recovery behavior

The current source has been validated for:

- OrangeFox boot with the system-compatible vendor_boot layout
- MTP and ADB in recovery
- touch input
- FBE user-data decryption
- Fastbootd
- A/B slot switching
- ROM-install recovery preservation
- Format Data workflow
- USB OTG after automatic OrangeFox preservation
- a tested legacy ARM32 Edify installer through the ARM64 fallback updater

Legacy installer support should not be interpreted as universal compatibility with every historical recovery ZIP.

## Flashing compatibility

Only flash the final 64 MiB system-compatible vendor_boot image produced by the rodin post-build flow.

If a recovery test fails, restore the matching stock `vendor_boot.img` from the same firmware package installed on the device.

Do not use a stock vendor_boot image from another region or firmware release as a generic fallback.


## Recovery product identity

The recovery keeps the tested `rodin` product identity used during device bring-up. Firmware compatibility for this public source release is India-only and is determined by the verified India platform ramdisk used in the final system-compatible `vendor_boot` image.
