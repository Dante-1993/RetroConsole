# 🎮 RetroConsole OS

> **Turn any modern PC, laptop, or Raspberry Pi into a dedicated Windows 98 machine.**

> **RetroConsole is not an emulator launcher.** It is a complete, self-contained retro operating environment built to make modern hardware behave like a dedicated 1998 computer.

---

## 📸 Screenshots & Showcase

| Phase 1: Custom Installer | Phase 2: Setup Slideshow |
| :---: | :---: |
| ![RetroConsole Installer Setup](https://via.placeholder.com/400x250.png?text=RetroConsole+Setup) | ![Windows 98 Setup Promo](https://via.placeholder.com/400x250.png?text=Win98+Setup+Slideshow) |

| Award BIOS POST Screen | Running Windows 98 |
| :---: | :---: |
| ![Award BIOS POST Screen](https://via.placeholder.com/400x250.png?text=Award+BIOS+POST) | ![Windows 98 Desktop](https://via.placeholder.com/400x250.png?text=Windows+98+Desktop) |

---

## ⚡ Why RetroConsole?

* **✔ Zero Driver Hunting:** No searching for legacy SATA, GPU, or motherboard drivers.
* **✔ Bare-Metal Feel:** Boots seamlessly with Award BIOS POST simulations and zero Linux text output.
* **✔ Plug & Play Media:** Insert a USB flash drive with games or ISOs — RetroConsole handles the rest.
* **✔ Perfect Audio Hardware:** Built-in General MIDI via FluidSynth, Sound Blaster 16/AWE32, and Gravis Ultrasound (GUS) support.
* **✔ Modern Network Bridge:** Integrated SMBv1 Samba server allows transferring files directly from your main PC.
* **✔ Hardware Accelerated:** OpenGL 2.1/3.x rendering for crystal-clear scaling without aspect ratio distortion.

---

## 🏗️ Architecture: How It Works

```text
               ┌────────────────────────────────────────┐
               │    Modern Hardware / Virtual Machine   │
               │   (x86_64 / ARM64, NVMe, UEFI, GPU)    │
               └───────────────────┬────────────────────┘
                                   │
                                   ▼
               ┌────────────────────────────────────────┐
               │         Micro Linux Runtime            │
               │   (Debian 13 Kernel + Silent Boot)     │
               └───────────────────┬────────────────────┘
                                   │
                                   ▼
               ┌────────────────────────────────────────┐
               │         RetroConsole Core              │
               │   (DOSBox-X + FluidSynth + Samba)      │
               └───────────────────┬────────────────────┘
                                   │
                                   ▼
               ┌────────────────────────────────────────┐
               │         Windows 98 OS / MS-DOS         │
               │ (Dedicated Fullscreen Kiosk Experience)│
               └────────────────────────────────────────┘
