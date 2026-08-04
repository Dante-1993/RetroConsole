# 🎮 RetroConsole OS & Installer

**RetroConsole** is a standalone, kiosk-oriented operating system built on Debian 13 (Trixie), designed to seamlessly run classic MS-DOS and Windows 95/98 games and applications on modern and legacy hardware.

The system comes with the **RetroConsole Custom Installer ISO** — a customized zero-touch installation media styled after late 90s setup utilities. The deployment process is completely automated, featuring a dual-phase setup with Windows 98 Setup-style promotional slideshows and an Award BIOS POST screen finish.

---

## 💻 System Requirements

| Parameter | Minimum Requirements | Recommended Requirements |
| :--- | :--- | :--- |
| **CPU** | 64-bit (x86_64 / ARM64), Dual-Core | Quad-Core CPU (Ryzen / Core i5+) |
| **RAM** | 2 GB | 4 GB or more |
| **Storage** | 8 GB Free Space (HDD) | 16 GB Free Space (SSD) |
| **Graphics** | OpenGL 2.1 compatible GPU | OpenGL 3.x+ / Vulkan compatible GPU |
| **Display Resolution** | 1024×768 | 1920×1080 |
| **Network** | Internet access for initial setup phase | 100/1000 Mbit Ethernet or Wi-Fi |

> **Performance Note:** Thanks to dynamic CPU core recompilation (`core=dynamic_x86`), the underlying DOSBox-X emulation layer is extremely lightweight. Core 2 Duo or Athlon 64 X2 CPUs are more than sufficient for most DOS and Windows 95/98 titles without heavy 3D acceleration.

---

## 🧪 Hardware & Platform Compatibility

| Platform / Environment | Compatibility Status | Notes |
| :--- | :--- | :--- |
| **AMD Ryzen (x86_64)** | ✅ Fully Supported | Tested, maximum performance |
| **Intel Core (x86_64)** | ✅ Fully Supported | Tested across multiple generations |
| **Legacy x86 PCs (~2005+)** | ✅ Fully Supported | Performance depends on raw CPU clock speed |
| **Raspberry Pi 5 (ARM64)** | 🔄 In Testing | Solid Win98 boot; heavy Glide/3D workloads under testing |
| **QEMU / KVM** | ✅ Fully Supported | Reference development and ISO build platform |
| **VMware Workstation / ESXi** | ✅ Fully Supported | Smooth graphics stack execution |
| **VirtualBox** | ✅ Fully Supported | 3D acceleration must be enabled in VM settings |
| **Hyper-V** | ✅ Fully Supported | Operates via RetroConsole custom framebuffers |

---

## ❓ Why These Requirements & How It Works

> **RetroConsole does not run Windows 98 directly on bare-metal modern hardware.**

Modern chipsets, NVMe drives, UEFI firmware, and contemporary GPUs lack Windows 9x drivers. Instead of native booting, RetroConsole deploys a minimalist, hyper-tuned Linux kernel layer hosting a software-emulated late-90s PC environment.

### Key Advantages:
* **Hardware Independence:** Operates identically on a 2026 gaming rig, inside a Hyper-V VM, or on a compact Raspberry Pi 5.
* **Zero Driver Issues:** Windows 98 interacts exclusively with virtualized legacy devices (Sound Blaster 16/AWE32, SoundFont MIDI, NE2000 network adapter, VESA/S3 Graphics).
* **Seamless Silent Boot:** All Linux, GRUB, and systemd text outputs are masked. On startup, users only see custom retro splash screens and Award BIOS POST simulations.

---

## 💿 RetroConsole Custom Installer ISO

The **RetroConsole** installation image is crafted from `debian-13-netinst` with heavily patched installer internals:

1. **Phase 1 (ISO Setup):** Clean GTK installer interface free of standard Debian branding, executing automated disk partitioning and base extraction in zero-touch mode.
2. **Phase 2 (First-Boot Setup):** Upon initial reboot, a Plymouth `retro-promo` theme triggers a **Windows 98 Setup-style slideshow** (*"Sit back and relax while setup configures your system..."*). In the background, it fetches the Win98 image, compiles DOSBox-X, and configures Samba (SMBv1) alongside SoundFont MIDI synthesizers.
3. **Finalization:** The system transitions to an **Award BIOS** screen, auto-reboots, and boots directly into full-screen Windows 98.

---

## ☁️ Coming Soon: RetroCloud Ecosystem

**RetroCloud** is an upcoming cloud-native storage and synchronization service tailored specifically for retro gaming enthusiasts and legacy operating systems.

The platform bridges the gap between modern cloud infrastructure and vintage software, enabling seamless game save synchronization, ISO library management, and remote access to your retro assets from anywhere in the world.

---

### 🚀 Key Planned Features:

* **Cross-Device Save Sync:** Automatic cloud backup and synchronization of game save states across RetroConsole, modern PCs, laptops, and mobile devices.
* **Legacy-to-Cloud Bridge:** Seamless integration linking modern WebRTC/P2P and Cloud APIs with vintage network protocols (SMBv1, FTP, WebDAV) for direct access within Windows 95/98 and MS-DOS.
* **Zero-Install Web Dashboard:** A sleek, browser-based management interface to organize your ISO images, virtual hard drives, and system profiles on the fly.
* **Data Protection & Versioning:** Cloud snapshots preventing save corruption or disk image degradation.

> 🛠 **Development Status:** RetroCloud is currently in active development. Stay tuned to this repository for early access and beta testing announcements!
