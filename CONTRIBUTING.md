# Contributing

This repository tracks the runtime-verified OrangeFox Recovery integration for Xiaomi `rodin`.

Changes affecting boot, `vendor_boot`, Fastbootd, USB/MTP/OTG, FBE/decryption, touch, filesystems, A/B preservation, Format Data, auto-reflash, or legacy installer compatibility require device validation.

Canonical patches under `patches/` are checksum-tracked. Do not reformat them solely to remove whitespace warnings.

Before committing:

```bash
sha256sum -c patches/SHA256SUMS
git diff --check -- . ':(exclude)patches/**'
```

Rodin recovery is **region-agnostic**. There is no India, Global, China, EEA, or other market-region build selector. Compatibility is determined by the ROM profile, Android GKI/KMI compatibility, and vendor environment, not by the firmware region label or exact 6.6.x patchlevel. Changes introducing a new Android/LTS GKI family, incompatible KMI/vendor ABI, vendor_boot layout, or fundamentally different first-stage environment still require device validation before inclusion.
