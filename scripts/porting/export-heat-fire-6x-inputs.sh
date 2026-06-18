#!/usr/bin/env bash
# Export the first-pass heat/fire inputs needed when seeding a 6.x kernel tree.

set -euo pipefail

root="$(git rev-parse --show-toplevel)"
out="${1:-$root/out/porting-6x/heat-fire-inputs}"

mkdir -p "$out"

required_files="$out/required-files.list"
config_symbols="$out/fire-config-symbols.list"
dts_includes="$out/dts-includes.list"
summary="$out/summary.txt"

cat >"$required_files" <<'LIST'
arch/arm64/configs/fire_defconfig
arch/arm64/configs/fire_6x_porting.fragment
arch/arm64/configs/heat_defconfig
arch/arm64/configs/heat_6x_porting.fragment
arch/arm64/boot/dts/mediatek/mt6768.dts
arch/arm64/boot/dts/mediatek/fire.dts
arch/arm64/boot/dts/mediatek/heat.dts
arch/arm64/boot/dts/mediatek/fire/cust.dtsi
include/dt-bindings/pinctrl/mt6768-pinfunc.h
LIST

git -C "$root" ls-files \
	'arch/arm64/boot/dts/mediatek/cust_mt6768_*.dtsi' \
	'arch/arm64/boot/dts/mediatek/bat_setting/mt6768_*' \
	>>"$required_files"

sort -u "$required_files" -o "$required_files"

sed -n 's/^\(CONFIG_[A-Za-z0-9_]*\).*/\1/p' \
	"$root/arch/arm64/configs/fire_6x_porting.fragment" \
	"$root/arch/arm64/configs/heat_6x_porting.fragment" |
	sort -u >"$config_symbols"

{
	for dts in \
		"$root/arch/arm64/boot/dts/mediatek/mt6768.dts" \
		"$root/arch/arm64/boot/dts/mediatek/fire.dts" \
		"$root/arch/arm64/boot/dts/mediatek/heat.dts" \
		"$root/arch/arm64/boot/dts/mediatek/fire/cust.dtsi"
	do
		sed -n 's/^[[:space:]]*#include[[:space:]]*[<"]\([^>"]*\)[>"].*/\1/p' "$dts"
	done
} | sort -u >"$dts_includes"

{
	printf 'MoonLightKernel heat/fire 6.x seed inputs\n'
	printf 'tree: %s\n' "$root"
	printf 'commit: %s\n' "$(git -C "$root" rev-parse --short=12 HEAD)"
	printf 'required files: %s\n' "$(wc -l <"$required_files")"
	printf 'config symbols: %s\n' "$(wc -l <"$config_symbols")"
	printf 'DTS includes: %s\n' "$(wc -l <"$dts_includes")"
} >"$summary"

printf 'Wrote %s\n' "$out"
