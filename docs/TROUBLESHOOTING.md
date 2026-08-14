# Troubleshooting

## Do not flash the intermediate vendor_boot

The ordinary Android build produces an intermediate recovery-oriented vendor_boot layout.

For rodin, build with:

```bash
device/xiaomi/rodin/build-lowmem.sh vendorbootimage
```

Flash only the final system-compatible 64 MiB image created by the rodin post-build step.

## Build fails before compilation

On constrained hosts, verify available memory and swap:

```bash
free -h
swapon --show
```

The low-memory build path expects at least 12 GiB of swap on constrained builders.

## Source patch application fails

Run the public patch helper from the OrangeFox source root:

```bash
device/xiaomi/rodin/tools/apply-orangefox-patches.sh "$PWD"
```

The helper expects the pinned OrangeFox source state described in `PATCHES.md`.

For manual replay of the numbered recovery patches with `git am`, use `--keep-cr` because the upstream font XML at the patch-3 parent uses CRLF line endings.

## Wrong firmware profile

The public source release is India-only.

Use the default profile:

```bash
export RODIN_FIRMWARE_VARIANT=india
```

Do not substitute platform ramdisks or stock `vendor_boot` images from unrelated firmware packages.

## Android or recovery does not boot after flashing

Do not immediately flash random vendor_boot images from another region.

Return to the bootloader and restore the matching stock `vendor_boot.img` from the same firmware package installed on the device.

During initial testing, avoid overwriting both slots.

## OTG disappears after installing a ROM

The verified recovery source patches the rodin xHCI DTB state during automatic OrangeFox preservation.

The expected workflow is:

```text
Flash ROM
-> allow OrangeFox to preserve itself
-> reboot recovery
-> Format Data if required
-> boot Android
```

If testing a build without the runtime OTG patch, manually reflashing a known-good OrangeFox image may temporarily restore OTG, but the correct fix is to use the current patched recovery source.

See `USB-OTG.md`.

## Format Data after ROM installation

Do not wipe immediately in the middle of the automatic preservation/merge transition.

Allow OrangeFox preservation to finish, reboot recovery, then Format Data if the ROM requires it.

## Touch problems

The rodin recovery uses Xiaomi's TouchReport raw-frame path and recovery-specific module handling.

If touch regresses, capture:

```bash
adb shell getprop vendor.touch.modules.ready
adb shell getprop vendor.touch.service.ready
adb shell 'dmesg | grep -iE "goodix|focal|touch|scp|11011800" | tail -200'
```

Do not re-enable a generic second-pass vendor module loader without validating `scp.ko`; the recovery-specific module path intentionally avoids the unsafe SCP initialization observed on rodin.

## FBE decryption problems

The current tree includes the vendor security-service path required for rodin KeyMint, Gatekeeper, MiTEE and Weaver integration.

If `/data` no longer decrypts after updating firmware inputs, treat the new firmware as a compatibility change and revalidate the matching vendor services, Trusted Applications, VINTF declarations and secure-element path rather than replacing only one binary.

## Patch integrity

From the device-tree repository root:

```bash
sha256sum -c patches/SHA256SUMS
```

All published patch entries should report `OK`.
