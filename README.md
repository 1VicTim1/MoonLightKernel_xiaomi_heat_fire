# LinyxKernel-OC — Overclocked Kernel for Xiaomi Redmi 12 (fire/heat)

> **Base:** MoonLightKernel (`ksu-susfs` branch) | **Device:** Xiaomi Redmi 12 (codename: fire) | **Chipset:** MediaTek MT6768

This document explains every change made to overclock the CPU and apply performance tuning, with copy-pasteable commands so you can replicate it on your own fork.

---

## Summary

| Component | Stock | Overclocked |
|---|---|---|
| LITTLE cluster (A55, 6 cores) | 1700 MHz | **1900 MHz** |
| BIG cluster (A75, 2 cores) | 2000 MHz | **2100 MHz** |
| Default governor | schedutil | **performance** |
| TCP congestion control | westwood+ | **bbr** |
| ZRAM compression | default | **lz4** |
| EEM (voltage/freq guard) | enabled | **disabled** |

---

## Step 1 — CPU Frequency Table (Device Tree)

File: `arch/arm64/boot/dts/mediatek/mt6768.dts`

This adds new OPP (Operating Performance Point) entries to the device tree so the kernel *knows about* the higher frequencies. Find the `cluster0_opp` (LITTLE) block and add two new entries after the last one (`opp15`):

```dts
		opp16 {
			opp-hz = /bits/ 64 <1800000000>;
			opp-microvolt = <987500>;
		};
		opp17 {
			opp-hz = /bits/ 64 <1900000000>;
			opp-microvolt = <1012500>;
		};
```

Then find `cluster1_opp` (BIG) and add after its last entry (`opp15`):

```dts
		opp16 {
			opp-hz = /bits/ 64 <2050000000>;
			opp-microvolt = <1100000>;
		};
		opp17 {
			opp-hz = /bits/ 64 <2100000000>;
			opp-microvolt = <1112500>;
		};
```

Then disable EEM (Embedded Energy Management), which otherwise clamps the CPU back down to stock frequencies at runtime regardless of the DTS values. Find this block and change `eem-status`:

```dts
	eem_fsm: eem_fsm@1100b000 {
		compatible = "mediatek,eem_fsm";
		...
		eem-status = <0>;    /* stock value is <1> */
```

**One-liner to apply the EEM change:**
```bash
sed -i 's/eem-status = <1>/eem-status = <0>/' arch/arm64/boot/dts/mediatek/mt6768.dts
```

> **Note:** the DTS-level OPP table is necessary but *not sufficient* on MT6768 — see Step 2.

---

## Step 2 — CPU Frequency Table (cpufreq driver)

This is the critical, easy-to-miss step. MT6768's `cpufreq_v1` driver does **not** read its frequency table from the DTS — it uses a separate hardcoded table in C. If you skip this step, the DTS changes above will have no effect.

File: `drivers/misc/mediatek/base/power/cpufreq_v1/src/mach/mt6768/mtk_cpufreq_opp_table.h`

### 2.1 — Find out which segment your device uses

Different `fire`-codename boards use different segments (`6768`, `6767`, `PRO`, `G75`, etc) depending on silicon binning. Boot the *stock* kernel and check which one is active:

```bash
adb shell su -c "cat /proc/cpufreq/MT_CPU_DVFS_L/cpufreq_oppidx"
```

The header on the output tells you the segment, e.g. `[MT_CPU_DVFS_L/6]` -> `CPU_LEVEL_6` -> this corresponds to the `G75` macros in the table file (see the `opp_tbls` array near the bottom of the header to map `CPU_LEVEL_N` to a macro suffix). **Redmi 12 (fire) uses the `G75` segment.** If your device differs, substitute the macro suffix (`_6768`, `_6767`, `_PRO`, etc.) accordingly in the commands below.

### 2.2 — Raise the LITTLE (A55) cluster max frequency

```bash
python3 << 'EOF'
path = 'drivers/misc/mediatek/base/power/cpufreq_v1/src/mach/mt6768/mtk_cpufreq_opp_table.h'
with open(path, 'r') as f:
    content = f.read()

content = content.replace(
    '#define CPU_DVFS_FREQ0_LL_G75\t\t1800000\t\t/* KHz */',
    '#define CPU_DVFS_FREQ0_LL_G75\t\t1900000\t\t/* KHz */'
)

with open(path, 'w') as f:
    f.write(content)
print("LITTLE cluster updated")
EOF
```

### 2.3 — Raise the BIG (A75) cluster max frequency + voltage

```bash
python3 << 'EOF'
path = 'drivers/misc/mediatek/base/power/cpufreq_v1/src/mach/mt6768/mtk_cpufreq_opp_table.h'
with open(path, 'r') as f:
    content = f.read()

# Frequencies
content = content.replace(
    '#define CPU_DVFS_FREQ0_L_G75\t\t2000000\t\t/* KHz */',
    '#define CPU_DVFS_FREQ0_L_G75\t\t2100000\t\t/* KHz */'
)
content = content.replace(
    '#define CPU_DVFS_FREQ1_L_G75\t\t1950000\t\t/* KHz */',
    '#define CPU_DVFS_FREQ1_L_G75\t\t2050000\t\t/* KHz */'
)

# Voltages (raised to keep the higher clocks stable)
content = content.replace(
    '#define CPU_DVFS_VOLT0_VPROC2_G75\t108750\t\t/* 10uV */',
    '#define CPU_DVFS_VOLT0_VPROC2_G75\t112500\t\t/* 10uV */'
)
content = content.replace(
    '#define CPU_DVFS_VOLT1_VPROC2_G75\t107500\t\t/* 10uV */',
    '#define CPU_DVFS_VOLT1_VPROC2_G75\t111250\t\t/* 10uV */'
)

with open(path, 'w') as f:
    f.write(content)
print("BIG cluster updated")
EOF
```

### 2.4 — Verify

```bash
grep -n "FREQ0_LL_G75\|FREQ0_L_G75\|FREQ1_L_G75\|VOLT0_VPROC2_G75\|VOLT1_VPROC2_G75" \
  drivers/misc/mediatek/base/power/cpufreq_v1/src/mach/mt6768/mtk_cpufreq_opp_table.h
```

Expected output:
```
#define CPU_DVFS_FREQ0_LL_G75		1900000		/* KHz */
#define CPU_DVFS_FREQ0_L_G75		2100000		/* KHz */
#define CPU_DVFS_FREQ1_L_G75		2050000		/* KHz */
#define CPU_DVFS_VOLT0_VPROC2_G75	112500		/* 10uV */
#define CPU_DVFS_VOLT1_VPROC2_G75	111250		/* 10uV */
```

---

## Step 3 — Default Governor: performance

File: `arch/arm64/configs/fire_defconfig`

By default the kernel boots with `schedutil`, which ramps frequency up/down based on load — meaning the CPU often idles well below the new max. Setting `performance` as the default keeps the CPU pinned at max frequency from boot.

```bash
sed -i 's/CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL=y/CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y/' \
  arch/arm64/configs/fire_defconfig
```

---

## Step 4 — TCP BBR Congestion Control

File: `arch/arm64/configs/fire_defconfig`

BBR generally achieves better throughput and lower latency than the default `westwood+` on most real-world networks.

```bash
sed -i 's/CONFIG_DEFAULT_TCP_CONG="westwood+"/CONFIG_DEFAULT_TCP_CONG="bbr"/' \
  arch/arm64/configs/fire_defconfig
```

> Requires `CONFIG_TCP_CONG_BBR=y` to already be set in the defconfig (it is, on MoonLightKernel).

---

## Step 5 — ZRAM LZ4 Compression

File: `arch/arm64/configs/fire_defconfig`

LZ4 trades a little compression ratio for significantly faster (de)compression compared to the default, which helps ZRAM swap feel snappier under memory pressure.

```bash
echo "CONFIG_CRYPTO_LZ4=y" >> arch/arm64/configs/fire_defconfig
```

---

## Step 6 — Kernel Name / Build Identity (optional)

File: `localversion-cip`, `localversion-st`

Purely cosmetic — changes what shows up in `Settings > About Phone > Kernel Version` and in KSU Manager.

```bash
echo "-LinyxKernel-OC+" > localversion-cip
echo "" > localversion-st
```

To also customize the `(builder@host)` part shown in `uname -a`, export these before building:

```bash
export KBUILD_BUILD_USER="YourName"
export KBUILD_BUILD_HOST="YourHost"
```

---

## Building

```bash
export KBUILD_BUILD_USER="YourName"
export KBUILD_BUILD_HOST="YourHost"
./build.sh fire
```

Output AnyKernel3 zip will be in `dist/`.

---

## Flashing

1. Push the zip to the device: `adb push dist/*.zip /sdcard/`
2. Boot into recovery (TWRP / stock recovery with sideload support)
3. Flash the zip
4. Reboot

---

## Verifying the Overclock

```bash
# BIG cluster max frequency should now list 2100000 and 2050000
adb shell su -c "cat /sys/devices/system/cpu/cpu6/cpufreq/scaling_available_frequencies"

# LITTLE cluster max frequency should now list 1900000
adb shell su -c "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies"

# Confirm performance governor is active
adb shell su -c "cat /sys/devices/system/cpu/cpu6/cpufreq/scaling_governor"

# Check thermals
adb shell su -c "cat /sys/class/thermal/thermal_zone0/temp"
```

---

## Adapting This to a Different MT6768 Device / Segment

If your board reports a different `CPU_LEVEL_N` than `G75` (Step 2.1), open `mtk_cpufreq_opp_table.h` and look for the macro family matching your level, e.g. for `CPU_LEVEL_0` it's the `_6768` suffix, for `CPU_LEVEL_2` it's `_PRO`, etc. Repeat Steps 2.2-2.3 substituting the correct suffix. The macro names follow this pattern:

```
CPU_DVFS_FREQ0_LL_<SUFFIX>      -> LITTLE cluster, OPP 0 (highest)
CPU_DVFS_FREQ0_L_<SUFFIX>       -> BIG cluster, OPP 0 (highest)
CPU_DVFS_FREQ1_L_<SUFFIX>       -> BIG cluster, OPP 1 (second highest)
CPU_DVFS_VOLT0_VPROC2_<SUFFIX>  -> BIG cluster voltage, OPP 0
CPU_DVFS_VOLT1_VPROC2_<SUFFIX>  -> BIG cluster voltage, OPP 1
```

---

## Warnings

- Overclocking increases voltage and frequency beyond stock, which means:
  - Higher heat generation
  - Faster battery drain
  - A small but non-zero risk of instability or, in rare cases, premature hardware wear
- Always stress-test after flashing (sustained load + thermal monitoring) before relying on the build daily.
- If you experience random reboots under load, the assigned voltage is likely too low for your specific chip (silicon lottery) — raise it slightly and rebuild.

---

## Credits

- [MoonLightKernel](https://github.com/1VicTim1/MoonLightKernel_xiaomi_heat_fire) — base kernel
- [KernelSU](https://github.com/tiann/KernelSU) — root solution
- [SUSFS](https://gitlab.com/simonpunk/susfs4ksu) — stealth patches
- [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3) — kernel flasher
