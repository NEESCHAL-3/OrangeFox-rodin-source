# Rodin recovery haptics

The Android 16 device probes a Silicon Integrated SIH6887 at I2C address
`0-006b`. The matching stock components were extracted read-only from the
running slot:

- `si_haptic.ko` from `vendor_dlkm_a`, retained here for controlled testing,
  SHA-256
  `a2d4f0ab2a21a8b8ea8b283243a5f83f5a0982c36c8f9ca0905b86d4914442e0`
- `aw8697_haptic.bin` from `/vendor/firmware`, SHA-256
  `7d331b2295fb098f521453382dab3011d442ae08f0aca1d1a680334ea92914b7`

Despite its filename, `aw8697_haptic.bin` is the RAM waveform requested by the
SIH6887 stock driver. Basic recovery feedback uses the driver's `duration` and
`activate` sysfs attributes and does not require the Android vibrator HAL.

Both files are packed only in the recovery fragment. `si_haptic.ko` is not in
`modules.load.recovery`: `rodin-haptics-loader` starts after the TouchReport
service is ready, waits another 20 seconds, and then loads it directly. This
keeps the driver out of first-stage initialization. A real-device late-load
test bound the driver at `0-006b`, and three 80 ms pulses were physically
confirmed. The loader itself never pulses the motor.
