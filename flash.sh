#!/usr/bin/env bash
#
# Flash build/nanotag.uf2 onto the nice!nano.
# Double-tap the board's RESET to enter the UF2 bootloader; this waits for the NICENANO
# drive to mount, then copies the firmware. The board reboots into the app automatically.
#
set -eo pipefail
cd "$(dirname "$0")"

UF2=build/nanotag.uf2
[ -f "$UF2" ] || { echo "No $UF2 — run ./build.sh first."; exit 1; }

find_drive() {
  # macOS: /Volumes/NICENANO ; Linux: /media/<user>/NICENANO or /run/media/<user>/NICENANO
  for d in /Volumes/NICENANO /media/*/NICENANO /run/media/*/NICENANO; do
    [ -d "$d" ] && { echo "$d"; return 0; }
  done
  return 1
}

echo "Double-tap the nice!nano RESET button to enter the bootloader..."
DRIVE=""
for _ in $(seq 1 120); do          # up to 60 s
  DRIVE=$(find_drive) && break
  sleep 0.5
done
[ -n "$DRIVE" ] || { echo "Timed out waiting for the NICENANO drive."; exit 1; }

echo "Flashing to $DRIVE ..."
# -X on macOS avoids a ._ metadata file (it corrupts the copy). A just-mounted drive can briefly
# refuse writes ("Permission denied"), so retry a few times.
cp_cmd=(cp "$UF2" "$DRIVE"/)
[ "$(uname)" = "Darwin" ] && cp_cmd=(cp -X "$UF2" "$DRIVE"/)
for _ in 1 2 3 4; do
  if "${cp_cmd[@]}" 2>/dev/null; then
    echo "Done — the board will reboot into the app."
    exit 0
  fi
  sleep 1
done
echo "Copy kept failing — re-run ./flash.sh and double-tap RESET again."
exit 1
