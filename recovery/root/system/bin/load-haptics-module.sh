#!/system/bin/sh

# The driver is known to bind reliably once recovery and touch initialization
# have settled. Do not pulse the motor here; UI feedback controls it later.
sleep 20

if ! grep -q '^si_haptic ' /proc/modules; then
    insmod /lib/modules/si_haptic.ko || exit 1
fi

tries=0
while [ "${tries}" -lt 50 ]; do
    if [ -e /sys/bus/i2c/drivers/sih_haptic_688X/0-006b/activate ]; then
        setprop vendor.haptics.ready 1
        exit 0
    fi
    tries=$((tries + 1))
    sleep 0.1
done

echo "SIH6887 did not bind" >&2
exit 2
