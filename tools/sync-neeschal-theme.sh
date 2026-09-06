#!/usr/bin/env bash
set -euo pipefail

DEVICE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
ROOT="${DEVICE_DIR}"

if [[ -n "${ORANGEFOX_TOP:-}" ]]; then
    FOX="$(cd -- "${ORANGEFOX_TOP}" && pwd -P)"
elif [[ -n "${RODIN_TOP_DIR:-}" ]]; then
    FOX="$(cd -- "${RODIN_TOP_DIR}" && pwd -P)"
elif [[ -f "${DEVICE_DIR}/../../../build/envsetup.sh" ]]; then
    FOX="$(cd -- "${DEVICE_DIR}/../../.." && pwd -P)"
elif [[ -f "${DEVICE_DIR}/../fox_14.1/build/envsetup.sh" ]]; then
    FOX="$(cd -- "${DEVICE_DIR}/../fox_14.1" && pwd -P)"
else
    echo "ERROR: OrangeFox 14.1 source tree not found." >&2
    exit 1
fi

mkdir -p \
"$FOX/bootable/recovery/gui/theme/portrait_hdpi/images/Default/About"

cp -f \
"$ROOT/assets/theme/maintainer.png" \
"$FOX/bootable/recovery/gui/theme/portrait_hdpi/images/Default/About/maintainer.png"

echo "NEESCHAL theme assets synced."
