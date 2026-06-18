#!/usr/bin/env bash
# Export the first-pass heat/fire inputs needed when seeding a 6.x kernel tree.

set -euo pipefail

root="$(git rev-parse --show-toplevel)"
out="${1:-$root/out/porting-6.6/heat-fire-inputs}"

mkdir -p "$out"

required_files="$out/required-files.list"
config_symbols="$out/fire-config-symbols.list"
dts_includes="$out/dts-includes.list"
dt_binding_files="$out/dt-binding-files.list"
summary="$out/summary.txt"
dts_roots=(
	arch/arm64/boot/dts/mediatek/mt6768.dts
	arch/arm64/boot/dts/mediatek/fire.dts
	arch/arm64/boot/dts/mediatek/heat.dts
	arch/arm64/boot/dts/mediatek/fire/cust.dtsi
)

cat >"$required_files" <<'LIST'
arch/arm64/configs/fire_defconfig
arch/arm64/configs/fire_6x_porting.fragment
arch/arm64/configs/heat_defconfig
arch/arm64/configs/heat_6x_porting.fragment
arch/arm64/boot/dts/mediatek/mt6768.dts
arch/arm64/boot/dts/mediatek/fire.dts
arch/arm64/boot/dts/mediatek/heat.dts
arch/arm64/boot/dts/mediatek/fire/cust.dtsi
LIST

git -C "$root" ls-files \
	'arch/arm64/boot/dts/mediatek/cust_mt6768_*.dtsi' \
	'arch/arm64/boot/dts/mediatek/bat_setting/mt6768_*' \
	>>"$required_files"

{
	for dts in "${dts_roots[@]}"
	do
		sed -n 's/^[[:space:]]*#include[[:space:]]*[<"]\([^>"]*\)[>"].*/\1/p' "$root/$dts"
	done
} | sort -u >"$dts_includes"

>"$dt_binding_files"
binding_queue=()

add_dt_binding_file() {
	local path="$1"

	[[ "$path" == include/dt-bindings/* ]] || return
	[[ -f "$root/$path" ]] || return
	grep -qxF "$path" "$dt_binding_files" 2>/dev/null && return

	printf '%s\n' "$path" >>"$dt_binding_files"
	binding_queue+=("$path")
}

while IFS= read -r include; do
	case "$include" in
	dt-bindings/*)
		add_dt_binding_file "include/$include"
		;;
	mediatek/*)
		[[ -f "$root/arch/arm64/boot/dts/$include" ]] &&
			printf 'arch/arm64/boot/dts/%s\n' "$include"
		;;
	esac
done <"$dts_includes" >>"$required_files"

while ((${#binding_queue[@]})); do
	current="${binding_queue[0]}"
	binding_queue=("${binding_queue[@]:1}")
	current_dir="$(dirname "$current")"

	while IFS= read -r include; do
		case "$include" in
		dt-bindings/*)
			add_dt_binding_file "include/$include"
			;;
		*/*)
			add_dt_binding_file "$current_dir/$include"
			;;
		*)
			add_dt_binding_file "$current_dir/$include"
			;;
		esac
	done < <(sed -n 's/^[[:space:]]*#include[[:space:]]*[<"]\([^>"]*\)[>"].*/\1/p' "$root/$current")
done

cat "$dt_binding_files" >>"$required_files"
sort -u "$required_files" -o "$required_files"
sort -u "$dt_binding_files" -o "$dt_binding_files"

sed -n 's/^\(CONFIG_[A-Za-z0-9_]*\).*/\1/p' \
	"$root/arch/arm64/configs/fire_6x_porting.fragment" \
	"$root/arch/arm64/configs/heat_6x_porting.fragment" |
	sort -u >"$config_symbols"

{
	printf 'MoonLightKernel heat/fire 6.x seed inputs\n'
	printf 'tree: %s\n' "$root"
	printf 'commit: %s\n' "$(git -C "$root" rev-parse --short=12 HEAD)"
	printf 'required files: %s\n' "$(wc -l <"$required_files")"
	printf 'config symbols: %s\n' "$(wc -l <"$config_symbols")"
	printf 'DTS includes: %s\n' "$(wc -l <"$dts_includes")"
	printf 'DT binding files: %s\n' "$(wc -l <"$dt_binding_files")"
} >"$summary"

printf 'Wrote %s\n' "$out"
