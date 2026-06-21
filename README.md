# LinyxKernel-OC — NetHunter Branch

Bu branch, [LinyxKernel-OC](https://github.com/Linyx9/LinyxKernel-OC) layihəsinin Xiaomi Redmi 12 (MT6768 / `fire`) üçün **NetHunter pentest dəstəyi və KernelSU root** əlavə olunmuş versiyasıdır. Əsas overclock branch-ından fərqli olaraq, bu branch performans yox, **pentest tooling + root** üzərində fokuslanır.

## Cihaz məlumatı

- **Cihaz:** Xiaomi Redmi 12 (`fire`)
- **SoC:** MediaTek MT6768
- **Kernel versiyası:** 4.19
- **Toolchain:** Android Clang (`clang-r383902b`)
- **Defconfig:** `arch/arm64/configs/fire_defconfig`

## Edilən dəyişikliklər

### 1. KernelSU inteqrasiyası

- KernelSU rəsmi repo-sundan (`tiann/KernelSU`) clone edildi.
- **İlk cəhd `v3.2.4` ilə oldu, amma bu versiya kernel 5.10+/6.x (GKI) üçün yazılıb** və 4.19 ilə uyğun deyil. Aşağıdaki API-lar səbəbindən compile xətaları yarandı:
  - `fsnotify_ops.handle_inode_event` (yeni fsnotify API, 4.19-da `handle_event`)
  - `struct file_operations.iopoll` / `.remap_file_range` (4.19-da mövcud deyil)
  - `SECCOMP_ARCH_NATIVE_NR`, `TWA_RESUME` (yeni kernel makroları)
  - `uapi/linux/mount.h` (yol fərqi)
  - `MODULE_IMPORT_NS()` makrosu (yalnız kernel 5.4+)
  - `copy_to_kernel_nofault()` (yalnız kernel 5.8+, 4.19-da `probe_kernel_write()`)
- **Qərar: `v0.9.5` tag-ına keçildi** — bu, KernelSU-nun GKI-yönümlü refaktorinqindən (multi-manager, seccomp cache, fsnotify v2, file_wrapper) əvvəlki son stabil versiyadır və 4.14/4.19 kernel-lərlə geniş test edilib. Bu versiyada yalnız `CONFIG_KSU` və `CONFIG_KSU_DEBUG` seçimləri var — minimal və sadədir.

```bash
cd KernelSU
git checkout v0.9.5
```

- `fire_defconfig`-ə əlavə olundu:
```
CONFIG_KSU=y
```

### 2. Pentest-yönümlü əlavə kernel seçimləri

`fire_defconfig`-in sonuna əlavə edildi:
```
CONFIG_USB_RAW_GADGET=y
CONFIG_CRYPTO_USER_API_SKCIPHER=y
CONFIG_CRYPTO_USER_API_HASH=y
```
- `USB_RAW_GADGET` — arbitrary USB device emulation (BadUSB/fuzzing ssenariləri üçün)
- `CRYPTO_USER_API_*` — userspace-dən kernel crypto API-larına çıxış (VPN/tunnel alətləri üçün)

### 3. WiFi adapter dəstəyi (mövcud, dəyişdirilməyib)

Defconfig-də onsuz da builtin olan USB WiFi driverlər (NetHunter-də xarici adapter üçün):
- `RT2800USB` ailəsi (Ralink/MediaTek)
- `ATH9K_HTC`, `CARL9170` (Atheros)
- `MT76x0U`, `MT76x2U`, `MT7601U` (MediaTek MT76)
- `RTL8187`, `RTL8192CU`, `RTL8XXXU` (Realtek — TP-Link TL-WN722N v2/v3 daxil)
- `ZD1211RW`, `USB_ZD1201` (Zydas)

> **Qeyd:** Builtin driverlər (məs. `RTL8XXXU`) client mode üçün kifayətdir, amma monitor mode/packet injection üçün stabil deyil. Real pentest (aircrack-ng, wifite) üçün `RTL8812AU`/`RTL88x2BU` kimi patch olunmuş driverlərin DKMS modulu kimi əlavə edilməsi tövsiyə olunur — bu branch-da hələ edilməyib.

## Build

```bash
./build.sh fire -A
```

`-A` (`--auto`) bayrağı toolchain-i avtomatik yükləyir və asılılıqları yoxlayır. Build nəticəsində AnyKernel3 flashable ZIP `dist/` qovluğuna yazılır.

Build-i yoxlamaq üçün:
```bash
grep -i ksu out/fire/.config
```

## Məlum problemlər / Gələcək işlər

- [ ] `RTL8812AU`/`RTL88x2BU` injection-capable driverlərin əlavə edilməsi
- [ ] Netfilter/iptables tam dəstəyinin yoxlanılması (MITM alətləri üçün)
- [ ] `CONFIG_PACKET` / `AF_PACKET` dəstəyinin təsdiqlənməsi (tcpdump/Wireshark üçün)
- [ ] SUSFS inteqrasiyası (root gizlətmə, hazırda əlavə olunmayıb — sadə KSU istifadə olunur)

## Lisenziya

Bu layihə GPL-2.0 əsasında, yuxarı axın (upstream) MediaTek/Xiaomi kernel mənbəyi və KernelSU layihəsi üzərində qurulub.
