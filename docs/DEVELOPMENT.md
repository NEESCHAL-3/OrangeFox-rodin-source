# Development Workflow

This document describes the reproducible development path for OrangeFox Recovery on Xiaomi `rodin`.

## 1. Source layout

Place this repository at:

```text
device/xiaomi/rodin
```

The external OrangeFox recovery and Android build-system modifications are distributed as canonical patches under `patches/`.

## 2. Verify patch integrity

From `device/xiaomi/rodin`:

```bash
sha256sum -c patches/SHA256SUMS
```

Every entry must report `OK` before patch application.

## 3. Recovery source baseline

Expected clean OrangeFox recovery base:

```text
fd98f33a722bd0bd52034f170bb91e2862654d6b
```

Apply the rodin recovery series from the Android source root:

```bash
git -C bootable/recovery am --keep-cr device/xiaomi/rodin/patches/bootable-recovery/000*.patch
```

Expected final recovery commit:

```text
bc786e483e55c4be5ebeebc039b8acf6ed65d6b2
```

## 4. build/make baseline

Expected clean `build/make` base:

```text
506df226dd003a364916b6b3ee1eb3bf9064f97f
```

Apply the build integration patch:

```bash
git -C build/make am --keep-cr device/xiaomi/rodin/patches/build-make/0001-build-integrate-OrangeFox-recovery-packaging-support.patch
```

Expected final build/make commit:

```text
701572c48b6b328b1ce7f904aeb745440f0f3da0
```

## 5. Firmware profile

Only the India profile is supported:

```bash
export RODIN_FIRMWARE_VARIANT=india
```

The required platform ramdisk is:

```text
device/xiaomi/rodin/prebuilt/india/vendor_ramdisk00
```

## 6. Build

From the Android/OrangeFox source root:

```bash
export RODIN_FIRMWARE_VARIANT=india
device/xiaomi/rodin/build-lowmem.sh vendorbootimage
```

The device has recovery inside `vendor_boot`; do not treat rodin as a standalone recovery-partition device.

## 7. Runtime validation

A source change is not considered verified only because it compiles.

For recovery-sensitive changes validate, where applicable:

- recovery boot
- touch and UI input
- decryption/FBE
- MTP
- Fastbootd
- A/B slot handling
- Format Data
- recovery preservation after ROM installation
- legacy Edify fallback
- USB OTG after ROM install and automatic recovery preservation

## 8. ROM-install recovery flow

The verified flow is:

```text
Flash ROM
   ↓
allow OrangeFox to preserve/repack recovery
   ↓
reboot recovery
   ↓
Format Data when required
   ↓
boot system
```

The runtime rodin OTG handling patches the target-slot DTB during the recovery preservation/repack path.

## 9. Patch maintenance

Do not casually regenerate canonical patches after documentation-only changes.

When runtime source changes intentionally, update the relevant patch series, regenerate `patches/SHA256SUMS`, replay the patches against their documented clean bases, and perform device runtime validation before changing the verified baseline.
