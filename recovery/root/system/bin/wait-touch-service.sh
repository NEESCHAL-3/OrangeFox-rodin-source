#!/system/bin/sh

setprop vendor.touch.service.ready 0

attempt=0
while [ "$attempt" -lt 50 ]; do
    raw="$(cat /sys/devices/virtual/touch/touch_dev/enable_touch_raw 2>/dev/null)"
    state="$(getprop init.svc.rodin-touchfeature)"
    input=""
    for name_path in /sys/class/input/input*/name; do
        name="$(cat "$name_path" 2>/dev/null)"
        case "$name" in
            goodix_ts|focaltech_ts|fts_ts)
                input="$name"
                break
                ;;
        esac
    done

    if [ "$state" = "running" ] && [ -n "$input" ]; then
        setprop vendor.touch.service.ready 1
        echo "TouchReport is running; input=$input raw=$raw"
        exit 0
    fi

    attempt=$((attempt + 1))
    sleep 0.1
done

echo "TouchReport did not become ready: service=$state input=$input raw=$raw" >&2
exit 1
