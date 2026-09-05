#!/usr/bin/env bash

ROOT=/mnt/rodin-build/OrangeFox-rodin-source
FOX=/mnt/rodin-build/fox_14.1

mkdir -p \
"$FOX/bootable/recovery/gui/theme/portrait_hdpi/images/Default/About"

cp -f \
"$ROOT/assets/theme/maintainer.png" \
"$FOX/bootable/recovery/gui/theme/portrait_hdpi/images/Default/About/maintainer.png"

echo "NEESCHAL theme assets synced."
