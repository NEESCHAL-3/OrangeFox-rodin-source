# Verified Runtime Baseline

[Repository](../README.md) / [Documentation](README.md)

This file records the currently verified OrangeFox baseline for Xiaomi `rodin`.

<details>
<summary>On this page</summary>

- [Device tree](#device-tree)
- [Patched external repositories](#patched-external-repositories)
- [Fastbootd patches](#fastbootd-patches)
- [Unified HOS PLATFORM](#unified-hos-platform)
- [Global and India module equivalence](#global-and-india-module-equivalence)
- [Unified HOS runtime validation](#unified-hos-runtime-validation)
- [Unified prototype](#unified-prototype)
- [Verified release build](#verified-release-build)
- [Verified HOS packaging](#verified-hos-packaging)
- [Recovery behavior baseline](#recovery-behavior-baseline)
- [Support boundary](#support-boundary)

</details>

## Device tree

Canonical device source:

`device/xiaomi/rodin`

The public release workflow uses:

```bash
./build-release.sh
```

The release build produces four images:

- unified HOS AVB Enabled
- unified HOS AVB Disabled
- AOSP AVB Enabled
- AOSP AVB Disabled

## Patched external repositories

Verified development revisions:

| External repository | Verified development revision |
| --- | --- |
| `bootable/recovery` | `eaa1bf3d2c71b4c8c2ecccdb24f1170b0fe4d8e7` |
| `hardware/interfaces` | `61f0bcd25bdbf2b6d4d978fdfa348bf01078a8f8` |
| `system/core` | `d4add349bc23456cd137d73b1acbcd789aaa5ed0` |

The remaining untouched source projects are verified against the pinned OrangeFox source manifest.

## Fastbootd patches

BootControl non-blocking lookup patch SHA-256:

`e10f789766f359d5d4b91d2fa7ee8418d5c39694f7c914d5cc02c6aa533755b8`

Fastbootd optional-HAL non-blocking patch SHA-256:

`740b10ad8cae477e8d387406b61594db869f83ab3fe0a15af46ec4ca6fc655e6`

Runtime Fastbootd verification produced:

```text
is-userspace: yes
product: rodin
```

on both verified HOS kernel families.

## Unified HOS PLATFORM

Pinned file:

`prebuilt/unified/vendor_ramdisk00`

SHA-256:

`dda9762619ee1cbe3019735103ddd25c62ebd9d2431e991303d5855520d93389`

Compression:

`Zstandard`

The PLATFORM contains independent module trees for:

| Firmware family | Verified kernel release |
| --- | --- |
| CN | `6.6.77-android15-8-gca30f3b4bef6-abogki440974771-4k` |
| Global/MIXM and India | `6.6.89-android15-8-g8e4be6b47e40-ab14134548-4k` |

The stock CN and 6.6.89 module sets each contain 244 stock modules before the OrangeFox device modules are added.

## Global and India module equivalence

The stock Global/MIXM and India PLATFORM ramdisks were directly compared.

Both contain 485 files and 244 stock kernel modules.

Their file layouts are identical.

Their complete kernel-module payloads are identical and use:

`6.6.89-android15-8-g03fb7c87b0b5-4k`

The observed content differences were limited to:

- `prop.default`
- `system/etc/copylib.txt`

Therefore the unified HOS PLATFORM uses one 6.6.89 module tree for both Global/MIXM and India.

## Unified HOS runtime validation

The same unified HOS vendor_boot architecture was tested with both supported kernel families.

CN test kernel:

`6.6.77-android15-8-gca30f3b4bef6-abogki440974771-4k`

Global/MIXM test kernel:

`6.6.89-android15-8-g8e4be6b47e40-ab14134548-4k`

Verified on both:

- OrangeFox boot
- correct stock module-tree selection
- OrangeFox touch modules
- haptics module
- userdata block mapping
- recovery storage access
- Fastbootd
- userspace Fastboot identification

The OrangeFox device-specific module set successfully loaded under both kernel families.

## Unified prototype

The first dual-kernel AVB-disabled unified prototype SHA-256 was:

`57df845928e5716ae486f9d1be4e2e577006040fe432b274ba4b16384dfab2ad`

It was runtime-tested under both the CN 6.6.77 and Global 6.6.89 kernels.

## Verified release build

A complete `./build-release.sh` run completed successfully and produced all four release images.

| Release image | SHA-256 |
| --- | --- |
| HOS AVB Enabled | `2d17e011cdbb1d9f7c21d4a7f4a0688c8823df65e10070db60837bccd9880fed` |
| HOS AVB Disabled | `3d276e4df21dfaba31215ef1e6a283b2693e1faa6d3ca235e9de2740a80ba60f` |
| AOSP AVB Enabled | `47d29039fcac073fdceb5bcc86df0db1abdb6d81bb2a300b868003e429638346` |
| AOSP AVB Disabled | `23607d444d45b1db279117c70944255f5cece027d9ed2b21c41ad1c5dee6bffd` |

The default `vendor_boot.img` output points to the unified HOS AVB Enabled image.

## Verified HOS packaging

The successful unified HOS AVB Disabled build reported:

| Component | Size (bytes) | Compression |
| --- | ---: | --- |
| PLATFORM | 22564936 | Zstandard |
| RECOVERY | 38600750 | LZ4 |
| Combined vendor ramdisk | 61165686 | Zstandard PLATFORM + LZ4 RECOVERY |

This remains below the rodin build safety limit of 62000000 bytes.

## Recovery behavior baseline

The current recovery baseline includes verified support for:

- touch
- haptics
- MTP
- ADB
- FBE decryption
- Fastbootd
- A/B slot switching
- ROM-install recovery preservation
- Format Data
- USB OTG preservation
- legacy ARM32 Edify installer fallback

## Support boundary

The verified HOS compatibility baseline covers the supported rodin CN 6.6.77 and Global/India 6.6.89 kernel families.

AOSP remains a separate profile with its dedicated PLATFORM and bootconfig.

Different kernel ABIs or unrelated vendor environments require separate validation before being declared supported.

## Auto-DFE v2 validation

Recovery revision:

`eaa1bf3d2c71b4c8c2ecccdb24f1170b0fe4d8e7`

Auto-DFE v2 adds compression-aware vendor_boot v4 PLATFORM handling.

Verified behavior:

- legacy LZ4 PLATFORM support retained
- Zstd PLATFORM support added through libzstd
- PLATFORM size and offset are taken from the vendor ramdisk table
- Zstd does not depend on an LZ4 end-marker scan
- rebuilt PLATFORM must remain within the original allocation
- actual rebuilt PLATFORM size is written back to the v4 ramdisk table
- other vendor_boot fragments remain at their existing offsets
- AVB hash refresh and rollback protections remain active

The unified HOS Zstd dry-run completed successfully:

`Auto-DFE DRY-RUN PASS. Nothing was flashed.`

The target vendor_boot remained unchanged during dry-run.

Final normal recovery startup was also verified with successful FBE decryption and the required rodin modules loaded.

---

[Back to documentation](README.md)
