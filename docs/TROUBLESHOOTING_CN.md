# rodin OrangeFox 故障排查手册

## 1. 先判断卡在哪一层

| 屏幕/现象 | 主要层级 | 首选日志 |
| --- | --- | --- |
| 设备第一屏后重启，ADB 从未出现 | bootloader/kernel/first-stage ramdisk | pstore、stock header 对比 |
| OrangeFox splash 长时间不动，但 ADB 存在 | recovery userspace/HAL/GUI 初始化 | `/tmp/recovery.log`、logcat |
| 主界面出现但无触摸 | kernel touch + TouchReport | dmesg、getevent、touch properties |
| 输入密码一直等待 | KeyMint/Gatekeeper/Weaver/TEE | logcat、service list、TEE dmesg |
| 解密成功后 recovery 循环重启 | Recovery 进程崩溃 | pstore init service exit、tombstone |
| Recovery 正常但 Android 无法启动 | type-1 platform fragment 被破坏 | stock/platform 文件哈希对比 |

## 2. 设备首屏循环重启

检查：

```bash
adb shell 'ls /sys/fs/pstore'
adb pull /sys/fs/pstore logs/pstore
```

常见原因：

- vendor_boot header 地址、page size、DTB 或 cmdline 不匹配。
- combined vendor ramdisk 过大。
- 使用 zstd recovery fragment；rodin 实机测试在 ADB 前失败。
- OrangeFox 第二遍模块加载器拉起原始 `scp.ko`，在 `scp_region_info_init()` panic。
- 刷入了 recovery-only 中间 vendor_boot，而不是 system-compatible IMG。

## 3. splash 很久才进入界面

已知启动路径会同步执行：

- 两处约 1 秒固定等待。
- metadata-encrypted `/data` 映射和 `fsck.f2fs`。
- DE key 初始化。
- 分区枚举和 `/data` backup size 计算。
- OrangeFox XML、语言和字体资源加载。

触摸等待通常只有约 0.1 秒，不是主要瓶颈。约 4 至 6 秒 splash 可解释；明显更长时记录带时间戳的 logcat。

## 4. 无触摸

先确认控制器供应商。stock 系统可能同时加载 Goodix 和 FocalTech 模块，必须以 SPI driver symlink、input 名称或 probe 日志为准。Goodix 已实机验证；FocalTech 为待验证测试路径，参见 [COMPATIBILITY_CN.md](COMPATIBILITY_CN.md)。

```bash
adb shell getprop vendor.touch.modules.ready
adb shell getprop vendor.touch.service.ready
adb shell 'cat /sys/devices/virtual/touch/touch_dev/enable_touch_raw'
adb shell 'getevent -pl | grep -A25 -E "goodix_ts|focaltech_ts|fts_ts"'
adb shell 'dmesg | grep -iE "goodix|focaltech|fts_ts|touch|scp|11011800" | tail -300'
```

期望：

- `vendor.touch.modules.ready=1`。
- `vendor.touch.service.ready=1`。
- 存在 `goodix_ts`、`focaltech_ts` 或 `fts_ts` input device。
- TouchReport 进程运行并持续处理 raw frames。

只看到 input device 并不代表触摸可用。rodin 使用 THP raw-frame 路径，需要 Android 16 TouchReport 算法把坐标写回 `/dev/xiaomi-touch`。

## 5. FBE 卡住

```bash
adb shell 'service list | grep -E "keymint|gatekeeper|weaver|keystore"'
adb shell 'ps -A | grep -E "tee-supplicant|keymint|gatekeeper|weaver|secure_element|keystore2"'
adb logcat -b all -d | grep -iE 'keymint|gatekeeper|weaver|keystore2|mitee|optee|tee'
```

关键判断：

- `keystore2` 等不到 KeyMint：检查 VINTF 和 KeyMint service。
- `auth ca name error`：HAL 从错误路径启动，必须使用原始 `/vendor/bin/hw`。
- `optee_open_session()` 阻塞/失败：检查 TA、TEE 节点权限和 persist。
- synthetic password 到 Weaver 后阻塞：检查 NXP Weaver、secure-element、OMAPI、`nxp_i2c.ko`、`p73.ko`。
- user 0 成功而 user 999 失败：通常不影响主用户 `/data` 解密。

命令行测试：

```bash
adb shell 'twrp decrypt "你的密码" 0'
```

不要把真实密码写入永久日志或 shell history。

## 6. 解密后崩溃

已确认的 rodin 原因不是 FBE mount 失败，而是 OrangeFox 在发现：

```text
/data/media/0/Fox/.theme
/data/media/0/Fox/.navbar
```

后执行完整 `PageManager::RequestReload()`，Recovery 进程收到 `SIGSEGV`。设备 patch 定义 `OF_SKIP_POST_DECRYPT_THEME_RELOAD`，只跳过这次 late full-package reload。

诊断时可先做可逆重命名，禁止删除：

```bash
adb shell 'mv /data/media/0/Fox/.theme /data/media/0/Fox/.theme.disabled-test 2>/dev/null || true'
adb shell 'mv /data/media/0/Fox/.navbar /data/media/0/Fox/.navbar.disabled-test 2>/dev/null || true'
```

## 7. MiSans 导致全局卡顿

```bash
adb shell 'top -b -n 1 | head -20'
adb shell 'file /twres/fonts/MiSans.ttf'
```

如果字体实际为 CFF OpenType，旧 FreeType/Pixelflinger 路径会持续高 CPU。当前设备树要求 TrueType `glyf` 子集，预检脚本会拒绝 CFF 版本。

另外检查 `minuitwrp/truetype.cpp` patch 是否存在。原始 string cache 在 400 项时使用错误的 `||` 条件整批清空，文件列表会反复重新光栅化文本。

## 8. 截屏后进入电源菜单

原因是截屏渲染耗时超过长按阈值后，组合键 repeat 被转换成 `hkey=power`。设备 patch 在组合键激活期间禁止 key repeat，并在截屏后重置计时。

截图保存位置：

```text
/data/media/0/Fox/screenshots/
```

## 9. 解密前英文、解密后中文

`TW_DEFAULT_LANGUAGE=zh_CN` 只设置 DataManager 默认值。OrangeFox 原流程会先用英文加载 UI，并在解密页面退出后才调用 `LoadLanguage()`。

设备 patch 使用 `OF_LOAD_DEFAULT_LANGUAGE_BEFORE_DECRYPT`，在第一次 `Decrypt_Page()` 前加载 `zh_CN`。如果仍是英文，检查编译命令中是否同时存在：

```text
-DTW_DEFAULT_LANGUAGE=zh_CN
-DOF_LOAD_DEFAULT_LANGUAGE_BEFORE_DECRYPT=1
```

## 10. Recovery 正常但系统无法启动

必须确认最终刷入的是 `OrangeFox-...-system-compatible.img`。正常 Android boot 只选择 type-1 platform fragment；它必须保留 stock first-stage init、linker、libc、fstab、SELinux、firmware 和全部 244 个模块。

立即回退：

```bash
fastboot flash vendor_boot device/xiaomi/rodin/prebuilt/vendor_boot_stock.img
fastboot reboot
```

不要在未确认原因前刷另一槽位。

## 11. 最小日志包

```bash
LOGDIR="logs/$(date +%F-%H%M%S)"
mkdir -p "$LOGDIR"
adb pull /tmp/recovery.log "$LOGDIR/recovery.log"
adb logcat -b all -d > "$LOGDIR/logcat.txt"
adb shell dmesg > "$LOGDIR/dmesg.txt"
adb shell getprop > "$LOGDIR/getprop.txt"
adb pull /sys/fs/pstore "$LOGDIR/pstore" || true
```

记录测试镜像 SHA-256、当前槽位、系统版本、是否解密、是否存在 ADB，以及屏幕停在哪一层。没有这些信息时不要同时修改多个变量。
