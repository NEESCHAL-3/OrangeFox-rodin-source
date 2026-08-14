# Building OrangeFox for rodin

This repository is intended to be placed at `device/xiaomi/rodin` inside an OrangeFox 14.1 source tree.

## Supported profiles

- `india` — default

China firmware is not a supported public build profile.

## Source preparation

The rodin tree carries exact external patches for `bootable/recovery` and `build/make`.

From the OrangeFox source root run:

```bash
device/xiaomi/rodin/tools/apply-orangefox-patches.sh "$PWD"
```

The script verifies the pinned inputs and applies the complete base-to-target patches only when required.

## Host memory

The low-memory build path expects at least 12 GiB of available swap on constrained builders.

The included GitHub Actions workflow provisions 12 GiB of swap automatically.

## India build

India is the default profile:

```bash
export RODIN_FIRMWARE_VARIANT=india
device/xiaomi/rodin/build-lowmem.sh vendorbootimage
```

The environment variable may be omitted for India.


## Important output rule

Do not flash the intermediate recovery-only `vendor_boot` produced by the ordinary Android build.

`build-lowmem.sh vendorbootimage` runs `tools/build-system-compatible-vendor-boot.sh`, combines the selected stock platform fragment with the OrangeFox recovery fragment, applies the rodin recovery-host DTB handling, and produces the final 64 MiB system-compatible `vendor_boot` image.

## Flashing

Flash the final system-compatible image:

```bash
fastboot flash vendor_boot <final-system-compatible-image.img>
fastboot reboot recovery
```

During initial testing, do not overwrite both slots.

If recovery is required, restore the matching stock `vendor_boot.img` from the same firmware package installed on the device.

## GitHub Actions

The workflow under `.github/workflows/build.yml` provides the verified `india` firmware profile and uses the same patching and low-memory build path described above.
