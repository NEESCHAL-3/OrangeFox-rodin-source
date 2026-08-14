# Contributing

This repository tracks the runtime-verified OrangeFox Recovery integration for Xiaomi `rodin`.

Changes affecting boot, `vendor_boot`, Fastbootd, USB/MTP/OTG, FBE/decryption, touch, filesystems, A/B preservation, Format Data, auto-reflash, or legacy installer compatibility require device validation.

Canonical patches under `patches/` are checksum-tracked. Do not reformat them solely to remove whitespace warnings.

Before committing:

```bash
sha256sum -c patches/SHA256SUMS
git diff --check -- . ':(exclude)patches/**'
```

The maintained firmware profile is **India only**. Other regional profiles require separate runtime validation before inclusion.
