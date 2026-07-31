#!/system/bin/sh

MODULE="/lib/modules/si_haptic.ko"
NODE="/sys/bus/i2c/devices/0-006b"

setprop vendor.haptics.ready 0

# Touch is already ready before this service starts.
# Allow a brief settling delay instead of waiting 20 seconds.
sleep 3

if ! grep -q '^si_haptic ' /proc/modules; then
    insmod "$MODULE" || {
        echo "Failed to load si_haptic.ko" >&2
        exit 1
    }
fi

tries=0

while [ "$tries" -lt 100 ]; do
    if [ -e "$NODE/activate" ] &&
       [ -e "$NODE/duration" ] &&
       [ -e "$NODE/gain" ] &&
       [ -e "$NODE/ram_num" ]; then

        ram_status="$(cat "$NODE/ram_num" 2>/dev/null)"

        case "$ram_status" in
            *"wave_num = "[1-9]*)
                # 64 decimal = 0x40, stronger than stock recovery's 0x1e.

                setprop vendor.haptics.ready 1
                exit 0
                ;;
        esac
    fi

    sleep 0.1
    tries=$((tries + 1))
done

echo "SIH6887 RAM firmware did not become ready" >&2
exit 2
