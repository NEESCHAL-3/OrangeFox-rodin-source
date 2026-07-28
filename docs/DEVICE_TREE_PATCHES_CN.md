# rodin 设备树补丁说明

## 范围

`patches/rodin-fbe-global.patch` 是针对本仓库初始 rodin 设备树快照的文本补丁。它补齐了 FBE 所需的 recovery 依赖和 Global 固件构建 profile；不替换 OrangeFox 共享源码 patch，也不携带任何 firmware blob。

补丁涉及：

- `Android.bp`：将 Android 15 vendor 的 secure-element 与 OMAPI NDK 预编译库改为 recovery 专用模块名，保留 Android 16 构建图中的 AIDL 生成头文件，并让 `rodin_omapi_bridge` 显式链接 `librodin_libcxx_compat`。
- `recovery/root/init.recovery.keymint.rc`：为 OMAPI bridge 设置 vendor/system 运行时库搜索路径和 libc++ compatibility preload；在 `tee-supplicant` 就绪后并行启动 KeyMint、secure-element 与 NXP Weaver，不再以 bridge ready 属性阻塞 Weaver。
- `tools/build-system-compatible-vendor-boot.sh`：增加 `RODIN_FIRMWARE_VARIANT=cn|global`，使最终镜像保留与目标系统相匹配的 type-1 platform ramdisk。
- 构建前检查、文件哈希清单和构建文档。

这份补丁解决两个已定位的问题：原先 Soong 会把设备树中 Android 15 预编译 NDK 库与 Android 16 AIDL 生成模块混淆，导致 recovery 依赖解析失败；运行时的 bridge 则因找不到 `/vendor/lib64` 内的 NDK 库而无法启动，使 Weaver 被错误的 ready gate 无限阻塞。它们分别影响可编译性和 FBE synthetic-password 流程。

## 应用

先保存完整设备树和现有工作，再在 OrangeFox 源码根目录执行。补丁文件必须在目标设备树外部，因为应用前目标树中尚不存在该文件。

```bash
PATCH=/path/to/rodin-fbe-global.patch
patch -d device/xiaomi/rodin -p1 --dry-run < "$PATCH"
patch -d device/xiaomi/rodin -p1 < "$PATCH"
```

只对与本项目初始快照相同的设备树直接应用。若 `--dry-run` 有上下文冲突，不要使用 `.rej` 继续构建；先按各文件的功能块人工 rebase，并重新运行完整预检。

应用后仍按常规方式执行：

```bash
device/xiaomi/rodin/tools/apply-orangefox-patches.sh "$PWD"
```

该脚本继续负责 `build/make` 和 `bootable/recovery` 的两个 Git patch；`rodin-fbe-global.patch` 只修改设备树，不能由该脚本对非 Git 设备目录自动应用。

## Global 固件输入

Global OS3.0.301.0.WOJMIXM 的 244 个 type-1 platform 内核模块与 CN OS3.0.303.0.WOJCNXM 不同。两者 DTB、fstab、first-stage init、SELinux 数据和 type-2 stock recovery fragment 相同，但 type-1 fragment 不能交叉使用。

补丁不包含 29,235,080 字节的 `prebuilt/global/vendor_ramdisk00`。从完整 Global 固件包导入：

```bash
device/xiaomi/rodin/tools/import-global-firmware-inputs.sh \
  /path/to/rodin_global_images_OS3.0.301.0.WOJMIXM_16.0/images/vendor_boot.img
```

导入器固定校验以下值，失败时不会覆盖现有输入：

| 项目 | 值 |
| --- | --- |
| Global `vendor_boot.img` 大小 | `67108864` |
| Global `vendor_boot.img` SHA-256 | `72b8ae7637af1924de8312855790de91f99abbc9c8c8ab6003ddce14abc4d956` |
| type-1 fragment 大小 | `29235080` |
| type-1 fragment SHA-256 | `349cc6598f70ae401afe3071abed6de00815af39c5aded3551cff23364208731` |
| DTB SHA-256 | `38369239c984fc191e36d043d19ccbea4c1cd09ee6c80f8646d9493f650a30ae` |

然后使用：

```bash
RODIN_FIRMWARE_VARIANT=global OF_BUILD_JOBS=16 GOMEMLIMIT=12GiB \
  device/xiaomi/rodin/build-lowmem.sh vendorbootimage
```

CN 3.0.303 默认不设置 `RODIN_FIRMWARE_VARIANT`。两个 profile 都必须先通过：

```bash
RODIN_FIRMWARE_VARIANT=global \
  device/xiaomi/rodin/tools/verify-build-inputs.sh "$PWD"
```

Global 输出为 `OrangeFox-R12.0-Unofficial-rodin-global-system-compatible.img`，不能用于 CN；默认 CN 输出也不能用于 Global。
