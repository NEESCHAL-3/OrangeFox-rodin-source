$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)
$(call inherit-product, vendor/twrp/config/common.mk)
$(call inherit-product, device/xiaomi/rodin/device.mk)

PRODUCT_DEVICE := rodin
PRODUCT_NAME := omni_rodin
PRODUCT_BRAND := Redmi
PRODUCT_MODEL := 24129RT7CC
PRODUCT_MANUFACTURER := Xiaomi
PRODUCT_RELEASE_NAME := Redmi Turbo 4

PRODUCT_GMS_CLIENTID_BASE := android-xiaomi


PRODUCT_BUILD_PROP_OVERRIDES += \
    TARGET_DEVICE=rodin \
    PRODUCT_NAME=rodin
