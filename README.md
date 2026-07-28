# OrangeFox Recovery device tree for Redmi Turbo 4 (rodin)

Chinese build and porting documentation:

- [`manifests/README_CN.md`](manifests/README_CN.md)
- [`docs/BUILD_FROM_SOURCE_CN.md`](docs/BUILD_FROM_SOURCE_CN.md)
- [`docs/DEVICE_TREE_PATCHES_CN.md`](docs/DEVICE_TREE_PATCHES_CN.md)
- [`docs/BLOBS_AND_PORTING_CN.md`](docs/BLOBS_AND_PORTING_CN.md)
- [`docs/COMPATIBILITY_CN.md`](docs/COMPATIBILITY_CN.md)
- [`docs/TROUBLESHOOTING_CN.md`](docs/TROUBLESHOOTING_CN.md)

Device tree for the Redmi Turbo 4 (`rodin`), built against OrangeFox 14.1.
The vendor boot layout, MediaTek HALs, firmware, and kernel modules follow
[`KSN2redawew/android_device_xiaomi_rodin-twrp`](https://github.com/KSN2redawew/android_device_xiaomi_rodin-twrp)
at commit `50c9afc`. Firmware-specific boot data comes from the supplied
Android 16 HyperOS partition dump.

## Device and firmware base

- Model: `24129RT7CC`
- SoC: MediaTek MT6899 / Dimensity 8400 Ultra
- Kernel: `6.6.77-android15-8-gca30f3b4bef6-abogki440974771-4k`
- Layout: A/B, dynamic partitions, virtual A/B userspace snapshots
- Recovery location: vendor boot header v4, named `recovery` fragment
- Vendor base: `OS3.0.303.0.WOJCNXM`, Android 15 / API 35
- Installed system reported by the owner: Android 16 HyperOS
- Display: `1220x2712`; OrangeFox theme coordinate space: `1080x2400`

The vendor metadata remains Android 15 because the Android 16 system uses an
Android 15 vendor/GKI base.

## Vendor boot layout

The delivered whole image uses the Android vendor boot v4 fragment model:

1. The unnamed type-1 platform fragment is derived from the Android 16 stock
   fragment. It uses LZ4 legacy compression and retains the stock first-stage
   init/runtime, SELinux policy, fstab, firmware, and all 244 stock boot
   modules. Stock-recovery userspace that OrangeFox replaces is omitted.
2. The named type-2 recovery fragment contains OrangeFox and only seven modules
   that are absent from stock or deliberately patched for recovery. It also
   uses LZ4 legacy compression.
3. Normal Android boot selects only the pruned stock platform fragment.
   Recovery boot
   selects the platform fragment followed by the OrangeFox fragment, whose
   files and module metadata override stock where required.

Although the supplied GKI enables both `CONFIG_RD_LZ4` and `CONFIG_RD_ZSTD`, a
real-device test showed that a zstd recovery fragment fails before ADB becomes
available. The final image therefore uses LZ4 for both fragments. The platform
fragment's normal-boot files and all modules remain byte-identical to stock;
only recovery-only programs, services, and graphics are removed to keep the
combined ramdisk below the early-boot size observed to work on this device.

The stock and generated images share these boot-critical values:

| Item | Value |
| --- | --- |
| Page size | 4096 |
| Kernel address | `0x40000000` |
| Ramdisk address | `0x66f00000` |
| Tags / DTB address | `0x47c80000` |
| Header size | 2128 |
| Vendor cmdline | `bootopt=64S3,32N2,64N2 erofs.reserved_pages=64` |
| DTB SHA-256 | `38369239c984fc191e36d043d19ccbea4c1cd09ee6c80f8646d9493f650a30ae` |

## Kernel modules and touch

The reference tree sets `TW_LOAD_VENDOR_MODULES` to every module in the
ramdisk. OrangeFox interprets that setting differently from the reference TWRP:
after init has loaded `modules.load.recovery`, OrangeFox mounts `vendor_dlkm`
and tries to load the remaining modules. This pulls in `scp.ko`, which panics
in `scp_region_info_init()` because the recovery environment has no SCP
reserved-memory node. The setting is intentionally omitted here; init remains
responsible for the same module set that boots successfully in the reference
TWRP.

Pstore proved that the unmodified Android 16
`scp.ko` panics in `scp_region_info_init()` because recovery boot neither loads
the SCP firmware nor creates the `mediatek,reserve-memory-scp_share` reserved
memory node. The recovery-only module patch keeps the stock ABI and symbol
CRCs, makes the SCP module registration a no-op, and disables the Goodix and
FocalTech SCP offload helpers. Their AP-side SPI paths remain intact. The shared
touch modules and both controller modules are loaded at the end of
`modules.load.recovery`; an idempotent loader
checks them again during `early-boot`, before the recovery process enumerates
input devices.

The Android driver uses Xiaomi's THP raw-frame path rather than Goodix's
standard event parser. The matching Android 16 TouchReport daemon, Goodix and
FocalTech algorithms, HAL, configurations, and isolated libc++/AIDL
dependencies are packed in the recovery ramdisk. Init starts this daemon during
`early-boot` and waits
for raw mode before allowing the normal `boot` trigger to start OrangeFox. The
daemon's service-registration failure branch is bypassed because Android 14
recovery's servicemanager does not know the Android 16 Xiaomi AIDL declaration;
the independent frame-processing thread remains unchanged.

On-device staged testing confirmed the complete path: GT9916K raw frames were
processed by the stock Goodix algorithm, `/dev/input/event1` emitted valid
multitouch DOWN/move/UP events, and the OrangeFox UI responded to touch. Runtime
health can be checked with:

```bash
adb shell getprop vendor.touch.modules.ready
adb shell getprop vendor.touch.service.ready
adb shell 'dmesg | grep -iE "goodix|touch|scp|11011800" | tail -200'
```

The equivalent manually applied FocalTech path has now passed real-device
touch testing. The archived source patches also pass a clean-worktree replay;
the first image rebuilt from a fresh checkout should still receive a FocalTech
boot, touch, FBE, and Android reboot regression test. Its patched module SHA-256 is
`da967ce3f94ecc81153ee91f7e06a2b48eda0526b857688016ef660844bc70b2`.

The first crypto build reached the splash and then waited indefinitely for
`android.system.keystore2.IKeystoreService`; keystore2 repeatedly aborted
because recovery had no usable KeyMint service. The current FBE test build
includes the OS3.0.303.0 vendor's MiTEE KeyMint and Gatekeeper services,
`tee-supplicant`, the required proprietary `libteecli`, VINTF declarations,
and the source-built `libtrusty`. A process-local compatibility library supplies
the newer libc++ verbose-abort symbol required by the Android 15 vendor HALs.
MiTEE also authenticates the client executable path, so the two security HALs
must run from their original `/vendor/bin/hw` paths; launching identical files
from `/system/bin/hw` is rejected with `auth ca name error`. The matching
KeyMint and Gatekeeper Trusted Applications are included under
`/vendor/mitee/ta`. The recovery also exposes the real persist secure storage
read-only with journal replay disabled and applies the original RPMB/UFS device
permissions. A command-line FBE test then reached the Weaver-backed synthetic
password path and blocked because the recovery did not provide
`android.hardware.weaver.IWeaver/default`. The tree now also includes the stock
NXP Weaver service, Xiaomi MiTEE secure-element service, GPMESE TA, and the
matching `nxp_i2c.ko` and `p73.ko` modules from the active `vendor_dlkm`. These
two modules do not depend on `scp.ko`; the unsafe touch/SCP path remains
disabled. The Android 15 NDK interface libraries are isolated under
`/vendor/lib64` for the two proprietary HALs; the recovery process retains its
source-built Weaver interface under `/system/lib64`. On-device testing confirms
that the lockscreen credential decrypts FBE user 0 and mounts `/data` read-write.

## Build

```bash
export ALLOW_MISSING_DEPENDENCIES=true
export FOX_BUILD_DEVICE=rodin
export FOX_AB_DEVICE=1
export FOX_VIRTUAL_AB_DEVICE=1
export OF_FORCE_PREBUILT_KERNEL=1

OF_BUILD_JOBS=8 GOMEMLIMIT=10GiB \
    device/xiaomi/rodin/build-lowmem.sh adbd vendorbootimage
```

Soong can use more than 16 GiB while regenerating the build graph. On a 24 GiB
host, keep at least 12 GiB of swap enabled. The low-memory wrapper also runs
`tools/build-system-compatible-vendor-boot.sh`; a direct `mka vendorbootimage`
only creates an intermediate recovery-only layout and must not be flashed.

## Controlled device test

Xiaomi's user-build fastbootd does not support `fetch`, so
`fastboot flash vendor_boot:recovery` cannot perform the required on-device
read-modify-write. Do not flash the standalone recovery fragment. Flash the
complete 64 MiB image; fastboot selects the current slot for this slotted
partition:

```bash
fastboot flash vendor_boot out/target/product/rodin/OrangeFox-R12.0-Unofficial-rodin-system-compatible.img
fastboot reboot recovery
```

Leave the other slot untouched. After Recovery has been checked, this image is
intended to reboot directly into Android without restoring stock first. If the
first system-boot test fails, return to the bootloader and restore the matching
stock image:

```bash
fastboot flash vendor_boot device/xiaomi/rodin/prebuilt/vendor_boot_stock.img
fastboot reboot
```

Never flash both slots during initial testing.

## Validation status

Host-side validation completed for the current build:

- Full `vendorbootimage` build and system-compatible post-build completed.
- Final IMG is exactly 64 MiB and its embedded AVB hash footer verifies.
- Final SHA-256 is
  `26c8439f4d446754dbfef8defeb3649bad2f65df6fe0cd2a0994ee502185b57b`.
- Header v4, addresses, page size, cmdline, empty bootconfig, and DTB match
  stock. The DTB SHA-256 is `38369239c984fc191e36d043d19ccbea4c1cd09ee6c80f8646d9493f650a30ae`.
- The pruned LZ4 platform fragment is 21,919,218 bytes, expands to 58,098,432
  bytes, and has SHA-256
  `2e4e350653a765f12a0feda4c52e34a4dccc1738d9082fc6a936d66f30cb29d6`.
  It retains all 244 stock modules and the byte-identical normal-boot init,
  linker, libc, fstab, module metadata, firmware, and SELinux files. The two
  stock recovery HAL device fragments are removed from the platform's framework
  VINTF directory so servicemanager can load the OrangeFox keystore2 declaration.
- The LZ4 recovery fragment is 37,319,523 bytes, expands to 92,111,104 bytes,
  and contains 1,144 cpio entries. Its SHA-256 is
  `b5461f854fa291005eb5f31ccb04fe86e90a9db1299177557d413b6fe5ebf844`.
- The combined vendor ramdisk is 59,238,741 bytes, below both the 60,000,000
  byte build limit and the last OrangeFox image confirmed to reach the UI.
- The dual-touch source contains seven recovery-fragment modules and 246
  entries in `modules.load.recovery`; the remaining modules come from the
  retained stock platform fragment. Its latest simulated combined LZ4 size is
  59,612,145 bytes.
- Both ramdisk fragments pass LZ4 integrity tests. Every selected UPX-compressed
  executable passes `upx -t`; init, linkers, ADB, and service managers remain
  uncompressed.
- The unsafe OrangeFox second-pass module loader is disabled.
- Android 16 platform and touch modules are packed, with SPI1 initialized only
  after its MT6899 peripheral clock provider.
- Patched SCP and Goodix module SHA-256 values are
  `ebae9554467e148256cfbab90f0b6d7943d2818ae0cf09bad8aec650bbd99310`
  and `3c2fe7db061743134b715e5a7c361690c3fa36cfacb9c15c1e0bb122e51ac966`.
- Touch modules and the Android 16 TouchReport service start before OrangeFox.
- Real-device testing captured 1,149 valid multitouch event lines and confirmed
  that the OrangeFox UI responds normally.
- The GUI uses equal horizontal and vertical scaling (`1220/1080 =
  2712/2400`) instead of stretching the 1080x1920 theme vertically.
- English, simplified Chinese, traditional Chinese, Japanese, Spanish, and Hungarian are
  packed as built-in languages. Font pruning retains only Noto and MiSans
  families when present; this build contains the single 8,134-codepoint MiSans
  subset because no Noto font is supplied by the tree. It uses TrueType `glyf`
  outlines; the earlier CFF subset caused sustained recovery CPU usage during
  GUI rendering. Every theme font reference resolves to that file. Its SHA-256
  is `db6151d5ab2de091fbd8450df9bee1ffcde396c5a359b1030c3c58a952d81be9`.
- The OrangeFox terminal is retained. Its real executables are mode `0755`
  under `/system/bin`, with the expected absolute links under `/sbin`.
- ADB sideload is retained through `minadbd` and `update_engine_sideload`.
  `fastbootd` and the logical-partition tools are also present. Only the
  standalone `lpdump` diagnostic stack is omitted for space.
- The stock SIH6887 module binds at I2C `0-006b`; three runtime 80 ms pulses
  were physically confirmed. It is packed but omitted from first-stage module
  loading. A oneshot service waits for TouchReport and another 20 seconds
  before loading it, and never pulses the motor itself.
- Crypto/FBE is enabled. The packed cpio contains MiTEE KeyMint, Gatekeeper,
  tee-supplicant, all VINTF fragments, and every direct ELF dependency.
- The packed KeyMint, Gatekeeper, and tee-supplicant files are at their original
  `/vendor/bin` paths, retain mode `0755`, and are byte-identical to the files
  extracted from the Android 15 vendor image.
- The packed TA files match the UUIDs requested by the two HAL binaries and are
  byte-identical to the files extracted from the vendor image.
- Persist is mounted `ro,noload`; recovery cannot write it or replay its ext4
  journal during this test.
- Framework and device VINTF manifests merge successfully. The optional example
  fastboot HAL is omitted because its device fragment was incorrectly installed
  under the framework manifest directory; the `fastbootd` executable remains.
- Legacy battery polling reads the working kernel capacity and status nodes
  instead of the unavailable recovery Health HAL.
- The installer ZIP is intentionally withheld because it is generated before
  the system-compatible post-processing step and embeds the recovery-only
  intermediate image. Use the whole IMG only.

The first on-device build reached the recovery process but panicked at 2.712
seconds while its second-pass loader pulled `scp.ko` from `vendor_dlkm`. Pstore
recorded a translation fault in `scp_region_info_init()` after the SCP driver
reported that its reserved-memory node was unavailable. A subsequent build
without the second-pass loader stayed alive with ADB and initialized DRM, but
remained on the splash while recovery waited for keystore2; keystore2 aborted
repeatedly because KeyMint was unavailable. The boot-stability build without
crypto then reached the full OrangeFox UI with ADB. The first MiTEE build failed
to link the Android 15 services against Android 14 libc++; the compatibility
library fixed that. The next build opened the TEE context but MiTEE rejected the
HALs because they ran from `/system/bin/hw`. The current FBE path-fix build keeps
the module-loader and libc++ fixes and restores the authenticated vendor paths.
On-device testing then showed both HALs blocked in `optee_open_session()`: the
required TA files were absent from the ramdisk, and all RPMB/UFS nodes still had
mode `0600 root:root`. The current TA/RPMB build adds only the two requested TAs,
restores the original device permissions, and starts Gatekeeper in the later
`hal` phase instead of concurrently with KeyMint.
That build successfully registered KeyMint, SecureClock, SharedSecret, and
Gatekeeper on the device. Keystore2 then failed its own service registration
because the example fastboot HAL had installed a device manifest fragment in
`/system/etc/vintf/manifest`, invalidating the complete framework manifest. The
current VINTF-fix build removes that optional HAL and its invalid fragment.

Real-device validation has confirmed FBE user 0 decryption, corrected battery
reporting, and touch. The first successful FBE image then repeatedly restarted
the recovery process with `SIGSEGV` after decryption. `/data` itself was already
mounted successfully; the crash began when OrangeFox found
`/data/media/0/Fox/.theme` or `.navbar` and destroyed and recreated the complete
GUI package. Reversibly renaming those two files kept the same recovery process
stable for more than six minutes after decryption, confirming the trigger. The
current build defines `OF_SKIP_POST_DECRYPT_THEME_RELOAD` for rodin and skips
only that late full-package reload. The initial GUI package, normal settings
load, FBE, touch, language files, and persistent theme files remain supported.
This source-level fix still requires a final on-device test with the saved theme
files restored. MTP and fastbootd also still require testing. Flashlight remains
disabled until a recovery-safe LED node is verified.
