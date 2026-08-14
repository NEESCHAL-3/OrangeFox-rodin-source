# rodin recovery architecture

This document describes the current OrangeFox architecture for Xiaomi `rodin`.

## Recovery location

Rodin uses Android vendor boot header v4. Recovery is not stored in a standalone `recovery` partition.

The final image contains two vendor ramdisk fragments:

1. a firmware-specific type-1 platform fragment; and
2. a named type-2 OrangeFox recovery fragment.

The platform fragment is selected from the verified India profile. It retains the first-stage runtime, SELinux data, fstab, firmware and stock kernel modules required for normal Android boot. Stock recovery userspace replaced by OrangeFox is pruned so the combined ramdisk remains within the size known to boot reliably on the device.

The OrangeFox fragment contains the recovery userspace and the recovery-only device integration.

Both fragments use LZ4. A zstd recovery-fragment experiment failed before ADB became available on real hardware, so zstd is not used for the final rodin recovery image.

## System-compatible vendor_boot

A normal Android `vendorbootimage` build produces an intermediate recovery-oriented layout. That intermediate image must not be flashed.

`device/xiaomi/rodin/build-lowmem.sh vendorbootimage` invokes `tools/build-system-compatible-vendor-boot.sh` after the Android build. The post-build step combines the selected stock platform fragment with the OrangeFox recovery fragment and emits the final 64 MiB system-compatible `vendor_boot` image.

Normal Android boot therefore continues to receive the retained platform runtime, while recovery boot receives the platform fragment followed by OrangeFox.

## A/B and recovery preservation

Rodin is an A/B Virtual A/B device.

The recovery source patches provide rodin-specific A/B preservation so OrangeFox can be reinstalled into the target slot after a ROM installation.

The verified workflow is:

```text
Flash ROM
-> allow OrangeFox to preserve itself
-> reboot recovery
-> Format Data if required
-> boot Android
```

The preservation path does not treat the target DTB as byte-for-byte immutable. For recovery USB OTG compatibility it intentionally removes the single `mediatek,usb-offload` property from the validated rodin xHCI DTB node before repacking the target-slot image.

## UFS slot switching and Fastbootd

Rodin uses MediaTek UFS handling that differs from generic recovery assumptions.

The device integration switches the UFS boot LUN through the MediaTek BSG interface for slot operations. Recovery-side Fastbootd also carries rodin-specific USB gadget ownership handling so gadget setup is deterministic instead of racing between recovery components.

## Kernel modules and touch

The OrangeFox configuration intentionally avoids the generic second-pass `TW_LOAD_VENDOR_MODULES` behavior used by some TWRP trees.

On rodin that path can attempt to load `scp.ko` in a recovery environment without the SCP reserved-memory setup expected by the stock driver, which was observed to panic in `scp_region_info_init()`.

The recovery fragment therefore carries a controlled module path for the recovery environment. The recovery-only SCP integration prevents unsafe SCP registration while preserving the stock ABI expected by the remaining modules. Goodix and FocalTech SCP offload helpers are disabled for recovery while their AP-side SPI paths remain available.

Rodin touch uses Xiaomi's raw-frame TouchReport path rather than relying only on the standard Goodix event parser. The matching TouchReport service, Goodix/FocalTech processing components, configurations and required isolated runtime dependencies are included in the recovery environment.

Real-device testing confirmed functional multitouch input in OrangeFox, including the Goodix path and the corresponding FocalTech path.

## FBE and security services

File-based encryption support on rodin requires more than the generic recovery crypto stack.

The recovery integration includes the matching vendor security-service path required by the device, including KeyMint, Gatekeeper, MiTEE support, `tee-supplicant`, the required proprietary runtime dependency and the matching Trusted Applications.

The vendor security HALs must execute from their expected `/vendor/bin/hw` paths because the MiTEE authentication path validates the client executable identity.

The recovery also integrates the device Weaver path and the related secure-element components required by synthetic-password unlock.

On-device validation confirmed that the recovery can unlock the lockscreen-backed FBE credential for user 0 and mount `/data` read-write.

## Firmware profiles

The public source release uses the verified India platform ramdisk at `prebuilt/india/vendor_ramdisk00`.

The firmware-specific platform fragment is combined with the OrangeFox recovery fragment by the rodin post-build flow. Other regional firmware profiles are not part of this published build configuration.

## OTG DTB handling

The build-time and runtime OTG handling is documented separately in [`USB-OTG.md`](USB-OTG.md).

## External recovery patches

The exact recovery and build-system source bases, target commits and patch hashes are documented in [`PATCHES.md`](PATCHES.md).
