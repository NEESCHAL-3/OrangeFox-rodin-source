# Verified Runtime Baseline

This file records the known-good source identities used for the tested Xiaomi `rodin` OrangeFox build.

## Device tree

```text
4df2a7210e1b146cebeed11252fe5f8fa516d2eb
rodin: save runtime verified recovery baseline
```

Tags associated with this baseline:

```text
rodin-full-runtime-known-good-20260807
rodin-source-release-20260812
```

## bootable/recovery

Clean base:

```text
fd98f33a722bd0bd52034f170bb91e2862654d6b
```

Verified rodin target:

```text
bc786e483e55c4be5ebeebc039b8acf6ed65d6b2
```

## build/make

Clean base:

```text
506df226dd003a364916b6b3ee1eb3bf9064f97f
```

Verified rodin target:

```text
701572c48b6b328b1ce7f904aeb745440f0f3da0
```

## India platform ramdisk

File:

```text
prebuilt/india/vendor_ramdisk00
```

SHA-256:

```text
c1b5ad776c93f89c6bf227ffecbf21ff3338236833d424446b388bb9819587a6
```

## Canonical complete patches

Recovery complete patch SHA-256:

```text
7a9e58bd9ac062bf93c67c080ba3ec397ce3b06530283b4eb07031e6163dc763
```

build/make complete patch SHA-256:

```text
5f2d3f43a4d78eee6d560a4a169df30fc95de6fa2ed294e3210e684a641a8329
```

## Verified release artifact

```text
OrangeFox-R12.0-Rodin-UNOFFICIAL-STABLE-20260807.img
```

Size:

```text
67108864 bytes
```

SHA-256:

```text
fa4c59e0f3713b42aa20d6316243fc1dd629e8899d461160411d52c4c2ff124e
```

## Support boundary

The verified configuration is **India only**. Global and China profiles are not part of the supported build path documented by this repository.
