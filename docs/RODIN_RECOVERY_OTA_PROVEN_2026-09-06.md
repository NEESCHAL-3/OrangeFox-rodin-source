# Rodin Recovery OTA — Proven Working

Date: 2026-09-06

## Proven image

SHA-256:

```
cb173af954a51bd7543d5a1e948236206fbe53284aeb72c618afa52b3cf9cc59
```

## Source commits

- system/core Virtual A/B recovery cleanup:
  `8852c2902`
- system/core adaptive recovery COW mapping:
  `f16d1d3fdd463571601dd01d526643cd0230aa43`
- bootable/recovery legacy decrypt watchdog fix:
  `7de2b5e1ddd0a90914e29268c23a2f40418eaec7`
- bootable/recovery sideload / OTA fix:
  `15587c4fe7fbfff2825ec7ba8754066949060e15`

## Tested OTA

Source recovery slot:

```
_b
```

OTA target:

```
_a
```

Package:

```
rodin_eea_global-ota_full-OS3.0.302.0.WOJEUXM-user-16.0-34303fcc4d.zip
```

ADB result:

```
Total xfer: 1.00x
```

Recovery updater result:

```
NEES_RUN_UPDATE_BINARY_RETURN=0
DownloadAction: ErrorCode::kSuccess
FilesystemVerifierAction: ErrorCode::kSuccess
PostinstallRunnerAction: ErrorCode::kSuccess
Update successfully applied, waiting to reboot.
```

## Virtual A/B result

Recovery successfully created all snapshots for target slot `_a`.

Physical/super-backed COWs continued using the normal dm path.

File-backed COW images successfully used loop devices for:

- product_a
- system_a
- system_dlkm_a
- system_ext_a
- vendor_a
- vendor_dlkm_a
- mi_ext_a

This avoids dm-linear EBUSY when recovery has userdata mounted directly on the physical block device.

## Boot verification

Device rebooted successfully into:

```
slot: _a
build: OS3.0.302.0.WOJEUXM
fingerprint:
POCO/rodin_eea/rodin:16/BP2A.250605.031.A3/OS3.0.302.0.WOJEUXM:user/release-keys

ro.virtual_ab.enabled=true
ro.virtual_ab.userspace.snapshots.enabled=true
```

This is the preserved known-good recovery OTA state.
