DEVICE_PATH := device/xiaomi/rodin

TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a55
TARGET_CPU_VARIANT_RUNTIME := cortex-a55

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a55

TARGET_BOARD_PLATFORM := mt6899
TARGET_BOOTLOADER_BOARD_NAME := mt6899
TARGET_NO_BOOTLOADER := true
TARGET_NO_RADIOIMAGE := true
TARGET_USES_UEFI := true

BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

TARGET_NO_RECOVERY := true
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab

# KSN's working TWRP uses these equivalent base-relative values. They resolve
# to the physical addresses in the supplied stock vendor_boot image.
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
TARGET_NO_KERNEL := true
BOARD_USES_GENERIC_KERNEL_IMAGE := true
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
BOARD_RAMDISK_USE_LZ4 := true
BOARD_KERNEL_SEPARATED_DTBO := true

BOARD_KERNEL_BASE := 0x3fff8000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_PAGE_SIZE := 4096
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x26f08000
BOARD_KERNEL_TAGS_OFFSET := 0x07c88000
BOARD_DTB_OFFSET := 0x07c88000

BOARD_BOOT_HEADER_VERSION := 4
BOARD_VENDOR_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 erofs.reserved_pages=64
# mkbootimg's defaults do not match the physical addresses in stock
# vendor_boot. Keep these offsets explicit so the generated header remains
# compatible with the MTK bootloader.
BOARD_MKBOOTIMG_ARGS += \
    --header_version $(BOARD_BOOT_HEADER_VERSION) \
    --kernel_offset $(BOARD_KERNEL_OFFSET) \
    --ramdisk_offset $(BOARD_RAMDISK_OFFSET) \
    --tags_offset $(BOARD_KERNEL_TAGS_OFFSET) \
    --dtb_offset $(BOARD_DTB_OFFSET)

BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img
BOARD_PREBUILT_DTBIMAGE_DIR := $(DEVICE_PATH)/prebuilt/dtb

BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
BOARD_SUPER_PARTITION_SIZE := 11811160064
BOARD_USERDATAIMAGE_PARTITION_SIZE := 12884901888
BOARD_FLASH_BLOCK_SIZE := 131072

BOARD_USES_RECOVERY_AS_BOOT := false
BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
BOARD_MOVE_GSI_AVB_KEYS_TO_VENDOR_BOOT := true
BOARD_USES_METADATA_PARTITION := true

# Prune the full ncurses database after OrangeFox finishes preparing the
# ramdisk, while retaining common terminal definitions.
BOARD_RECOVERY_IMAGE_PREPARE = bash $(DEVICE_PATH)/fox_callback.sh $(TARGET_RECOVERY_ROOT_OUT) --first-call

AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    init_boot \
    vendor_boot \
    dtbo \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor \
    system \
    system_ext \
    system_dlkm \
    vendor \
    vendor_dlkm \
    product \
    odm \
    odm_dlkm \
    mi_ext

BOARD_SUPER_PARTITION_BLOCK_DEVICES := super
BOARD_SUPER_PARTITION_METADATA_DEVICE := super
BOARD_SUPER_PARTITION_SUPER_DEVICE_SIZE := 11811160064
BOARD_SUPER_PARTITION_GROUPS := main
BOARD_MAIN_SIZE := 11800674304
BOARD_MAIN_PARTITION_LIST := \
    odm \
    odm_dlkm \
    product \
    system \
    system_dlkm \
    system_ext \
    vendor \
    vendor_dlkm \
    mi_ext

TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
TARGET_USERIMAGES_USE_EROFS := true
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_METADATAIMAGE_FILE_SYSTEM_TYPE := f2fs

BOARD_AVB_ENABLE := true

TW_THEME := portrait_hdpi
TARGET_SCREEN_WIDTH := 1220
TARGET_SCREEN_HEIGHT := 2712
TW_MAX_BRIGHTNESS := 2047
TW_DEFAULT_BRIGHTNESS := 1000
# Read capacity directly from the working kernel power-supply node.
TW_USE_LEGACY_BATTERY_SERVICES := true
TW_INCLUDE_FASTBOOTD := true
TW_INCLUDE_LPTOOLS := true
TW_INCLUDE_LPDUMP := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_EROFS := true
TW_DEFAULT_LANGUAGE := en
# The first decrypt page opens before encrypted Fox settings can be read.
OF_LOAD_DEFAULT_LANGUAGE_BEFORE_DECRYPT := 1
TW_HAS_MTP := true
TW_MTP_DEVICE := /dev/mtp_usb
TW_NO_USB_STORAGE := true
TW_INPUT_BLACKLIST := "hbtp_vm"
# Reloading the complete GUI after FBE unlock reproducibly SIGSEGVs on rodin.
# The initial package remains active and settings are still loaded normally.
OF_SKIP_POST_DECRYPT_THEME_RELOAD := 1
TARGET_USES_LOGD := true
TWRP_INCLUDE_LOGCAT := true
RECOVERY_SDCARD_ON_DATA := true
BOARD_HAS_LARGE_FILESYSTEM := true

# Android 16 FBE uses the device's MiTEE KeyMint and Gatekeeper services.
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_USE_FSCRYPT_POLICY := 2
TW_RECOVERY_ADDITIONAL_RELINK_LIBRARY_FILES = \
    $(TARGET_OUT_SHARED_LIBRARIES)/libtrusty.so \
    $(TARGET_OUT_SHARED_LIBRARIES)/librodin_libcxx_compat.so

PRODUCT_SOONG_NAMESPACES += $(DEVICE_PATH)

-include $(DEVICE_PATH)/fox_rodin.mk
TW_EXCLUDE_DEFAULT_USB_INIT := true

# NEES: native ARM64 Edify fallback for legacy ARM32 recovery ZIPs
TARGET_RECOVERY_DEVICE_MODULES += updater
