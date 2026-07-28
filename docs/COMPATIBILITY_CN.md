# rodin OrangeFox 固件与硬件兼容性说明

## 1. 当前发布范围

当前镜像只在以下组合上完成实机验证：

| 项目 | 已验证值 |
| --- | --- |
| 设备 | Redmi Turbo 4 / `rodin` / `24129RT7CC` |
| vendor 固件 | `OS3.0.303.0.WOJCNXM` |
| kernel ABI | `6.6.77-android15-8-g358a69b2ec0f-4k` |
| 触摸控制器 | Goodix 已验证；FocalTech 等价手工修复已实机验证 |
| vendor_boot | 303 固件 header v4、DTB、type-1 platform fragment |

不要把该镜像标记为“全版本通用”。建议发布文件名包含：

```text
rodin-OrangeFox-OS3.0.303.0-WOJCNXM-dual-touch.img
```

从新源码首次重放 patch 后、尚未完成回归测试的构建应标记为测试版，例如：

```text
rodin-OrangeFox-OS3.0.303.0-WOJCNXM-dual-touch-test.img
```

界面中显示的“3.0.303”不足以确认兼容性，必须比较完整 vendor fingerprint、kernel ABI 和触摸控制器。

## 2. 为什么 3.0.4.0 不能直接使用

最终 IMG 内置了 303 固件的以下内容：

- stock DTB 和 vendor_boot header/cmdline。
- 精简后的 303 type-1 platform ramdisk。
- 244 个与 303 kernel ABI 匹配的 stock 模块。
- 303/Android 16 触摸模块和用户态 HAL。
- 303 vendor 基线的 KeyMint、Gatekeeper、Weaver、secure-element 和 TA。

新固件可能同时更新 kernel、DTB、vendor ramdisk、vendor_dlkm、SELinux、HAL 或 TA。混用后可能在 ADB 出现前重启、回落到官方 Recovery，或者正常系统无法启动。

要支持 `3.0.4.0`，应从该版本重新提取一整套输入并生成独立镜像，不能只替换版本字符串或单个 `vendor_boot`。

## 3. 同为 303 但没有触摸

已从 303 `vendor_dlkm` 确认 rodin 同时提供两套触摸驱动：

```text
goodix_core_rodin.ko
focaltech_touch_rodin.ko
```

Goodix 和使用等价手工修复的 FocalTech 路径均已有实机触控结果。设备树包含 `focaltech_touch_rodin.ko`、`libtouchreport_alg_fts.so` 和 FTS 配置；自动应用脚本会在编译前验证这些文件及全部加载入口。新源码重放已经通过干净 worktree 测试，但其第一次最终构建仍应在 FocalTech 设备上做一次启动、触摸和系统重启回归。

FocalTech 模块同样调用 SCP reserved-memory 和 IPI 接口，不能原样装入 Recovery。当前补丁将其 6 个 SCP helper 替换为 recovery-only `return 0`，保持 AP SPI、IRQ 和 THP 路径；patched 模块 SHA-256 为 `da967ce3f94ecc81153ee91f7e06a2b48eda0526b857688016ef660844bc70b2`。

stock 系统会同时加载 Goodix 和 FocalTech 两个模块，因此 `/proc/modules` 只能证明驱动可用，不能证明实际绑定了哪一个。应检查 SPI driver symlink、input 名称和 probe 日志：

```bash
adb shell su -c '
for dev in /sys/bus/spi/devices/*; do
  echo "--- $dev"
  cat "$dev/modalias" 2>/dev/null
  readlink -f "$dev/driver" 2>/dev/null
done
for name in /sys/class/input/input*/name; do
  printf "%s: " "$name"
  cat "$name" 2>/dev/null
done'

adb shell su -c \
  'dmesg | grep -iE "TP is|goodix|focaltech|fts_ts|touch-spi" | tail -300'
```

若 driver/input/probe 显示 FocalTech，应核对最终 IMG 来自通过 preflight 的完整设备树，并收集 Recovery 中的 module probe、input 和 TouchReport 日志。新源码产物完成触摸、FBE、系统重启验证前不要作为稳定版发布。

## 4. “自动进入官方 Recovery”的排查顺序

1. 确认对方 Bootloader 确实已解锁，而不只是能进入 fastboot。
2. 核对对方收到的 IMG SHA-256，排除传输或重命名错误。
3. 记录 `fastboot getvar current-slot`，只刷当前槽位。
4. 刷完立即 `fastboot reboot recovery`，不要先进入系统，避免系统恢复 stock 镜像干扰判断。
5. 记录设备是直接进入官方 Recovery、先重启一次后进入，还是先进入系统后才恢复官方 Recovery。
6. 若 OrangeFox 从未出现 ADB，收集 pstore；无法取得 pstore时，需要该固件的 stock 分区输入做离线对比。

不要让测试者同时刷两个槽位，也不要让其刷 `vendor_ramdisk_recovery.cpio` 或 recovery-only 中间镜像。

## 5. 收集兼容性报告

设备处于 OrangeFox/TWRP 且有 ADB 时，在主机源码根目录执行：

```bash
device/xiaomi/rodin/tools/collect-compat-report.sh
```

也可以把待核对的 IMG 作为第二个参数：

```bash
device/xiaomi/rodin/tools/collect-compat-report.sh \
  rodin-report \
  out/target/product/rodin/OrangeFox-R12.0-Unofficial-rodin-system-compatible.img
```

脚本只执行读取操作，不解密 `/data`、不修改分区、不刷机。报告可能包含序列号、fingerprint 和日志，公开上传前应检查隐私信息。

## 6. 为新固件制作版本

至少收集以下同一槽位、同一 OTA 版本的输入：

- `boot`、`init_boot`、`vendor_boot`、`dtbo`。
- `vendor_dlkm`、`odm_dlkm` 和相关模块元数据。
- vendor/odm 中的触摸 HAL、配置和固件。
- KeyMint、Gatekeeper、Weaver、secure-element、MiTEE TA 和依赖库。
- 完整 `ro.vendor.build.fingerprint`、kernel version 和测试设备触摸供应商。

每个固件基线应生成独立 blob 清单、独立最终 IMG 和独立测试记录。只有两个版本的 DTB、platform fragment、kernel ABI、模块及安全 HAL 全部确认兼容后，才可以考虑合并发布。
