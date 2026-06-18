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

Use an Android common 6.1 arm64/GKI tree as the first 6.x base unless a newer
MediaTek mt6768 vendor source tree is available.  A plain upstream Linux 6.x
tree is not enough for this device because most of the modem, display, camera,
power and connectivity stack is vendor code.

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
* ``include/dt-bindings/pinctrl/mt6768-pinfunc.h``

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
