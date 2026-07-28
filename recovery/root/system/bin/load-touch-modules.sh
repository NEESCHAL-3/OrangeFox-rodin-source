#!/system/bin/sh

setprop vendor.touch.modules.ready 0

load_module() {
    module="$1"
    name="${module%.ko}"

    if grep -q "^${name} " /proc/modules; then
        echo "$name is already loaded"
        return 0
    fi

    echo "loading $module"
    insmod "/lib/modules/$module" || return 1
}

touch_spi=""
for device in /sys/bus/spi/devices/*; do
    if [ "$(cat "$device/modalias" 2>/dev/null)" = "spi:touch-spi" ]; then
        touch_spi="$device"
        break
    fi
done

if [ -z "$touch_spi" ]; then
    echo "touch SPI device is missing; refusing to load touch drivers" >&2
    exit 1
fi
echo "found touch controller at ${touch_spi##*/}"

load_module scp.ko || exit 2
load_module xiaomi_touch_rodin.ko || exit 3
load_module goodix_core_rodin.ko || exit 4
load_module focaltech_touch_rodin.ko || exit 5

setprop vendor.touch.modules.ready 1
echo "touch modules loaded; inspect dmesg for controller probe status"
