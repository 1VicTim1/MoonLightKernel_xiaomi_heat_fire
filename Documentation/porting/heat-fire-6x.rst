MoonLightKernel heat/fire 6.x port seed
=======================================

Current base
------------

The main branch is currently a MediaTek Android kernel based on Linux 4.19.325
for Xiaomi Redmi 12 fire/heat.  The active production target is ``fire`` on
``mt6768``; ``heat_defconfig`` is retained as an archived variant and should be
treated as a delta on top of ``fire`` during the 6.x bring-up.

Initial 6.x target
------------------

Use an Android common 6.6 arm64/GKI tree as the first 6.x base unless a newer
MediaTek mt6768 vendor source tree is available.  A plain upstream Linux 6.x
tree is not enough for this device because most of the modem, display, camera,
power and connectivity stack is vendor code.

The current test branch is ``6.6-testing`` and the checked base is
``android-common/android15-6.6`` at ``9a017a1c5913``.  That branch identifies
itself as Linux 6.6.138.

Portable device surface
-----------------------

The first migration unit is the device surface, not the whole 4.19 tree:

* ``arch/arm64/configs/fire_defconfig``
* ``arch/arm64/configs/fire_6x_porting.fragment``
* ``arch/arm64/configs/heat_defconfig``
* ``arch/arm64/configs/heat_6x_porting.fragment``
* ``arch/arm64/boot/dts/mediatek/mt6768.dts``
* ``arch/arm64/boot/dts/mediatek/fire.dts``
* ``arch/arm64/boot/dts/mediatek/heat.dts``
* ``arch/arm64/boot/dts/mediatek/fire/cust.dtsi``
* ``arch/arm64/boot/dts/mediatek/cust_mt6768_*.dtsi``
* ``arch/arm64/boot/dts/mediatek/bat_setting/mt6768_*``
* ``include/dt-bindings/clock/mt6768-clk.h``
* ``include/dt-bindings/gce/mt6768-gce.h``
* ``include/dt-bindings/memory/mt6768-larb-port.h``
* ``include/dt-bindings/mmc/mt6768-msdc.h``
* ``include/dt-bindings/pinctrl/mt6768-pinfunc.h``
* Other local ``dt-bindings`` headers included by the MT6768 DTS roots

Bring-up order
--------------

1. Import or check out the selected 6.x Android common base.
2. Merge the 6.x base defconfig with ``fire_6x_porting.fragment``.
3. Copy only the MT6768/fire/heat DTS and binding inputs listed above.
4. Run ``make ARCH=arm64 O=out/fire-6x fire_defconfig`` or the equivalent
   merged-config target in the 6.x tree.
5. Fix missing Kconfig symbols by porting the owning vendor driver directory,
   starting with PMIC/charger, pinctrl/GPIO, display/backlight and storage.
6. Build ``dtbs`` and ``dtbo.img`` before attempting a full ``Image.gz`` build.
7. After the kernel links, validate boot, display init, touch, charging, modem,
   Wi-Fi/BT/GPS and suspend/resume in that order.

Expected 4.19 to 6.x conflict zones
-----------------------------------

* ``CONFIG_SCHED_TUNE`` and MTK scheduler hooks need reconciliation with modern
  uclamp/cgroup behavior.
* Legacy ION users must be moved to DMA-BUF heaps or a compatible Android common
  shim.
* ``struct file_operations`` users that only expose procfs/debugfs paths often
  need ``proc_ops`` conversions.
* Block, MMC, USB gadget, extcon and power-supply APIs changed across 5.x/6.x.
* The MTK framebuffer path may conflict with newer DRM/KMS expectations.
* DTS bindings should be cleaned as each driver is ported; the generated
  ``fire/cust.dtsi`` should remain a mechanical input until the first boot.

Build checkpoints
-----------------

The first useful 6.x milestone is not a booting kernel.  It is a 6.x tree where
``fire_6x_porting.fragment`` expands, MT6768 DTS files compile, and the missing
symbols list is small enough to map to concrete vendor driver directories.

Baseline check
--------------

Run the reproducible first-pass check with:

::

    scripts/porting/check-android15-6.6-baseline.sh

The script creates a generated worktree under ``out/porting-6.6/``, copies the
portable heat/fire inputs into the Android common 6.6 tree, runs
``olddefconfig`` with ``fire_6x_porting.fragment``, and then attempts to build
``mediatek/mt6768.dtb`` and ``mediatek/fire.dtbo``.  Reports are written to
``out/porting-6.6/android15-6.6-report``.

The first run against ``android15-6.6`` expands the config but drops the vendor
MTK symbols that are not present in Android common 6.6.  This confirms that the
next major porting unit is the MTK Kconfig/driver stack, while DTS bring-up
should continue by fixing missing binding and include inputs first.

The legacy MTK DTS roots include ``generated/autoconf.h`` to use ``CONFIG_*``
preprocessor guards.  Android common 6.6 generates that header under the
``O=`` directory, while the DTC include path does not expose ``generated/``.
The baseline check creates a generated-only symlink so diagnostics can continue;
the long-term port should replace those Kconfig-gated DTS sections with 6.6
friendly board includes or explicit overlay variants.

The same diagnostic check also exposes a ``mediatek`` include-prefix shim
because legacy MTK DTS files include sibling files as ``"mediatek/foo.dtsi"``,
while the 6.6 per-vendor DTB target already runs from the MediaTek DTS
directory.  Long-term cleanup should normalize those local includes instead of
depending on the shim.

Android common 6.6 also expects overlays to be declared in the vendor DTS
``Makefile`` and compiled from ``*.dtso`` sources.  The diagnostic check patches
the generated 6.6 worktree to register ``mt6768.dtb`` and ``fire.dtbo``, and
mirrors legacy ``fire.dts`` as ``fire.dtso``.  The long-term source-tree port
should make that integration explicit instead of relying on the generated
mirror.

Current checkpoint against ``android15-6.6``:

* ``fire_6x_porting.fragment`` merges and ``olddefconfig`` completes.
* ``mediatek/mt6768.dtb`` builds with no DTC warnings.
* ``mediatek/fire.dtbo`` builds with no DTC warnings.
* 175 fire config symbols are dropped because Android common
  6.6 does not contain the MTK vendor Kconfig/driver stack.
* ``mediatek/heat.dtbo`` is not part of the passing checkpoint yet; the archived
  heat DTS includes ``<heat/cust.dtsi>``, which is not present in this tree.

Materialized 6.6 Workspace
--------------------------

Use this when moving from diagnostics into actual porting work:

::

    scripts/porting/materialize-android15-6.6-port.sh

It creates ``out/porting-6.6/android15-6.6-port-tree`` from the Android common
6.6 base, copies the portable heat/fire inputs, applies the temporary DTB/DTBO
integration used by the checker, generates ``olddefconfig``, and builds
``mediatek/mt6768.dtb`` plus ``mediatek/fire.dtbo``.  This generated worktree
is the place to start importing MTK vendor Kconfig and driver directories
without disturbing the 4.19 source branch.

The materializer also copies the root ``build.sh`` into the generated 6.6
worktree and writes ``arch/arm64/configs/fire_6x_defconfig`` from the merged
configuration.  A focused fire smoke build can then be run with:

::

    TOOLCHAIN_DIR=$HOME/.cache/android-kernel-toolchains/clang-r530567 \
    OUT_DIR=$PWD/out/porting-6.6/config-fire-port \
    BUILD_TARGETS='Image mediatek/mt6768.dtb mediatek/fire.dtbo' \
    out/porting-6.6/android15-6.6-port-tree/build.sh fire_6x --manual --no-ccache

``BUILD_TARGETS`` is intentionally narrower than a full arm64 build so Android
common does not try to compile unrelated vendor DTBs while the fire port is
still being staged.  The current smoke checkpoint produces:

* ``out/porting-6.6/config-fire-port/arch/arm64/boot/Image``
* ``out/porting-6.6/config-fire-port/arch/arm64/boot/dts/mediatek/mt6768.dtb``
* ``out/porting-6.6/config-fire-port/arch/arm64/boot/dts/mediatek/fire.dtbo``
* ``out/porting-6.6/config-fire-port/arch/arm64/boot/dtbo.img``

The next source porting target is the missing MTK vendor stack represented by
the dropped fire config symbols.  Start with the lowest boot-critical layers:
``CONFIG_MACH_MT6768``, pinctrl/GPIO, PMIC/charger, MMC/storage, USB/Type-C,
and display/backlight.

To map dropped symbols back to the current 4.19 Kconfig owners, run:

::

    scripts/porting/map-dropped-symbol-owners.sh

The report is written to
``out/porting-6.6/android15-6.6-port-report/dropped-symbol-owners.tsv``.

Current dropped-symbol ownership snapshot:

* 168 entries are owned by ``drivers/misc/mediatek``.
* 7 entries are owned by ``kernel/sched/extension``.
* 6 entries are owned by ``drivers/power/supply``.
* 4 entries are owned by ``arch/arm64/Kconfig``.
* The most important first owner groups are ``drivers/misc/mediatek/pmic``,
  ``drivers/misc/mediatek/pmic/mt6370``, ``drivers/misc/mediatek/usb20``,
  ``drivers/misc/mediatek/typec/tcpc``, ``drivers/misc/mediatek/video``,
  ``drivers/misc/mediatek/lcm``, ``drivers/misc/mediatek/leds`` and
  ``drivers/power/supply/mediatek``.

ADB Reference Device
--------------------

The connected ``fire`` phone is useful as a working 4.19 reference.  It is not
currently booted into official 6.6 sources:

* Active slot is ``_b``.
* Live kernel is ``4.19.325-cip132-st16-MoonLightKernel+``.
* Live DT root reports ``model = "MT6769H"`` and
  ``compatible = "mediatek,MT6768"``.
* Dumped ``boot_a`` and ``boot_b`` both contain
  ``4.19.325-cip132-st16-MoonLightKernel+`` strings, so neither slot currently
  gives us an official 6.6 kernel image.
* Embedded boot DTB is identical between ``boot_a`` and ``boot_b``.
* ``vendor_boot_a`` and ``vendor_boot_b`` are identical.
* ``dtbo_a`` and ``dtbo_b`` differ; active ``dtbo_b`` uses ``novatek@0`` for
  the touch overlay and has the same ``mediatek,md-eint`` SIM hotplug binding as
  the current source tree.

To refresh a read-only reference dump from an attached rooted phone:

::

    scripts/porting/dump-fire-adb-artifacts.sh
    DUMP_IMAGES=1 scripts/porting/dump-fire-adb-artifacts.sh

The default mode collects properties, kernel config, command line and live
device tree.  ``DUMP_IMAGES=1`` additionally reads ``boot_*``, ``vendor_boot_*``
and ``dtbo_*`` partitions into ``out/device-dumps``.
