# External Source Patches

[Repository](../README.md) / [Documentation](README.md)

Rodin requires a small set of canonical changes outside `device/xiaomi/rodin`.

The public build workflow applies these through:

```bash
tools/apply-orangefox-patches.sh
```

All patch files are SHA-256 verified by `tools/verify-build-inputs.sh`.

<details>
<summary>On this page</summary>

- [bootable/recovery](#bootablerecovery)
- [build/make](#buildmake)
- [hardware/interfaces](#hardwareinterfaces)
- [system/core](#systemcore)
- [Fastbootd runtime validation](#fastbootd-runtime-validation)
- [Patch application](#patch-application)
- [Reproducibility](#reproducibility)
- [Hash manifest](#hash-manifest)

</details>

## bootable/recovery

Canonical complete patch:

`patches/bootable-recovery/rodin-complete.patch`

SHA-256:

`2139f65744aa6773132b149c80adc5ff6596a67269029cd57935f8b3c076c4e0`

The recovery patch contains the established rodin recovery work, including:

1. deterministic rodin USB gadget ownership
2. A/B recovery preservation and Format Data fixes
3. rodin UI, input and font rendering fixes
4. ARM64 fallback for legacy ARM32 Edify installers
5. runtime-verified recovery baseline work
6. rodin OTG DTB handling during automatic recovery reflash

The corresponding numbered development patches remain under:

`patches/bootable-recovery/`

The complete patch is the machine-friendly input used by automated source preparation.

The current verified development recovery revision is:

`a9729dd387aef007c9ed87ced989bebc5e5441b7`

Because later recovery development can modify lines originally introduced by the complete patch, `apply-orangefox-patches.sh` also recognizes the already-prepared recovery state through verified source markers instead of attempting to apply the complete patch twice.

## build/make

Canonical complete patch:

`patches/build-make/rodin-complete.patch`

SHA-256:

`8d7f88b979fd51280d52774ccc51205a4316f6160053a17210c246ca4944b18b`

The build/make patch contains the rodin OrangeFox recovery compression/build integration required by the current source flow.

The numbered development patch is stored under:

`patches/build-make/`

## hardware/interfaces

Canonical Fastbootd BootControl patch:

`patches/hardware-interfaces/rodin-fastbootd-bootcontrol-nonblocking.patch`

SHA-256:

`e10f789766f359d5d4b91d2fa7ee8418d5c39694f7c914d5cc02c6aa533755b8`

This patch adds a non-blocking BootControl service lookup path.

Rodin Fastbootd must not wait indefinitely for an optional BootControl service that may not be published in recovery.

The verified development revision containing this change is:

`61f0bcd25bdbf2b6d4d978fdfa348bf01078a8f8`

## system/core

Canonical Fastbootd optional-HAL patch:

`patches/system-core/rodin-fastbootd-optional-hals-nonblocking.patch`

SHA-256:

`740b10ad8cae477e8d387406b61594db869f83ab3fe0a15af46ec4ca6fc655e6`

This patch changes Fastbootd optional service discovery to non-blocking lookups, including the BootControl client path.

It prevents recovery Fastbootd from hanging while waiting for optional HAL services that are unavailable.

The verified development revision containing this change is:

`d4add349bc23456cd137d73b1acbcd789aaa5ed0`

## Fastbootd runtime validation

The hardware/interfaces and system/core patches are part of the verified rodin Fastbootd fix.

Runtime testing under both supported HOS kernel families produced:

```text
is-userspace: yes
product: rodin
```

The working recovery USB ConfigFS configuration is retained separately in the rodin recovery/device source and should not be replaced by competing USB gadget ownership.

## Patch application

Automated source preparation uses:

```bash
tools/apply-orangefox-patches.sh
```

For each normal patch, the helper distinguishes between:

- cleanly applicable
- already applied
- invalid/unexpected source state

The complete recovery patch additionally has verified marker detection so an already-prepared recovery development tree is not patched twice.

Do not force-apply a patch when both forward and already-applied validation fail.

## Reproducibility

The pinned OrangeFox manifest remains the pristine source baseline.

Repositories intentionally changed by rodin external patches are verified separately from untouched manifest projects.

The current verifier checks:

- 657 untouched pinned projects
- patched recovery state
- patched hardware/interfaces state
- patched system/core state
- canonical patch SHA-256 values
- rodin binary/prebuilt inputs

This preserves source reproducibility without pretending intentionally patched repositories are still identical to their pristine manifest revisions.

## Hash manifest

All published patch hashes are recorded in:

`patches/SHA256SUMS`

Current machine-friendly patch hashes:

```text
2139f65744aa6773132b149c80adc5ff6596a67269029cd57935f8b3c076c4e0  patches/bootable-recovery/rodin-complete.patch
8d7f88b979fd51280d52774ccc51205a4316f6160053a17210c246ca4944b18b  patches/build-make/rodin-complete.patch
e10f789766f359d5d4b91d2fa7ee8418d5c39694f7c914d5cc02c6aa533755b8  patches/hardware-interfaces/rodin-fastbootd-bootcontrol-nonblocking.patch
740b10ad8cae477e8d387406b61594db869f83ab3fe0a15af46ec4ca6fc655e6  patches/system-core/rodin-fastbootd-optional-hals-nonblocking.patch
```

---

[Back to documentation](README.md)
