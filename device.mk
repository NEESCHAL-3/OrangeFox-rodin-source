DEVICE_PATH := device/xiaomi/rodin

$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/launch_with_vendor_ramdisk.mk)

PRODUCT_DEVICE := rodin
PRODUCT_BRAND := Redmi
PRODUCT_MODEL := 24129RT7CC
PRODUCT_MANUFACTURER := Xiaomi
PRODUCT_NAME := omni_rodin

PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_USE_VIRTUAL_AB := true
PRODUCT_VIRTUAL_AB_OTA := true
PRODUCT_VIRTUAL_AB_COMPRESSION := true

# OrangeFox 14.1 is Android 14 based and only exposes SystemSDK up to 34.
# The supplied stock images report Android 15; OrangeFox 14.1 exposes
# SystemSDK up to 34, so keep the recovery build system at its supported API.
PRODUCT_SHIPPING_API_LEVEL := 34

PRODUCT_PROPERTY_OVERRIDES += \
    ro.product.device=rodin \
    ro.product.model=24129RT7CC \
    ro.product.brand=Redmi \
    ro.product.vendor.marketname=REDMI Turbo 4 \
    ro.board.platform=mt6899 \
    ro.boot.dynamic_partitions=true \
    ro.build.ab_update=true \
    ro.virtual_ab.enabled=true \
    ro.virtual_ab.userspace.snapshots.enabled=true \
    ro.virtual_ab.compression.enabled=true \
    ro.virtual_ab.io_uring.enabled=true \
    ro.crypto.metadata_init_delete_all_keys.enabled=true \
    ro.crypto.volume.filenames_mode=aes-256-cts \
    ro.recovery.usb.vid=18D1 \
    ro.recovery.usb.adb.pid=D001 \
    ro.recovery.usb.fastboot.pid=4EE0

PRODUCT_PACKAGES += \
    android.hardware.boot@1.0-impl-1.2-mtkimpl \
    android.hardware.boot@1.2-mtkimpl \
    android.hardware.boot@1.2-mtkimpl.recovery \
    android.hardware.health@2.1-impl \
    android.hardware.health@2.1-impl.recovery \
    android.hardware.health@2.1-service \
    android.hardware.health@2.1-service.rc \
    create_pl_dev \
    create_pl_dev.recovery \
    fastbootd \
    fsck.erofs \
    fsck.f2fs \
    lpdump \
    lpunpack \
    make_f2fs \
    rodin_omapi_bridge \
    snapuserd \
    snapuserd_ramdisk \
    librodin_libcxx_compat

PRODUCT_PACKAGES_DEBUG += \
    bootctrl \
    bootctl \
    logcat

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/recovery/root/init.recovery.hardware.rc:recovery/root/init.recovery.hardware.rc \
    $(DEVICE_PATH)/recovery/root/init.recovery.keymint.rc:recovery/root/init.recovery.keymint.rc \
    $(DEVICE_PATH)/recovery/root/init.recovery.mt6899.rc:recovery/root/init.recovery.mt6899.rc \
    $(DEVICE_PATH)/recovery/root/init.recovery.project.rc:recovery/root/init.recovery.project.rc \
    $(DEVICE_PATH)/recovery/root/system/bin/load-touch-modules.sh:recovery/root/system/bin/load-touch-modules.sh \
    $(DEVICE_PATH)/recovery/root/system/bin/wait-touch-service.sh:recovery/root/system/bin/wait-touch-service.sh \
    $(DEVICE_PATH)/recovery/root/system/bin/load-haptics-module.sh:recovery/root/system/bin/load-haptics-module.sh \
    $(DEVICE_PATH)/proprietary/fonts/MiSans.ttf:recovery/root/twres/fonts/MiSans.ttf \
    $(DEVICE_PATH)/proprietary/haptics/si_haptic.ko:recovery/root/lib/modules/si_haptic.ko \
    $(DEVICE_PATH)/proprietary/haptics/firmware/aw8697_haptic.bin:recovery/root/vendor/firmware/aw8697_haptic.bin \
    $(DEVICE_PATH)/recovery/root/lib/modules/scp.ko:recovery/root/lib/modules/scp.ko \
    $(DEVICE_PATH)/recovery/root/lib/modules/xiaomi_touch_rodin.ko:recovery/root/lib/modules/xiaomi_touch_rodin.ko \
    $(DEVICE_PATH)/recovery/root/lib/modules/goodix_core_rodin.ko:recovery/root/lib/modules/goodix_core_rodin.ko \
    $(DEVICE_PATH)/recovery/root/lib/modules/focaltech_touch_rodin.ko:recovery/root/lib/modules/focaltech_touch_rodin.ko \
    $(DEVICE_PATH)/proprietary/odm/bin/hw/vendor.xiaomi.hw.touchfeature-service-recovery:recovery/root/system/bin/vendor.xiaomi.hw.touchfeature-service-recovery \
    $(DEVICE_PATH)/proprietary/odm/lib64/libtouchreport.so:recovery/root/system/lib64/rodin-touch/libtouchreport.so \
    $(DEVICE_PATH)/proprietary/odm/lib64/libtouchreport_alg_goodix.so:recovery/root/system/lib64/rodin-touch/libtouchreport_alg_goodix.so \
    $(DEVICE_PATH)/proprietary/odm/lib64/libtouchreport_alg_fts.so:recovery/root/system/lib64/rodin-touch/libtouchreport_alg_fts.so \
    $(DEVICE_PATH)/proprietary/odm/lib64/libtouchreport_hal.so:recovery/root/system/lib64/rodin-touch/libtouchreport_hal.so \
    $(DEVICE_PATH)/proprietary/odm/lib64/libtouchreport_sensor.so:recovery/root/system/lib64/rodin-touch/libtouchreport_sensor.so \
    $(DEVICE_PATH)/proprietary/odm/lib64/libtensorflowlite_touch_c.so:recovery/root/system/lib64/rodin-touch/libtensorflowlite_touch_c.so \
    $(DEVICE_PATH)/proprietary/odm/firmware/rodin_gtp_thp_config.ini:recovery/root/system/etc/rodin-touch/rodin_gtp_thp_config.ini \
    $(DEVICE_PATH)/proprietary/odm/firmware/rodin_gtp_thp_config_vendor.ini:recovery/root/system/etc/rodin-touch/rodin_gtp_thp_config_vendor.ini \
    $(DEVICE_PATH)/recovery/root/vendor/firmware/rodin_fts_thp_config.ini:recovery/root/system/etc/rodin-touch/rodin_fts_thp_config.ini \
    $(DEVICE_PATH)/proprietary/touch/lib64/android.frameworks.sensorservice-V1-ndk.so:recovery/root/system/lib64/rodin-touch/android.frameworks.sensorservice-V1-ndk.so \
    $(DEVICE_PATH)/proprietary/touch/lib64/android.hardware.common-V2-ndk.so:recovery/root/system/lib64/rodin-touch/android.hardware.common-V2-ndk.so \
    $(DEVICE_PATH)/proprietary/touch/lib64/android.hardware.common.fmq-V1-ndk.so:recovery/root/system/lib64/rodin-touch/android.hardware.common.fmq-V1-ndk.so \
    $(DEVICE_PATH)/proprietary/touch/lib64/android.hardware.sensors-V2-ndk.so:recovery/root/system/lib64/rodin-touch/android.hardware.sensors-V2-ndk.so \
    $(DEVICE_PATH)/proprietary/touch/lib64/libc++.so:recovery/root/system/lib64/rodin-touch/libc++.so \
    $(DEVICE_PATH)/proprietary/touch/lib64/libmisight.so:recovery/root/system/lib64/rodin-touch/libmisight.so \
    $(DEVICE_PATH)/proprietary/touch/lib64/vendor.xiaomi.hw.touchfeature-V1-ndk.so:recovery/root/system/lib64/rodin-touch/vendor.xiaomi.hw.touchfeature-V1-ndk.so \
    $(DEVICE_PATH)/recovery/root/first_stage_ramdisk/fstab.emmc:recovery/root/first_stage_ramdisk/fstab.emmc \
    $(DEVICE_PATH)/recovery/root/first_stage_ramdisk/fstab.mt6899:recovery/root/first_stage_ramdisk/fstab.mt6899 \
    $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab:recovery/root/system/etc/recovery.fstab \
    $(DEVICE_PATH)/proprietary/vendor/bin/tee-supplicant:recovery/root/vendor/bin/tee-supplicant \
    $(DEVICE_PATH)/proprietary/vendor/bin/hw/android.hardware.gatekeeper-service.mitee:recovery/root/vendor/bin/hw/android.hardware.gatekeeper-service.mitee \
    $(DEVICE_PATH)/proprietary/vendor/bin/hw/android.hardware.security.keymint@3.0-service.mitee:recovery/root/vendor/bin/hw/android.hardware.security.keymint@3.0-service.mitee \
    $(DEVICE_PATH)/proprietary/vendor/bin/hw/android.hardware.weaver-service.nxp:recovery/root/vendor/bin/hw/android.hardware.weaver-service.nxp \
    $(DEVICE_PATH)/proprietary/vendor/bin/hw/vendor.xiaomi.hardware.secure_element-service:recovery/root/vendor/bin/hw/vendor.xiaomi.hardware.secure_element-service \
    $(DEVICE_PATH)/proprietary/vendor/mitee/ta/2e8fade5-0c7a-46cc-810e6468baee66b9.ta:recovery/root/vendor/mitee/ta/2e8fade5-0c7a-46cc-810e6468baee66b9.ta \
    $(DEVICE_PATH)/proprietary/vendor/mitee/ta/4d573443-6a56-4272-ac6f2425af9ef9bb.ta:recovery/root/vendor/mitee/ta/4d573443-6a56-4272-ac6f2425af9ef9bb.ta \
    $(DEVICE_PATH)/proprietary/vendor/mitee/ta/dba51a17-0563-11e7-93b16fa7b0071a51.ta:recovery/root/vendor/mitee/ta/dba51a17-0563-11e7-93b16fa7b0071a51.ta \
    $(DEVICE_PATH)/proprietary/vendor/lib64/android.hardware.secure_element@1.0.so:recovery/root/vendor/lib64/android.hardware.secure_element@1.0.so \
    $(DEVICE_PATH)/proprietary/vendor/lib64/android.hardware.secure_element@1.1.so:recovery/root/vendor/lib64/android.hardware.secure_element@1.1.so \
    $(DEVICE_PATH)/proprietary/vendor/lib64/android.hardware.secure_element@1.2.so:recovery/root/vendor/lib64/android.hardware.secure_element@1.2.so \
    $(DEVICE_PATH)/proprietary/vendor/lib64/libclang_rt.ubsan_standalone-aarch64-android.so:recovery/root/vendor/lib64/libclang_rt.ubsan_standalone-aarch64-android.so \
    $(DEVICE_PATH)/proprietary/vendor/lib64/android.hardware.secure_element-V1-ndk.so:recovery/root/vendor/lib64/android.hardware.secure_element-V1-ndk.so \
    $(DEVICE_PATH)/proprietary/vendor/lib64/android.hardware.weaver-V2-ndk.so:recovery/root/vendor/lib64/android.hardware.weaver-V2-ndk.so \
    $(DEVICE_PATH)/proprietary/vendor/lib64/android.se.omapi-V1-ndk.so:recovery/root/vendor/lib64/android.se.omapi-V1-ndk.so \
    $(DEVICE_PATH)/proprietary/vendor/lib64/ese_weaver.nxp.so:recovery/root/system/lib64/ese_weaver.nxp.so \
    $(DEVICE_PATH)/proprietary/vendor/lib64/libjc_keymint_transport.nxp.so:recovery/root/system/lib64/libjc_keymint_transport.nxp.so \
    $(DEVICE_PATH)/proprietary/vendor/lib64/libmemunreachable.so:recovery/root/system/lib64/libmemunreachable.so \
    $(DEVICE_PATH)/proprietary/vendor/lib64/libmigpese@2.0.so:recovery/root/system/lib64/libmigpese@2.0.so \
    $(DEVICE_PATH)/proprietary/vendor/lib64/libteecli.so:recovery/root/system/lib64/libteecli.so \
    $(DEVICE_PATH)/proprietary/vendor/lib64/vendor.xiaomi.hardware.aidl.mtdservice-V1-ndk.so:recovery/root/system/lib64/vendor.xiaomi.hardware.aidl.mtdservice-V1-ndk.so \
    $(DEVICE_PATH)/proprietary/vendor/etc/hal_uuid_map_rodin.xml:recovery/root/vendor/etc/hal_uuid_map_rodin.xml \
    $(DEVICE_PATH)/proprietary/vendor/etc/vintf/manifest/android.hardware.gatekeeper-service.mitee.xml:recovery/root/vendor/etc/vintf/manifest/android.hardware.gatekeeper-service.mitee.xml \
    $(DEVICE_PATH)/proprietary/vendor/etc/vintf/manifest/android.hardware.security.keymint-service.mitee.xml:recovery/root/vendor/etc/vintf/manifest/android.hardware.security.keymint-service.mitee.xml \
    $(DEVICE_PATH)/proprietary/vendor/etc/vintf/manifest/android.hardware.security.secureclock-service.mitee.xml:recovery/root/vendor/etc/vintf/manifest/android.hardware.security.secureclock-service.mitee.xml \
    $(DEVICE_PATH)/proprietary/vendor/etc/vintf/manifest/android.hardware.security.sharedsecret-service.mitee.xml:recovery/root/vendor/etc/vintf/manifest/android.hardware.security.sharedsecret-service.mitee.xml \
    $(DEVICE_PATH)/proprietary/vendor/etc/vintf/manifest/android.hardware.weaver-service.nxp.xml:recovery/root/vendor/etc/vintf/manifest/android.hardware.weaver-service.nxp.xml
