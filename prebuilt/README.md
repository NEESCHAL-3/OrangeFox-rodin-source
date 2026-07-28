# Prebuilt firmware artifacts

These files were extracted directly from the supplied `rodin_part` partition
dump. Update all of them together when changing the firmware base.

| File | Source | SHA-256 |
| --- | --- | --- |
| `kernel` | kernel payload from `boot_a` | `55caa83bf1dd1ab5e34521f1faa18532a6110a065123577a1a62d80ee5178569` |
| `dtb/mt6899-rodin.dtb` | DTB from `vendor_boot_a` | `38369239c984fc191e36d043d19ccbea4c1cd09ee6c80f8646d9493f650a30ae` |
| `dtbo.img` | direct copy of `dtbo_a` | `ccd008dc7336301b7cc6fab7b59400b3debd2866f055f085e61696dbc7c0f298` |
| `global/vendor_ramdisk00` | locally extracted type-1 platform fragment from Global OS3.0.301.0.WOJMIXM `vendor_boot.img` | `349cc6598f70ae401afe3071abed6de00815af39c5aded3551cff23364208731` |
| `vendor_boot_stock.img` | direct copy of `vendor_boot_a` | `499bb470719b790baf90f8b49a0340e09b7ed983f3508736a86a6d1e9b503f47` |
| `vendor_ramdisk00` | platform fragment from `vendor_boot_a` | `192977d50a121f7a5ddfab0212488ef0dbb0326cad802ce9d664649967a9845c` |

Do not mix these files with artifacts from another firmware release. The
system-compatible post-build step uses `vendor_ramdisk00` as an immutable
source. It removes only the stock-recovery programs, services, graphics, and
misplaced recovery HAL VINTF fragments that the type-2 OrangeFox fragment
replaces. The generated type-1 fragment retains the byte-identical stock
first-stage runtime, SELinux data, fstab, firmware, and all 244 stock modules
required by normal Android boot. Both generated fragments use LZ4. The supplied
kernel advertises zstd support, but a real-device zstd test failed before ADB
became available.

The default build profile is `cn`, which uses `vendor_ramdisk00`. Global
OS3.0.301.0.WOJMIXM must instead use `global/vendor_ramdisk00`; select it with
`RODIN_FIRMWARE_VARIANT=global`. The Global profile changes only the retained
type-1 platform fragment. Its DTB, fstab, init, SELinux data, and stock
recovery fragment were verified identical to the CN base, so the OrangeFox
recovery resources remain shared.

The textual device-tree patch deliberately does not embed the 29 MiB Global
fragment. Populate it from the matching full firmware package before using the
Global profile:

```bash
device/xiaomi/rodin/tools/import-global-firmware-inputs.sh \
  /path/to/rodin_global_images_OS3.0.301.0.WOJMIXM_16.0/images/vendor_boot.img
```

The importer accepts only the verified 64 MiB Global `vendor_boot.img` and
checks its hash, extracted type-1 fragment, and DTB before atomically replacing
`global/vendor_ramdisk00`.
