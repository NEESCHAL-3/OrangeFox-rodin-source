# rodin 固件文件来源与移植说明

## 1. 原则

`prebuilt/` 和 `proprietary/` 不是可随意互换的素材库。它们共同描述一个固件 ABI：内核符号 CRC、模块依赖、AIDL/NDK 版本、MiTEE TA、RPMB 访问方式和 VINTF 声明必须匹配。

升级固件时建议建立新的提取目录，完成离线对比和实机验证后再替换设备树中的文件。始终保留已知可启动的 stock `vendor_boot_stock.img`。

当前全部 blob 的校验值保存在 `manifests/device-blobs.sha256`。有意更新固件文件后必须重新生成清单，并同时更新 `tools/verify-build-inputs.sh` 中用于启动、触摸和字体的关键固定哈希；不能只让预检跳过失败。

## 2. prebuilt 文件

| 设备树文件 | 原始来源 | 用途 |
| --- | --- | --- |
| `prebuilt/vendor_boot_stock.img` | 当前槽位 stock `vendor_boot` | 正常启动基线、DTB/platform ramdisk 来源、回退镜像 |
| `prebuilt/vendor_ramdisk00` | stock vendor_boot 的 unnamed type-1 fragment | 最终 system-compatible platform fragment 的唯一输入 |
| `prebuilt/dtb/mt6899-rodin.dtb` | stock vendor_boot DTB | MT6899 硬件描述 |
| `prebuilt/dtbo.img` | 当前固件 `dtbo` | boot overlay |
| `prebuilt/kernel` | 当前固件 boot/GKI kernel payload | 构建元数据和工具需要；Recovery 不把 kernel 塞入 vendor_boot |

不要把 reference TWRP 的 vendor_boot 当作正常系统 platform 基线。参考镜像只能用于观察 ramdisk 布局、模块列表和启动参数。

## 3. 触摸文件

| 文件组 | 典型来源 | 说明 |
| --- | --- | --- |
| `recovery/root/lib/modules/goodix_core_rodin.ko` | Android 16 vendor ramdisk/vendor_dlkm | AP 侧 Goodix 驱动，Recovery 专用 patch |
| `recovery/root/lib/modules/focaltech_touch_rodin.ko` | Android 16 vendor_dlkm | AP 侧 FocalTech 驱动，Recovery 专用 patch；等价手工修复已实机验证 |
| `recovery/root/lib/modules/xiaomi_touch_rodin.ko` | Android 16 vendor ramdisk/vendor_dlkm | Xiaomi touch 控制接口 |
| `recovery/root/lib/modules/scp.ko` | Android 16 vendor ramdisk/vendor_dlkm | 仅用于满足符号/依赖，Recovery 中禁止注册 SCP driver |
| `proprietary/odm/bin/hw/vendor.xiaomi.hw.touchfeature-service-recovery` | Android 16 ODM | THP raw frame 用户态服务 |
| `proprietary/odm/lib64/libtouchreport*.so` | Android 16 ODM | TouchReport HAL、算法和 sensor glue |
| `proprietary/odm/lib64/libtensorflowlite_touch_c.so` | Android 16 ODM | 触摸算法依赖 |
| `proprietary/odm/firmware/rodin_gtp_thp_config*.ini` | Android 16 ODM firmware | Goodix THP 配置 |
| `proprietary/touch/lib64/*` | Android 16 system/vendor/odm 依赖闭包 | 隔离到 `/system/lib64/rodin-touch`，避免污染 Recovery 全局 libc++ |

303 `vendor_dlkm` 同时提供 Goodix 和 FocalTech 驱动，ODM 也提供对应的两个 TouchReport 算法。FocalTech 的 6 个 SCP helper 已按与 Goodix 相同的原则禁用，AP SPI/IRQ/THP 路径保持不变；这条路径仍需 FocalTech 设备实测后才能标记为稳定。

不能直接加载原始 `scp.ko`。实机 pstore 已确认它会在缺少 SCP reserved-memory 的 Recovery 环境中于 `scp_region_info_init()` 触发 kernel panic。

补丁脚本只接受已知 stock/已知 patched 哈希：

```bash
device/xiaomi/rodin/tools/patch-recovery-touch-modules.sh
```

脚本修改固定 AArch64 指令偏移。固件更新导致哈希或偏移变化时，脚本会拒绝写入；此时必须重新反汇编和验证，不能删除哈希检查。

## 4. FBE 和安全服务

| 文件组 | 来源 | 约束 |
| --- | --- | --- |
| KeyMint/Gatekeeper service | Android 15 vendor `/vendor/bin/hw` | 必须保留原始 `/vendor/bin/hw` 运行路径，MiTEE 会认证 CA 名称 |
| `tee-supplicant`、`libteecli.so` | Android 15 vendor | 建立 TEE 会话 |
| Weaver service 和 `ese_weaver.nxp.so` | Android 15 vendor | synthetic password/Weaver |
| secure-element service、OMAPI/SE 库 | Android 15 vendor | 为 Weaver 建立 eSE 通路 |
| `vendor/mitee/ta/*.ta` | Android 15 vendor | UUID 必须与 HAL 请求完全一致 |
| `nxp_i2c.ko`、`p73.ko` | 当前 vendor_dlkm | eSE 设备通路 |
| VINTF fragment | Android 15 vendor | servicemanager 声明 |

`librodin_libcxx_compat.so` 只为 Android 15 proprietary HAL 补充较新的 libc++ verbose-abort 符号。不要用 Android 15 `libc++.so` 全局覆盖 OrangeFox Android 14 libc++。

`persist` 以 `ro,noload` 挂载，避免 Recovery 回放 ext4 journal 或写入安全存储。RPMB/UFS/TEE 节点只恢复 stock 所需权限。

## 5. 震动

`si_haptic.ko` 来自匹配 vendor_dlkm，目标设备为 I2C `0-006b`。模块不得放入 first-stage 加载列表；它在 TouchReport 就绪后延迟加载。loader 只加载模块，不主动触发震动。

不要因设备上存在 `aw8697_haptic.bin` 就假设马达是 AW8697。应以实际绑定驱动、I2C 节点和实机 pulse 测试为准。

## 6. 字体和语言

当前 `MiSans.ttf` 是从官方 `MiSans-Regular.ttf` 提取的 8,134-codepoint TrueType `glyf` 子集。不要使用 CFF OTF 子集伪装成 `.ttf`；实机静态 GUI 曾出现 recovery 主线程约 90% 单核占用。

语言文件来自 OrangeFox `common/languages` 和 `extra-languages`。当前保留英文、西班牙语、匈牙利语、日语、简体中文和繁体中文；默认语言在 `BoardConfig.mk` 中设置为 `zh_CN`，并在第一次解密页打开前显式加载。

Euclid Flex 与 Fira Code 的四个源码字体合计 335,216 字节。`fox_callback.sh` 在最终打包前已经删除它们；完整 cpio 对比显示这会减少约 202,951 字节的 LZ4 recovery fragment。源码字体继续保留给 OrangeFox 通用主题生成使用，不会进入 rodin 最终镜像。

`ja_JP.xml` 原始大小为 87,269 字节，加入后 LZ4 fragment 增加约 26,561 字节。双触摸与日语同时加入的模拟 combined vendor ramdisk 为 59,612,121 字节，距离 60,000,000 字节限制还剩 387,879 字节。

## 7. vendor_boot 大小控制

MT6899 在本设备上的可工作 combined vendor ramdisk 小于 60,000,000 字节。大小控制策略：

- platform fragment 保留正常启动必需 first-stage runtime、SELinux、firmware 和 244 个 stock 模块。
- recovery fragment 只保留 7 个补充/patch 模块。
- 两个 fragment 都使用 LZ4 legacy，不使用 zstd。
- 保留 terminal、minadbd、sideload、fastbootd 和 lptools。
- 删除 lpdump diagnostic stack、未使用语言/字体、mini debug data。
- 只对已验证白名单中的 Recovery 工具执行 UPX。

不要删除 init、linker、libc、servicemanager、adbd、安全 HAL 或正常启动 platform 文件来“碰运气”压缩。

## 8. 固件更新检查清单

1. 拆包新旧 stock vendor_boot，对比 header、DTB、cmdline 和 fragment 表。
2. 对比 `modules.load.recovery`、`modules.dep` 和全部模块哈希。
3. 重新确认 SCP reserved-memory 是否仍缺失。
4. 用 `readelf -d` 重新计算触摸和安全 HAL 的直接依赖闭包。
5. 对比 KeyMint/Gatekeeper/Weaver VINTF instance 名称。
6. 对比 TA UUID 和 HAL 中请求的 UUID。
7. 检查 fstab metadata encryption、fileencryption 和 keydirectory 参数。
8. 更新设备树哈希后先做 host-side validation。
9. 首次只刷当前槽位，并准备 stock vendor_boot 回退。
