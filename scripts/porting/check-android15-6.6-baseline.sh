#!/usr/bin/env bash
# Reproduce the first Android common 6.6 heat/fire porting check.

set -euo pipefail

root="$(git rev-parse --show-toplevel)"
ref="${1:-android-common/android15-6.6}"
base_out="$root/out/porting-6.6"
worktree="$base_out/android15-6.6-tree"
config_out="$base_out/config-fire-android15-6.6"
inputs_out="$base_out/heat-fire-inputs"
report_out="$base_out/android15-6.6-report"

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

mediatek_makefile="$worktree/arch/arm64/boot/dts/mediatek/Makefile"
grep -q '^dtb-$(CONFIG_ARCH_MEDIATEK) += mt6768.dtb$' "$mediatek_makefile" ||
	printf 'dtb-$(CONFIG_ARCH_MEDIATEK) += mt6768.dtb\n' >>"$mediatek_makefile"
grep -q '^dtb-$(CONFIG_ARCH_MEDIATEK) += fire.dtbo$' "$mediatek_makefile" ||
	printf 'dtb-$(CONFIG_ARCH_MEDIATEK) += fire.dtbo\n' >>"$mediatek_makefile"

# Linux 6.6 builds overlays from *.dtso.  The legacy MTK overlay is still named
# fire.dts, so mirror it in the generated worktree until the source is renamed.
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
) >"$report_out/olddefconfig.log" 2>&1

# Legacy MTK DTS files use CONFIG_* guards by including generated/autoconf.h.
# Keep this generated-only shim in the 6.6 check worktree so DTC can expose the
# next device-tree blocker before the DTS is cleaned up properly.
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

set +e
(
	cd "$worktree"
	make O="$config_out" ARCH=arm64 mediatek/mt6768.dtb
) >"$report_out/mt6768-dtb.log" 2>&1
dtb_status=$?

(
	cd "$worktree"
	make O="$config_out" ARCH=arm64 mediatek/fire.dtbo
) >"$report_out/fire-dtbo.log" 2>&1
fire_dtbo_status=$?
set -e

{
	printf 'Android common 6.6 heat/fire porting check\n'
	printf 'base ref: %s\n' "$ref"
	printf 'base commit: %s\n' "$(git -C "$root" rev-parse --short=12 "$ref")"
	printf 'required files: %s\n' "$(wc -l <"$inputs_out/required-files.list")"
	printf 'dropped fire symbols: %s\n' "$(wc -l <"$report_out/dropped-fire-symbols.list")"
	printf 'mt6768 dtb status: %s\n' "$dtb_status"
	printf 'mt6768 dtb warnings: %s\n' "$(grep -c 'Warning' "$report_out/mt6768-dtb.log" || true)"
	printf 'fire dtbo status: %s\n' "$fire_dtbo_status"
	printf 'fire dtbo warnings: %s\n' "$(grep -c 'Warning' "$report_out/fire-dtbo.log" || true)"
	if (( dtb_status != 0 )); then
		printf 'first dtb error:\n'
		grep -m1 -E 'fatal error|Error|Ошибка' "$report_out/mt6768-dtb.log" || true
	fi
	if (( fire_dtbo_status != 0 )); then
		printf 'first fire dtbo error:\n'
		grep -m1 -E 'fatal error|No rule|Нет правила|Error|Ошибка' \
			"$report_out/fire-dtbo.log" || true
	fi
} | tee "$report_out/summary.txt"

exit $((dtb_status || fire_dtbo_status))
