#!/usr/bin/env bash
# Overlay selected Android 15 MTK device_modules code into a materialized 6.6 tree.

set -euo pipefail

root="$(git rev-parse --show-toplevel)"
worktree="${1:?usage: $0 WORKTREE [DEVICE_MODULES_TREE]}"
ref_tree="${2:-${MTK_DEVICE_MODULES_REF_TREE:-$root/out/reference-moto-device-modules-6.6}}"
alps_commit="${MTK_DEVICE_MODULES_ALPS_COMMIT:-3b31307ea54d689cecab0f231d43208959287cd1}"

if [[ ! -d "$worktree" ]]; then
	printf 'error: worktree not found: %s\n' "$worktree" >&2
	exit 1
fi

if [[ ! -d "$ref_tree/.git" ]]; then
	printf 'error: device_modules reference tree not found: %s\n' "$ref_tree" >&2
	exit 1
fi

git -C "$ref_tree" rev-parse --verify "$alps_commit^{commit}" >/dev/null

copy_from_ref() {
	local src="$1"
	local dst="$2"

	mkdir -p "$worktree/$(dirname "$dst")"
	git -C "$ref_tree" show "$alps_commit:$src" >"$worktree/$dst"
}

rewrite_mmc_config_symbols() {
	local file="$1"

	perl -0pi \
		-e 's/CONFIG_DEVICE_MODULES_MMC_MTK_SW_CQHCI_DEBUG/CONFIG_MMC_MTK_SW_CQHCI_DEBUG/g;' \
		-e 's/CONFIG_DEVICE_MODULES_MMC_MTK_SW_CQHCI/CONFIG_MMC_MTK_SW_CQHCI/g;' \
		-e 's/CONFIG_DEVICE_MODULES_MMC_CQHCI_DEBUG/CONFIG_MMC_CQHCI_DEBUG/g;' \
		-e 's/CONFIG_DEVICE_MODULES_MMC_CQHCI/CONFIG_MMC_CQHCI/g;' \
		-e 's/CONFIG_DEVICE_MODULES_MMC_DEBUG/CONFIG_MMC_DEBUG/g;' \
		-e 's/CONFIG_DEVICE_MODULES_MMC_MTK_PRO/CONFIG_MMC_MTK_PRO/g;' \
		"$file"
}

copy_from_ref drivers/mmc/host/mtk-mmc.c drivers/mmc/host/mtk-sd.c
copy_from_ref drivers/mmc/host/mtk-mmc.h drivers/mmc/host/mtk-mmc.h
copy_from_ref drivers/mmc/host/mtk-mmc-dbg.h drivers/mmc/host/mtk-mmc-dbg.h
copy_from_ref drivers/mmc/host/mtk-mmc-swcqhci.h drivers/mmc/host/mtk-mmc-swcqhci.h
copy_from_ref drivers/mmc/host/mtk-mmc-swcqhci-crypto.h drivers/mmc/host/mtk-mmc-swcqhci-crypto.h

for file in \
	drivers/mmc/host/mtk-sd.c \
	drivers/mmc/host/mtk-mmc.h \
	drivers/mmc/host/mtk-mmc-dbg.h \
	drivers/mmc/host/mtk-mmc-swcqhci.h \
	drivers/mmc/host/mtk-mmc-swcqhci-crypto.h
do
	rewrite_mmc_config_symbols "$worktree/$file"
done

mkdir -p "$worktree/drivers/mmc/host" "$worktree/include/mt-plat"

grep -q '^obj-$(CONFIG_MMC_DEBUG)[[:space:]]*+= mtk-mmc-dbg.o$' \
	"$worktree/drivers/mmc/host/Makefile" ||
	printf 'obj-$(CONFIG_MMC_DEBUG)	+= mtk-mmc-dbg.o\n' \
		>>"$worktree/drivers/mmc/host/Makefile"

cat >"$worktree/drivers/mmc/host/mtk-mmc-dbg.c" <<'STUB'
// SPDX-License-Identifier: GPL-2.0-only
/*
 * Minimal MTK MMC debug hooks for the first Android common 6.6 MSDC bring-up.
 *
 * ALPS mtk-mmc.c calls these helpers even in normal error paths. The complete
 * debugfs/procfs implementation is useful later, but eMMC probing must not
 * depend on it while the rest of device_modules is being split into slices.
 */

#include <linux/mmc/host.h>
#include <linux/seq_file.h>

#include "mtk-mmc.h"

void msdc_dump_info(char **buff, unsigned long *size, struct seq_file *m,
		    struct msdc_host *host)
{
	if (host)
		dev_info(host->dev, "MSDC debug dump is not ported yet\n");
}

int mmc_dbg_register(struct mmc_host *mmc)
{
	return 0;
}

void gpio_dump_regs_range(int start, int end)
{
}

void msdc_dump_register_to_buf(struct msdc_host *host, int index)
{
}

void msdc_dump_register_from_buf(struct msdc_host *host, int index)
{
}
STUB

cat >"$worktree/drivers/mmc/host/rpmb-mtk.h" <<'STUB'
/* SPDX-License-Identifier: GPL-2.0 */
/*
 * Minimal MTK RPMB shim for the first Android common 6.6 MSDC bring-up.
 *
 * The full MediaTek RPMB/TEE stack lives outside the boot-critical eMMC host
 * probe path. Keep registration non-fatal here so first-stage init can reach
 * userdata/super while the vendor RPMB service is ported as a later slice.
 */
#ifndef _MTK_MMC_RPMB_BRINGUP_H
#define _MTK_MMC_RPMB_BRINGUP_H

struct mmc_host;

static inline int mmc_rpmb_register(struct mmc_host *mmc)
{
	return 0;
}

#endif
STUB

cat >"$worktree/include/mt-plat/mtk_blocktag.h" <<'STUB'
/* SPDX-License-Identifier: GPL-2.0 */
/*
 * Minimal blocktag shim for the first MTK MSDC 6.6 bring-up.
 *
 * The Android 15 device_modules tree exposes these helpers from the external
 * MediaTek blocktag module. The fire first-boot path only needs the MMC host to
 * probe, so keep the optional tracing hooks inert until blocktag is ported as
 * a separate vendor module slice.
 */
#ifndef _MTK_BLOCKTAG_BRINGUP_H
#define _MTK_BLOCKTAG_BRINGUP_H

#define mtk_btag_mictx_get_data(...)
#define mtk_btag_mictx_enable(...)
#define mtk_btag_ufs_init(...)
#define mtk_btag_ufs_exit(...)
#define mtk_btag_ufs_send_command(...)
#define mtk_btag_ufs_transfer_req_compl(...)
#define mmc_mtk_biolog_send_command(...)
#define mmc_mtk_biolog_transfer_req_compl(...)
#define mmc_mtk_biolog_init(...)
#define mmc_mtk_biolog_exit(...)
#define mmc_mtk_biolog_check(...)

#endif
STUB

printf 'Applied ALPS device_modules MMC slice %s from %s\n' \
	"$(git -C "$ref_tree" rev-parse --short=12 "$alps_commit")" "$ref_tree"
