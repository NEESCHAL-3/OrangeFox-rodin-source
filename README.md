# OrangeFox Recovery for POCO X7 Pro / Redmi Turbo 4 (rodin)

Unofficial OrangeFox Recovery source for Xiaomi `rodin`, targeting the POCO X7 Pro and Redmi Turbo 4.

This repository contains the complete rodin device integration together with the external OrangeFox and Android build-system patches required to reproduce the verified recovery.

## Source status

- OrangeFox branch: `14.1`
- Device tree baseline: `4df2a7210e1b146cebeed11252fe5f8fa516d2eb`
- Recovery target: `bc786e483e55c4be5ebeebc039b8acf6ed65d6b2`
- build/make target: `701572c48b6b328b1ce7f904aeb745440f0f3da0`
- Recovery location: `vendor_boot`
- Vendor boot header: v4
- Layout: A/B, dynamic partitions, Virtual A/B
- UI language: English
- Final image size: 64 MiB

## Firmware profiles

This public source release uses the runtime-verified India firmware profile only.

| Profile | Status | Input |
| --- | --- | --- |
| `india` | Verified / default | `prebuilt/india/vendor_ramdisk00` |

Build with:

```bash
export RODIN_FIRMWARE_VARIANT=india
device/xiaomi/rodin/build-lowmem.sh vendorbootimage
```

Other regional firmware profiles are not published by this source release.

## Included rodin work

- system-compatible `vendor_boot` generation
- deterministic Fastbootd USB gadget handling
- MediaTek UFS/BSG A/B slot switching
- A/B OrangeFox preservation after ROM installation
- Virtual A/B and Format Data fixes
- UI, input and font fixes
- Android 16 touch and recovery module integration
- FBE, KeyMint, Gatekeeper and Weaver recovery integration
- ARM64 fallback for legacy ARM32 Edify installers
- legacy Edify, applypatch and blockimg compatibility work
- runtime OTG DTB repair during OrangeFox auto-preservation

## Vendor boot architecture

Rodin boots recovery from a named type-2 recovery fragment inside Android vendor boot v4.

The final system-compatible image combines:

1. a firmware-specific type-1 platform ramdisk; and
2. the OrangeFox type-2 recovery ramdisk.

The platform fragment retains the stock first-stage runtime, SELinux data, fstab, firmware and kernel modules required for normal Android boot.

Both ramdisk fragments use LZ4.

Do not flash the intermediate recovery-only image produced by the normal Android build. `build-lowmem.sh vendorbootimage` runs the rodin system-compatible post-build step.

## Source patches

Device-specific changes outside `device/xiaomi/rodin` are published under:

```text
patches/bootable-recovery/
patches/build-make/
```

The numbered patches preserve the individual development commits. The `rodin-complete.patch` files are exact base-to-target patches used by the automatic source preparation script.

Patch integrity hashes are stored in `patches/SHA256SUMS`.

## Flashing

Flash a complete system-compatible 64 MiB image matching the intended firmware profile:

```bash
fastboot flash vendor_boot <OrangeFox-system-compatible.img>
fastboot reboot recovery
```

Do not overwrite both slots during initial testing.

If recovery or Android fails to boot, restore the matching stock `vendor_boot.img` from the same firmware package installed on the device.

Do not restore a `vendor_boot` image from another region or firmware release.

Recommended ROM installation flow:

```text
Flash ROM
→ allow OrangeFox to preserve itself
→ reboot recovery
→ Format Data if required
→ boot Android
```

## Verified release

Current verified unofficial stable image:

`OrangeFox-R12.0-Rodin-UNOFFICIAL-STABLE-20260807.img`

SHA-256:

```text
fa4c59e0f3713b42aa20d6316243fc1dd629e8899d461160411d52c4c2ff124e
```

Size: `67108864` bytes.

## Documentation

- `BUILDING.md` — reproducible build procedure
- `docs/ARCHITECTURE.md` — rodin vendor_boot, touch, crypto and recovery architecture
- `docs/COMPATIBILITY.md` — supported devices and firmware profiles
- `docs/PATCHES.md` — external recovery and build-system patches
- `docs/LEGACY-EDIFY.md` — legacy installer compatibility
- `docs/USB-OTG.md` — runtime OTG DTB handling
- `docs/TROUBLESHOOTING.md` — build and recovery troubleshooting
- `CREDITS.md` — upstream lineage and contributors
- `NOTICE.md` — licensing and proprietary component notice

## Disclaimer

This is an unofficial OrangeFox Recovery build for `rodin`.

Keep the matching stock firmware available before flashing or testing custom recovery images.
