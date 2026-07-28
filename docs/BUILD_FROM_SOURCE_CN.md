# Redmi Turbo 4 (rodin) OrangeFox 从源码构建手册

本文面向 Redmi Turbo 4（`rodin`、MT6899/天玑 8400 Ultra、A/B、Virtual A/B、Android 16 HyperOS）。目标产物是能够进入 Recovery，同时不破坏正常 Android 启动的完整 `vendor_boot.img`。

## 1. 先明确“只有源码”的边界

只有通用 OrangeFox 源码不能直接生成可用的 rodin 镜像。至少还需要：

- rodin 设备树 `device/xiaomi/rodin`。
- 当前系统配套的 stock `vendor_boot`、DTB、DTBO 和内核。
- Android 16 触摸模块、TouchReport HAL、配置和依赖库。
- Android 15 vendor 基线中的 MiTEE KeyMint、Gatekeeper、Weaver、secure-element、TA 和依赖库。
- 与当前 vendor/vendor_dlkm 完全匹配的内核模块。

这些文件是设备/固件相关输入，不能由 OrangeFox 编译器凭空生成。最可靠的方法是把已经验证的设备树连同 `prebuilt/` 和 `proprietary/` 一起版本化备份。

设备树提供完整 blob 校验清单。放置设备树后可先执行：

```bash
sha256sum --check --quiet \
  device/xiaomi/rodin/manifests/device-blobs.sha256
```

迁移前建议从 OrangeFox 源码根目录归档完整设备树，不要只保存 `.mk` 文件：

```bash
tar --zstd -cpf rodin-device-tree-$(date +%F).tar.zst \
  device/xiaomi/rodin
sha256sum rodin-device-tree-*.tar.zst
```

## 2. 已验证的基线

| 项目 | 值 |
| --- | --- |
| OrangeFox 分支 | `fox_14.1` |
| `bootable/recovery` 基线 | `fd98f33a722bd0bd52034f170bb91e2862654d6b` |
| `build/make` 基线 | `506df226dd003a364916b6b3ee1eb3bf9064f97f` |
| `vendor/recovery` 基线 | `0d7959e6538db5ddfff892cf7dfe207c68b0b753` |
| 设备 | Redmi Turbo 4 / `rodin` / `24129RT7CC` |
| SoC | MT6899 |
| vendor 基线 | `OS3.0.303.0.WOJCNXM`，Android 15/API 35 |
| 当前 system | Android 16 HyperOS |
| 触摸批次 | Goodix 已验证；FocalTech 等价手工修复已实机验证 |
| vendor_boot | header v4，64 MiB，type-1 platform + type-2 recovery |
| ramdisk 压缩 | 两个 fragment 都使用 LZ4 legacy |
| 屏幕 | `1220x2712` |

更换固件后不要只替换单个模块。stock `vendor_boot`、DTB、DTBO、vendor ramdisk、vendor_dlkm 模块、HAL 和 TA 应当作为一组重新提取和验证。

此基线覆盖已验证的 303 Goodix/FocalTech 批次，但不能作为跨固件或未知硬件 revision 的通用包发布。兼容性边界和报告采集方法见 [COMPATIBILITY_CN.md](COMPATIBILITY_CN.md)。

## 3. 主机准备

建议使用原生 Linux。24 GiB 内存的机器应准备至少 12 GiB swap，并给源码和 `out/` 预留 150 GiB 以上空间。

Ubuntu/Debian 常用依赖：

```bash
sudo apt update
sudo apt install -y \
  bc bison build-essential ccache curl flex g++-multilib gcc-multilib \
  git gnupg gperf imagemagick lib32ncurses-dev lib32readline-dev \
  lib32z1-dev libelf-dev liblz4-tool libncurses-dev libssl-dev \
  libxml2 libxml2-utils lz4 pngcrush ripgrep rsync schedtool squashfs-tools \
  unzip xsltproc zip zlib1g-dev
```

`ripgrep` 只用于加速构建前搜索；预检脚本在没有 `rg` 时会自动回退到 `grep`。

不要在空间不足的根分区构建。Soong 生成构建图时会出现短时高内存峰值。

## 4. 获取 OrangeFox 14.1

```bash
mkdir -p ~/orangefox
cd ~/orangefox
git clone https://gitlab.com/OrangeFox/sync.git ofox-sync
./ofox-sync/orangefox_sync.sh --branch 14.1 --path "$PWD/fox_14"
cd fox_14
```

确认：

```bash
test -f build/envsetup.sh
git -C bootable/recovery rev-parse HEAD
```

如果 `bootable/recovery` 已偏离上述基线，设备 patch 可能需要手动 rebase，不能强行 `git apply`。

## 5. 放置设备树并应用 Fox 源码 patch

将完整 rodin 设备树放到：

```text
device/xiaomi/rodin
```

设备树包含两份 OrangeFox 共享源码 patch，以及一份可移植的设备树修复 patch：

- `orangefox-build-make.patch`：OrangeFox 14.1 标准构建桥接，负责调用 `vendor/recovery/OrangeFox_A14.sh`。官方 vendor 克隆流程通常已经应用，脚本会自动跳过。
- `orangefox-recovery.patch`：本设备实测所需的 recovery 共享源码修复。
- `rodin-fbe-global.patch`：针对本设备树初始快照的 FBE/OMAPI/Weaver 修复及 CN/Global 构建 profile。它不包含 Global 固件二进制输入，应用方法和变更说明见 [DEVICE_TREE_PATCHES_CN.md](DEVICE_TREE_PATCHES_CN.md)。

recovery patch 包含：

- MiSans fallback、TrueType 文本缓存和文件列表性能修复。
- `音量- + 电源` 截屏组合键及长按电源冲突修复。
- rodin 解密后禁止完整 GUI package 重建，避免 recovery `SIGSEGV`。
- 解密页面显示前加载默认简体中文。
- MiSans 主题选择项和 SIH6887 震动节点支持。

在干净源码中执行：

```bash
device/xiaomi/rodin/tools/apply-orangefox-patches.sh "$PWD"
```

脚本可重复运行。它会检查并应用两份 patch，从 OrangeFox 自带 `extra-languages` 安装 `es_ES`、`hu_HU`、`zh_CN` 和 `zh_TW`，保留、验证内置的 `ja_JP`，然后自动运行完整构建输入预检。预检默认要求 pinned manifest 中全部 660 个 repo 项目以及独立的 `vendor/recovery` 与已验证 revision 一致，并检查 FocalTech 模块、算法库、配置、模块元数据、init 链接和运行时加载项。

`RODIN_ALLOW_UNPINNED_SOURCE=1` 只用于主动移植到新 revision；它会跳过源码 revision 限制，但不会跳过 blob、FocalTech 资源和 patch 标记检查。普通重复构建不要设置。

如果 patch 因源码版本变化而不能应用，先把对应仓库恢复到表中的基线，或人工 rebase patch。不要使用 `git apply --reject` 后忽略冲突继续构建。

若拿到的是未包含 FBE/Global 修复的原始 rodin 设备树，在将该 patch 放在设备树外部后先做 dry-run：

```bash
patch -d device/xiaomi/rodin -p1 --dry-run < /path/to/rodin-fbe-global.patch
patch -d device/xiaomi/rodin -p1 < /path/to/rodin-fbe-global.patch
```

patch 成功后，Global profile 还必须导入对应固件 fragment；CN 默认 profile 不需要此步骤。

## 6. 准备 stock vendor_boot 输入

不要从网络上随便下载其他版本的 `vendor_boot`。优先使用当前系统 OTA/分区备份中提取的镜像。

所需固定文件：

```text
device/xiaomi/rodin/prebuilt/vendor_boot_stock.img
device/xiaomi/rodin/prebuilt/vendor_ramdisk00
device/xiaomi/rodin/prebuilt/dtb/mt6899-rodin.dtb
device/xiaomi/rodin/prebuilt/dtbo.img
device/xiaomi/rodin/prebuilt/kernel
```

用 Android 源码自带工具拆包：

```bash
PRODUCT_TMP=/tmp/rodin-stock-vendor-boot
rm -rf "$PRODUCT_TMP"
mkdir -p "$PRODUCT_TMP"

python3 system/tools/mkbootimg/unpack_bootimg.py \
  --boot_img device/xiaomi/rodin/prebuilt/vendor_boot_stock.img \
  --out "$PRODUCT_TMP"

ls -lh "$PRODUCT_TMP"
```

必须确认：

- header version 为 4。
- `vendor_ramdisk00` 是 unnamed type-1 platform fragment。
- DTB 大小和哈希与 stock 一致。
- cmdline 为 `bootopt=64S3,32N2,64N2 erofs.reserved_pages=64`。
- 分区大小为 67,108,864 字节。

当前已验证输入的哈希见 [prebuilt/README.md](../prebuilt/README.md)。

CN 是默认 profile。Global OS3.0.301.0.WOJMIXM 必须选择它自己的 type-1
platform fragment；不要把默认 CN 成品刷入 Global 系统。

从完整 Global 固件包填充该 fragment：

```bash
device/xiaomi/rodin/tools/import-global-firmware-inputs.sh \
  /path/to/rodin_global_images_OS3.0.301.0.WOJMIXM_16.0/images/vendor_boot.img
```

脚本只接受已验证的 Global 3.0.301 `vendor_boot.img`，并检查整镜像、type-1
fragment 和 DTB 哈希。不要手工复制或复用其他 release 的 244 个内核模块。

## 7. 为什么不能直接使用普通 vendorbootimage

rodin 的正常系统启动依赖 stock type-1 platform ramdisk。普通 OrangeFox `vendorbootimage` 生成的是 recovery 中间布局，直接刷入可能导致 Recovery 可启动但 Android 无法启动。

本设备最终镜像必须包含：

1. 从 stock `vendor_ramdisk00` 精简得到的 type-1 platform fragment。
2. OrangeFox 生成的 named type-2 `recovery` fragment。
3. stock DTB、header 参数和 cmdline。
4. 64 MiB AVB hash footer。

`build-lowmem.sh` 会在 OrangeFox 编译成功后自动执行 `tools/build-system-compatible-vendor-boot.sh`。不要绕过该步骤。

## 8. 构建前预检

```bash
device/xiaomi/rodin/tools/verify-build-inputs.sh "$PWD"
```

预检会检查：

- `device.mk` 引用的文件是否齐全。
- stock 镜像尺寸和已知固件哈希。
- 全部 `prebuilt/`、`proprietary/`、`recovery/` 文件的 SHA-256 清单。
- patched SCP/Goodix/FocalTech 模块哈希。
- MiSans 是否为 TrueType `glyf` 版本。
- Fox recovery、build/make patch 标记和内置语言是否存在。
- 关键 shell 脚本语法。

哈希失败时先确认是否有意更换了完整固件基线。不要为了通过检查而盲目修改期望哈希。

## 9. 手动构建

```bash
cd /path/to/fox_14

export ALLOW_MISSING_DEPENDENCIES=true
export FOX_BUILD_DEVICE=rodin
export FOX_AB_DEVICE=1
export FOX_VIRTUAL_AB_DEVICE=1
export OF_FORCE_PREBUILT_KERNEL=1

OF_BUILD_JOBS=16 GOMEMLIMIT=12GiB \
  device/xiaomi/rodin/build-lowmem.sh vendorbootimage
```

Global OS3.0.301.0.WOJMIXM 使用：

```bash
RODIN_FIRMWARE_VARIANT=global OF_BUILD_JOBS=16 GOMEMLIMIT=12GiB \
  device/xiaomi/rodin/build-lowmem.sh vendorbootimage
```

低内存机器可以把 `OF_BUILD_JOBS` 降到 `1` 或 `2`。构建过程中不要清理 `/tmp`，也不要删除 `out/target/product/rodin/recovery`。

成功后只使用：

```text
out/target/product/rodin/OrangeFox-R12.0-Unofficial-rodin-system-compatible.img
```

Global profile 的命名成品为：

```text
out/target/product/rodin/OrangeFox-R12.0-Unofficial-rodin-global-system-compatible.img
```

不要刷生成过程中的：

- `vendor_ramdisk_recovery.cpio`
- `recovery.cpio.lz4`
- 后处理前的 recovery-only `vendor_boot.img`
- OrangeFox 自动生成的 installer ZIP

后处理脚本会删除不安全的 ZIP，并用 system-compatible IMG 覆盖标准 IMG 名称。

## 10. 离线校验

```bash
PRODUCT=out/target/product/rodin
IMG="$PRODUCT/OrangeFox-R12.0-Unofficial-rodin-system-compatible.img"

stat -c '%s %n' "$IMG"
sha256sum "$IMG"
out/host/linux-x86/bin/avbtool verify_image --image "$IMG"
```

尺寸必须为 `67108864`。

进一步拆包：

```bash
VERIFY=/tmp/rodin-release-verify
rm -rf "$VERIFY"
mkdir -p "$VERIFY"

python3 system/tools/mkbootimg/unpack_bootimg.py \
  --boot_img "$IMG" --out "$VERIFY"

out/host/linux-x86/bin/lz4 -t "$VERIFY/vendor_ramdisk00"
out/host/linux-x86/bin/lz4 -t "$VERIFY/vendor_ramdisk01"
file "$VERIFY/vendor_ramdisk00" "$VERIFY/vendor_ramdisk01"
```

期望结果：

- `vendor_ramdisk00`：type-1 platform，244 个 stock 模块。
- `vendor_ramdisk01`：type-2，name=`recovery`，最多 7 个补充模块。
- 两者都是 LZ4 legacy。
- combined vendor ramdisk 小于 60,000,000 字节。
- platform fragment 的 `/system/etc/vintf/manifest` 下没有 recovery device manifest。

## 11. 安全刷写与回退

不要让自动脚本刷机。先确认 fastboot 设备：

```bash
fastboot devices
fastboot getvar current-slot
```

rodin fastboot 能按当前槽位解析 `vendor_boot`，不需要手写 `_a`/`_b`：

```bash
fastboot flash vendor_boot \
  out/target/product/rodin/OrangeFox-R12.0-Unofficial-rodin-system-compatible.img
fastboot reboot recovery
```

首次只测试当前槽位，不要同时刷两个槽位。不要使用 `fastboot flash vendor_boot:recovery`；该设备 fastbootd 不支持所需的 `fetch` read-modify-write 流程。

回退：

```bash
fastboot flash vendor_boot device/xiaomi/rodin/prebuilt/vendor_boot_stock.img
fastboot reboot
```

## 12. 首次实机测试顺序

1. Recovery 能越过设备首屏和 OrangeFox splash。
2. `adb devices` 能看到 `recovery`。
3. 默认解密页为简体中文。
4. 输入锁屏凭据，确认 user 0 解密成功。
5. 确认 `/data` 为 f2fs、读写挂载。
6. 测试触摸 DOWN/move/UP、文件列表滑动和 MiSans 性能。
7. 测试震动和 `音量- + 电源` 截屏。
8. 测试 ADB sideload、MTP、fastbootd。
9. 最后从 Recovery 重启 Android，确认系统正常启动。

任何阶段出现循环重启，先回 fastboot 恢复 stock `vendor_boot`，再收集 pstore，不要连续盲刷多个变体。

## 13. 日志采集

Recovery 仍有 ADB 时：

```bash
mkdir -p logs/manual-test
adb pull /tmp/recovery.log logs/manual-test/recovery.log
adb logcat -b all -d > logs/manual-test/logcat.txt
adb shell dmesg > logs/manual-test/dmesg.txt
adb shell 'getprop' > logs/manual-test/getprop.txt
```

重启或崩溃后：

```bash
adb shell 'ls -la /sys/fs/pstore'
adb pull /sys/fs/pstore logs/manual-test/pstore
```

故障分类和关键日志模式见 [TROUBLESHOOTING_CN.md](TROUBLESHOOTING_CN.md)。
