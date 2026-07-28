#!/usr/bin/env bash
set -euo pipefail

SWAPFILE=/swapfile
SWAPSIZE=8G   # غيّر الحجم حسب الحاجة (مثلاً 8G، 12G، ...)

# If swap already active on the same file, skip
if sudo swapon --show=NAME | awk '{print $1}' | grep -qx "$SWAPFILE"; then
  echo "Swap already active at $SWAPFILE — skipping creation."
  exit 0
fi

# If file exists but not active, try to remove it safely
if [ -f "$SWAPFILE" ]; then
  echo "$SWAPFILE exists but not active — attempting to recreate."
  sudo swapoff "$SWAPFILE" || true
  sudo rm -f "$SWAPFILE"
fi

echo "Creating swapfile $SWAPFILE size $SWAPSIZE"

# Try fallocate first, fall back to dd on failure
if ! sudo fallocate -l "$SWAPSIZE" "$SWAPFILE" 2>/dev/null; then
  echo "fallocate failed — falling back to dd (slower)..."
  if [[ "$SWAPSIZE" =~ ^([0-9]+)G$ ]]; then
    MB=$(( ${BASH_REMATCH[1]} * 1024 ))
    sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count="$MB" status=progress
  else
    echo "Unsupported SWAPSIZE format: $SWAPSIZE"
    exit 1
  fi
fi

sudo chmod 600 "$SWAPFILE"
sudo mkswap "$SWAPFILE"
sudo swapon "$SWAPFILE"
echo "Swap enabled:"
sudo swapon --show
free -h
