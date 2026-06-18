#!/usr/bin/env bash
# Create a writable Android common 6.6 port workspace with heat/fire inputs.

set -euo pipefail

root="$(git rev-parse --show-toplevel)"
ref="${1:-android-common/android15-6.6}"
base_out="$root/out/porting-6.6"
worktree="$base_out/android15-6.6-port-tree"
config_out="$base_out/config-fire-port"
inputs_out="$base_out/heat-fire-inputs"
report_out="$base_out/android15-6.6-port-report"

git -C "$root" rev-parse --verify "$ref^{commit}" >/dev/null

"$root/scripts/porting/export-heat-fire-6x-inputs.sh" "$inputs_out" >/dev/null

if [[ -d "$worktree/.git" || -f "$worktree/.git" ]]; then
	git -C "$worktree" reset --hard "$ref" >/dev/null
	git -C "$worktree" clean -fdx >/dev/null
else
	rm -rf "$worktree"
	git -C "$root" worktree add --detach "$worktree" "$ref" >/dev/null
fi

while IFS= read -r path; do
	[[ -f "$root/$path" ]] || continue
	mkdir -p "$worktree/$(dirname "$path")"
	cp "$root/$path" "$worktree/$path"
done <"$inputs_out/required-files.list"

cp "$root/build.sh" "$worktree/build.sh"
chmod +x "$worktree/build.sh"

mediatek_makefile="$worktree/arch/arm64/boot/dts/mediatek/Makefile"
grep -q '^dtb-$(CONFIG_ARCH_MEDIATEK) += mt6768.dtb$' "$mediatek_makefile" ||
	printf 'dtb-$(CONFIG_ARCH_MEDIATEK) += mt6768.dtb\n' >>"$mediatek_makefile"
grep -q '^dtb-$(CONFIG_ARCH_MEDIATEK) += fire.dtbo$' "$mediatek_makefile" ||
	printf 'dtb-$(CONFIG_ARCH_MEDIATEK) += fire.dtbo\n' >>"$mediatek_makefile"

cp "$worktree/arch/arm64/boot/dts/mediatek/fire.dts" \
	"$worktree/arch/arm64/boot/dts/mediatek/fire.dtso"

rm -rf "$config_out" "$report_out"
mkdir -p "$config_out" "$report_out"

(
	cd "$worktree"
	scripts/kconfig/merge_config.sh -m -O "$config_out" \
		arch/arm64/configs/gki_defconfig \
		arch/arm64/configs/fire_6x_porting.fragment
	make O="$config_out" ARCH=arm64 olddefconfig
	make O="$config_out" ARCH=arm64 savedefconfig
) >"$report_out/olddefconfig.log" 2>&1
cp "$config_out/defconfig" "$worktree/arch/arm64/configs/fire_6x_defconfig"

mkdir -p "$worktree/scripts/dtc/include-prefixes/generated"
ln -sf "$config_out/include/generated/autoconf.h" \
	"$worktree/scripts/dtc/include-prefixes/generated/autoconf.h"
ln -sfn "$worktree/arch/arm64/boot/dts/mediatek" \
	"$worktree/scripts/dtc/include-prefixes/mediatek"

while IFS= read -r sym; do
	if ! grep -q "^${sym}=" "$config_out/.config"; then
		printf '%s\n' "$sym"
	fi
done <"$inputs_out/fire-config-symbols.list" >"$report_out/dropped-fire-symbols.list"

(
	cd "$worktree"
	make O="$config_out" ARCH=arm64 mediatek/mt6768.dtb
	make O="$config_out" ARCH=arm64 mediatek/fire.dtbo
) >"$report_out/dtb.log" 2>&1

{
	printf 'Android common 6.6 materialized fire port workspace\n'
	printf 'base ref: %s\n' "$ref"
	printf 'base commit: %s\n' "$(git -C "$root" rev-parse --short=12 "$ref")"
	printf 'worktree: %s\n' "$worktree"
	printf 'config out: %s\n' "$config_out"
	printf 'build script: %s\n' "$worktree/build.sh"
	printf 'build defconfig: %s\n' "$worktree/arch/arm64/configs/fire_6x_defconfig"
	printf 'required files: %s\n' "$(wc -l <"$inputs_out/required-files.list")"
	printf 'dropped fire symbols: %s\n' "$(wc -l <"$report_out/dropped-fire-symbols.list")"
	printf 'dtb warnings: %s\n' "$(grep -c 'Warning' "$report_out/dtb.log" || true)"
} | tee "$report_out/summary.txt"
