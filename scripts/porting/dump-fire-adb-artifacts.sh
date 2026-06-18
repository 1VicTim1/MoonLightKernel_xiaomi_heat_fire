#!/usr/bin/env bash
# Read-only dump of useful fire/heat kernel artifacts from an adb-connected phone.

set -euo pipefail

root="$(git rev-parse --show-toplevel)"
out="${1:-$root/out/device-dumps/fire-adb-$(date +%Y%m%d-%H%M%S)}"
dump_images="${DUMP_IMAGES:-0}"

mkdir -p "$out"
printf '%s\n' "$out" >"$root/out/device-dumps/.latest-fire-dump"

adb devices -l >"$out/adb-devices.txt"
adb shell 'id; uname -a; getprop ro.boot.slot_suffix; getprop ro.product.device; getprop ro.boot.hardware' \
	>"$out/device-summary.txt"
adb shell 'getprop' >"$out/getprop.txt"
adb shell 'cat /proc/cmdline' >"$out/proc-cmdline.txt"
adb shell 'cat /proc/version' >"$out/proc-version.txt"
adb shell 'zcat /proc/config.gz' >"$out/proc-config" 2>/dev/null || true
adb shell 'ls -l /dev/block/by-name; for p in boot_a boot_b vendor_boot_a vendor_boot_b dtbo_a dtbo_b; do printf "%s " "$p"; blockdev --getsize64 /dev/block/by-name/$p 2>/dev/null || true; done' \
	>"$out/partitions.txt"
adb exec-out 'cd /sys/firmware/devicetree/base && tar cf - .' >"$out/live-device-tree.tar"
gzip -c "$out/live-device-tree.tar" >"$out/live-device-tree.tar.gz"

if [[ "$dump_images" == 1 ]]; then
	mkdir -p "$out/images"
	for part in boot_a boot_b vendor_boot_a vendor_boot_b dtbo_a dtbo_b; do
		adb exec-out "dd if=/dev/block/by-name/$part bs=4M 2>/dev/null" \
			>"$out/images/$part.img"
	done
	sha256sum "$out"/images/*.img >"$out/sha256sums.txt"
fi

printf 'Wrote %s\n' "$out"
