# Credits

This repository is an unofficial OrangeFox Recovery device tree and source integration for Xiaomi `rodin`.

## OrangeFox / Android upstream

- **OrangeFox Recovery Project** — recovery framework, UI, build integration and upstream OrangeFox source.
- **Team Win Recovery Project (TWRP)** — upstream recovery foundation used by OrangeFox.
- **Android Open Source Project (AOSP)** — Android recovery, boot image, update-engine and platform components used by the source tree.

## rodin device lineage

- **KSN2redawew** — original/public rodin TWRP device work used as part of the upstream device lineage and reference base.
- **woshimaniubi8** — OrangeFox rodin device-tree/reference work used during bring-up, including source-tree references and the USB OTG DTB-fix lineage.

The initial local OrangeFox rodin tree was derived from an early `woshimaniubi8` OrangeFox rodin snapshot with local modifications already present at import. It is therefore not represented here as an exact import of one public upstream commit.

The upstream rodin work itself includes lineage from `KSN2redawew/android_device_xiaomi_rodin-twrp`.

## Current rodin integration

- **NEESCHAL** — current rodin OrangeFox integration, system-compatible `vendor_boot` work, Fastbootd fixes, UFS/BSG slot switching, A/B recovery preservation, Format Data fixes, touch/FBE integration, legacy Edify compatibility, runtime OTG auto-reflash handling, source reproducibility work, testing and release maintenance.

## Additional acknowledgements

Thanks to everyone who tested recovery boots, touch, FBE, ROM-install preservation, Format Data, Fastbootd and USB OTG behavior on real `rodin` hardware.

Individual source files and patches may retain their own copyright and attribution notices. Those notices remain authoritative for the corresponding code.
