# External source patches

The rodin device tree modifies two OrangeFox source repositories outside `device/xiaomi/rodin`.

## bootable/recovery

Base commit:

`fd98f33a722bd0bd52034f170bb91e2862654d6b`

Base tree:

`739ac37b8f59b2be91262425af8307d6e36ef589`

Verified target commit:

`bc786e483e55c4be5ebeebc039b8acf6ed65d6b2`

Verified target tree:

`60c1635bde22c205c11db32c32643f8228565206`

Numbered patch series:

1. deterministic rodin USB gadget ownership
2. A/B preservation and Format Data fixes
3. rodin UI, input and font fixes
4. ARM64 fallback for legacy ARM32 Edify installers
5. runtime-verified applypatch/blockimg/repacker baseline work
6. rodin OTG DTB handling during automatic recovery reflash

Machine-friendly complete patch:

`patches/bootable-recovery/rodin-complete.patch`

SHA-256:

`7a9e58bd9ac062bf93c67c080ba3ec397ce3b06530283b4eb07031e6163dc763`

## build/make

Base commit:

`506df226dd003a364916b6b3ee1eb3bf9064f97f`

Base tree:

`f08d9015d3c341f571651f99f28854b228163423`

Verified target commit:

`701572c48b6b328b1ce7f904aeb745440f0f3da0`

Verified target tree:

`fe99e6db5393c7fd725fa9b0d92d5d4e316c79b3`

Machine-friendly complete patch:

`patches/build-make/rodin-complete.patch`

SHA-256:

`5f2d3f43a4d78eee6d560a4a169df30fc95de6fa2ed294e3210e684a641a8329`

## Reproducibility

The complete recovery patch was independently replayed from its exact base and reproduced target tree `60c1635bde22c205c11db32c32643f8228565206`.

The build/make patch was independently replayed from its exact base and reproduced target tree `fe99e6db5393c7fd725fa9b0d92d5d4e316c79b3`.

The numbered recovery patches preserve development history. When replaying them with `git am`, use `--keep-cr` because the upstream font XML at the patch-3 parent uses CRLF line endings.

For automated preparation, use `tools/apply-orangefox-patches.sh`, which applies the complete patches rather than reconstructing the numbered series.

All published patch hashes are also recorded in `patches/SHA256SUMS`.
