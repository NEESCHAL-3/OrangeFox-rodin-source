# rodin 可移植备份说明

## 必须保留

完整保留以下目录，不要只挑选 `.mk` 文件：

```text
device/xiaomi/rodin
```

其中最关键的内容是：

- `prebuilt/`：303 stock vendor_boot、platform ramdisk、DTB、DTBO 和 kernel。
- `proprietary/`：触摸、FBE、MiTEE、Weaver、secure-element、震动和字体文件。
- `recovery/`：ramdisk、init、fstab、模块、固件和模块元数据。
- `patches/`：对 `bootable/recovery` 和 `build/make` 的源码 patch。
- `tools/`：应用 patch、输入预检、触摸模块 patch 和最终 vendor_boot 后处理脚本。
- `manifests/device-blobs.sha256`：全部设备 blob 的 SHA-256 清单。
- 根目录的 `BoardConfig.mk`、`device.mk`、产品 mk、callback 和构建脚本。

`manifests/orangefox-fox_14.1-pinned.xml` 是当前 660 个 repo 项目的精确 revision 记录，SHA-256 为：

```text
c34315d68bdcc526fc69f4f895920d8037389bcb357ba6f3cdfcea3c247c81ce
```

OrangeFox vendor tree 不在 repo manifest 中，当前来源是：

```text
https://gitlab.com/OrangeFox/vendor/recovery.git
0d7959e6538db5ddfff892cf7dfe207c68b0b753
```

## 不需要保留

以下内容不是以后重新构建所必需的：

- 整个 `fox_14/out/`。
- 整个 `fox_14/.repo/` 和其他通用 Android 源码。
- `orangefox_rodin/tmp/`、`logs/`、原始 `rodin_part/`。
- 设备树外单独保存的 `vendor_boot.img`。
- 原始完整 MiSans 仓库；设备树已经包含实际使用的 recovery 子集。

原始分区 dump 对升级固件或重新移植有帮助，但对重复构建当前 303 版本不是必需输入。

## 建议归档方式

在 OrangeFox 源码根目录执行：

```bash
tar --zstd -cpf /安全位置/rodin-device-tree-$(date +%F).tar.zst \
  device/xiaomi/rodin
sha256sum /安全位置/rodin-device-tree-*.tar.zst
```

设备树约 174 MiB，并包含设备专有二进制和字体。公开上传前应检查 Xiaomi 固件与 MiSans 的再分发许可；更适合私有仓库或本地备份。

## 下次恢复构建

同步 OrangeFox 14.1 并克隆 vendor tree 后，在新源码根目录解压：

```bash
tar --zstd -xpf /安全位置/rodin-device-tree-YYYY-MM-DD.tar.zst

device/xiaomi/rodin/tools/apply-orangefox-patches.sh "$PWD"
```

应用脚本会自动执行 `verify-build-inputs.sh`，包括 pinned manifest 中全部 660 个源码 revision、独立 vendor tree 和 FocalTech 完整资源链检查。也可以在编译前再次单独运行预检。

然后手动构建：

```bash
export ALLOW_MISSING_DEPENDENCIES=true
export FOX_BUILD_DEVICE=rodin
export FOX_AB_DEVICE=1
export FOX_VIRTUAL_AB_DEVICE=1
export OF_FORCE_PREBUILT_KERNEL=1

OF_BUILD_JOBS=16 GOMEMLIMIT=12GiB \
  device/xiaomi/rodin/build-lowmem.sh vendorbootimage
```

如果未来 OrangeFox 14.1 分支已经更新并导致 patch 不能应用，先根据 pinned manifest 中的 revision 对比源码，不要使用 `git apply --reject` 忽略冲突。
