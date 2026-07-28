# Recovery CJK fonts

`MiSans.ttf` is a recovery-sized subset of the locally supplied
`orangefox_rodin/MiSans/otf/MiSans-Regular.otf`. OrangeFox uses this single font
both as its selectable MiSans theme family and as the fallback for glyphs
missing from the selected Latin font. The subset combines the previous
recovery CJK coverage with every character supported by MiSans and referenced
by the built-in OrangeFox XML resources.

- Full source SHA-256:
  `8e9caa6f34f27c6baad1ecf0058cc13e1801efff698bc23e6e0b095d9a9ed9cb`
- Subset SHA-256:
  `13b4f46ec638a464355ca63f76ed6e0078d94927410503a9aa00cbdbaa8b01da`
- Subset size: 1,547,160 bytes
- Coverage: 8,134 Unicode code points, including every visible character in
  the simplified and traditional Chinese translations

The source directory did not include a separate license file. Confirm the
MiSans redistribution terms before publishing a recovery image.

## Previous Noto subset

`NotoSansCJKSC-Recovery.ttf` is a recovery-sized subset of the Android 16
system font `/system/fonts/NotoSansCJK-Regular.ttc`:

- Source TTC SHA-256: `3e7e5afaac2c6d872592d76abedac03a51c6f0fc42d11e311ff2816a6c368afe`
- Source face: index 2, Noto Sans CJK SC Regular
- Included characters: GB2312, Latin-1, CJK punctuation and radicals,
  full-width forms, kana, and bopomofo
- Subset SHA-256: `35a91fdb85a1e0fc39eaf1c35258cf1def7d8afb63df782148ac3ea6e0969dfc`
- Subset size: 6,324,104 bytes

The font remains licensed under the SIL Open Font License 1.1. It is retained
as a reproducible fallback asset but is no longer packed into the image.
