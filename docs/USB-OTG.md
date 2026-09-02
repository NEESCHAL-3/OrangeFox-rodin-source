# USB OTG Handling on Rodin

[Repository](../README.md) / [Documentation](README.md)

This guide describes the verified USB OTG fixes used during image packaging and automatic recovery preservation.

<details>
<summary>On this page</summary>

- [Problem](#problem)
- [DTB property](#dtb-property)
- [Build-time fix](#build-time-fix)
- [Runtime auto-preservation fix](#runtime-auto-preservation-fix)
- [Verified workflow](#verified-workflow)
- [Source location](#source-location)

</details>

## Problem

A rodin-specific OTG failure was reproduced after installing a ROM and allowing OrangeFox to preserve itself automatically into the target slot.

The sequence was:

```text
flash ROM
-> OrangeFox auto-preservation
-> reboot recovery
-> OTG unavailable
```

Manually flashing the known-good OrangeFox image again restored OTG, which showed that the recovery auto-repack path was carrying forward a DTB state that was unsuitable for recovery-host OTG.

## DTB property

The relevant validated node is:

```text
/soc/usb0@11201000/xhci0@11200000
```

Compatible string:

```text
mediatek,mtk-xhci
```

The recovery-host fix removes only:

```text
mediatek,usb-offload
```

No broader DTB rewrite is performed.

## Build-time fix

`tools/make-recovery-host-dtb.py` validates the MediaTek DTB container/FDT structure, finds the expected rodin xHCI node and removes only the `mediatek,usb-offload` property.

The final system-compatible image therefore carries a DTB suitable for recovery-host OTG.

## Runtime auto-preservation fix

Recovery patch 6 extends the rodin automatic reflash path.

During target-slot preservation the recovery code:

1. validates the rodin DTB and expected xHCI node;
2. removes only `mediatek,usb-offload`;
3. repacks the target-slot `vendor_boot`; and
4. aborts the unsafe automatic reflash if the DTB patch cannot be applied exactly as expected.

The rodin recovery build links `libfdt` for this operation.

This behavior is intentionally rodin-specific and is not a generic DTB mutation for other devices.

## Verified workflow

Real-device verification passed with:

```text
flash ROM
-> OrangeFox auto-preservation
-> reboot recovery
-> Format Data
-> boot Android
```

OTG remained functional without manually reflashing OrangeFox.

## Source location

The runtime implementation is part of the verified recovery target:

`bc786e483e55c4be5ebeebc039b8acf6ed65d6b2`

The corresponding numbered patch is:

`patches/bootable-recovery/0006-recovery-patch-rodin-OTG-DTB-during-auto-reflash.patch`

The exact complete recovery patch and its SHA-256 are documented in [`PATCHES.md`](PATCHES.md).

---

[Back to documentation](README.md)
