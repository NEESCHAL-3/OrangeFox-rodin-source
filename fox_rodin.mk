OF_MAINTAINER := local
FOX_TARGET_DEVICES := rodin
OF_USE_MAGISKBOOT := 1
OF_USE_NEW_MAGISKBOOT := 1
OF_USE_LZ4_COMPRESSION := 1
OF_USE_SYSTEM_FINGERPRINT := 1
# Virtual A/B devices are treated as Vanilla builds by OrangeFox 14.1.
# All-block OTA support is incompatible with that mode.
OF_SUPPORT_ALL_BLOCK_OTA_UPDATES := 0
OF_NO_TREBLE_COMPATIBILITY_CHECK := 1
OF_MANUAL_ROOT_VENDOR_ERROR_FIX := 1
OF_ENABLE_LPTOOLS := 1
OF_USE_TWRP_SAR_DETECT := 1
OF_FLASHLIGHT_ENABLE := 0
# The 1220x2712 panel is exactly 1080x2400 in the theme's coordinate space.
# Keep horizontal and vertical scaling equal instead of stretching the stock
# 1080x1920 theme vertically.
OF_SCREEN_H := 2400
OF_SKIP_MULTIUSER_FOLDERS_BACKUP := 1
