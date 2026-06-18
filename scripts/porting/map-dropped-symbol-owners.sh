#!/usr/bin/env bash
# Map dropped fire config symbols to the Kconfig files that define them here.

set -euo pipefail

root="$(git rev-parse --show-toplevel)"
symbols="${1:-$root/out/porting-6.6/android15-6.6-port-report/dropped-fire-symbols.list}"
report="${2:-$root/out/porting-6.6/android15-6.6-port-report/dropped-symbol-owners.tsv}"

[[ -f "$symbols" ]] || {
	printf 'missing symbols file: %s\n' "$symbols" >&2
	exit 1
}

mkdir -p "$(dirname "$report")"

while IFS= read -r config; do
	[[ "$config" == CONFIG_* ]] || continue
	symbol="${config#CONFIG_}"
	mapfile -t owners < <(
		rg -l "^(menuconfig|config)[[:space:]]+$symbol$" \
			--glob 'Kconfig*' \
			--glob '!out/**' \
			--glob '!dist/**' \
			"$root" || true
	)

	if ((${#owners[@]})); then
		for owner in "${owners[@]}"; do
			printf '%s\t%s\n' "$config" "${owner#$root/}"
		done
	else
		printf '%s\t%s\n' "$config" "MISSING"
	fi
done <"$symbols" | sort -k2,2 -k1,1 >"$report"

printf 'Wrote %s\n' "$report"
