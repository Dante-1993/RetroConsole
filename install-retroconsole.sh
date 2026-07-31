#!/usr/bin/env bash
set -e

# ==============================================================================
# НАЛАШТУВАННЯ (Змініть під свій репозиторій)
# ==============================================================================
GITHUB_USER="Dante-1993"
GITHUB_REPO="RetroConsole"
RELEASE_TAG="v1.0.0"
IMG_NAME="win98.img.gz"
WIN98_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/${IMG_NAME}"
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "Будь ласка, запустіть скрипт від імені root."
  exit 1
fi

echo "=== 1. Оновлення системи та встановлення залежностей ==="
apt update && apt upgrade -y
apt install -y \
    cage seatd \
    build-essential git automake libsdl2-dev libsdl2-net-dev \
    libpcap-dev libslirp-dev libfluidsynth-dev libpng-dev libfreetype6-dev \
    samba udev procps plymouth wget gzip

echo "=== 2. Створення користувача та структури каталогів ==="
if ! id "retro" &>/dev/null; then
    useradd -m -s /bin/bash -G dialout,video,audio,input,cdrom,render retro
else
    groupadd -f retro
    usermod -aG dialout,video,audio,input,cdrom,render retro
fi
RETRO_DIR="/home/retro/retroconsole"
mkdir -p "$RETRO_DIR/images"
mkdir -p "$RETRO_DIR/share"
chown -R retro:retro /home/retro

echo "=== 3. Завантаження образу Windows 98 з GitHub Releases ==="
IMG_TARGET="$RETRO_DIR/images/win98.img"
if [ ! -f "$IMG_TARGET" ]; then
    echo "Завантаження стиснутого образу Windows 98..."
    wget -O "$RETRO_DIR/images/win98.img.gz" "$WIN98_URL"
    echo "Розпакування образу..."
    gunzip -f "$RETRO_DIR/images/win98.img.gz"
    chown retro:retro "$IMG_TARGET"
else
    echo "Образ $IMG_TARGET вже існує, пропускаємо завантаження."
fi

echo "=== 4. Конфігурація Samba для Windows 98 (SMBv1) ==="
cat << 'EOF' > /etc/samba/smb.conf
[global]
   workgroup = WORKGROUP
   server string = RetroConsole
   netbios name = RETROCONSOLE
   security = user
   map to guest = bad user

   # --- Сумісність з Windows 98 (Debian 13 FIX) ---
   server min protocol = NT1
   lanman auth = yes
   ntlm auth = yes
   client NTLMv2 auth = no

[isos]
   path = /home/retro/retroconsole/share
   read only = no
   browsable = yes
   guest ok = yes
   public = yes
   writable = yes
   force user = retro
EOF

systemctl restart smbd nmbd

echo "=== 5. Компіляція та інсталяція DOSBox-X ==="
cd /usr/src
if [ ! -d "dosbox-x" ]; then
    git clone --depth 1 https://github.com/joncampbell123/dosbox-x.git
fi
cd dosbox-x
./build-debug-sdl2
make -j$(nproc)
make install

echo "=== 6. Налаштування Silent Boot & Plymouth Retro BIOS ==="
cat << 'EOF' > /etc/default/grub.d/quiet-boot.conf
GRUB_TIMEOUT=0
GRUB_RECORDFAIL_TIMEOUT=0
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=0 vt.handoff=7 console=tty12 rd.systemd.show_status=false rd.udev.log_level=0 quiet_boot fastboot"
EOF

update-grub
echo "setterm -cursor off" >> /etc/issue

# Створення теми Plymouth retro-bios
THEME_DIR="/usr/share/plymouth/themes/retro-bios"
mkdir -p "$THEME_DIR"
echo "iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAYAAABXAvmHAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdom6EAAAAOSURBVHgB7cEBDAAAAMGg+zz/4m4UAAAAAAAAAAAAD1sAARkAAW5S5/oAAAAASUVORK5CYII=" | tr -d '\r\n ' | base64 -d > "$THEME_DIR/energy_star.png"
cat << 'EOF' > "$THEME_DIR/retro-bios.plymouth"
[Plymouth Theme]
Name=Retro BIOS
Description=Award BIOS POST Screen Replica
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/retro-bios
ScriptFile=/usr/share/plymouth/themes/retro-bios/retro-bios.script
EOF

cat << 'EOF' > "$THEME_DIR/retro-bios.script"
Window.SetBackgroundTopColor(0.0, 0.0, 0.0);
Window.SetBackgroundBottomColor(0.0, 0.0, 0.0);

energy_image = Image("energy_star.png");
energy_sprite = Sprite(energy_image);
energy_x = Window.GetWidth() - energy_image.GetWidth() - 40;
energy_y = 30;
energy_sprite.SetX(energy_x);
energy_sprite.SetY(energy_y);
energy_sprite.SetOpacity(1.0);

title = Image.Text("Award Modular BIOS v4.51PG, An Energy Star Ally", 0.7, 0.7, 0.7);
s_title = Sprite(title); s_title.SetX(40); s_title.SetY(30);

copy = Image.Text("Copyright (C) 1984-98, Award Software, Inc.", 0.7, 0.7, 0.7);
s_copy = Sprite(copy); s_copy.SetX(40); s_copy.SetY(50);

cpu = Image.Text("Pentium II Processor - 300MHz", 0.9, 0.9, 0.9);
s_cpu = Sprite(cpu); s_cpu.SetX(40); s_cpu.SetY(90);

ram = Image.Text("Memory Testing : 262144K OK", 0.9, 0.9, 0.9);
s_ram = Sprite(ram); s_ram.SetX(40); s_ram.SetY(115);

disks = Image.Text("Primary Master   : RETRO-HDD 8.4GB\nPrimary Slave    : None\nSecondary Master : CD-ROM Drive", 0.7, 0.7, 0.7);
s_disks = Sprite(disks); s_disks.SetX(40); s_disks.SetY(155);

press = Image.Text("Press DEL to enter SETUP", 0.6, 0.6, 0.6);
s_press = Sprite(press); s_press.SetX(40); s_press.SetY(230);

status = Image.Text("BOOT: Starting Windows 98...", 0.2, 0.8, 0.2);
s_status = Sprite(status); s_status.SetX(40); s_status.SetY(260);
EOF

plymouth-set-default-theme -R retro-bios
update-initramfs -u

echo "=== 7. Автозапуск Wayland-середовища (Cage Kiosk) ==="
mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat << 'EOF' > /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin retro --noclear %I $TERM
EOF

cat << 'EOF' > /home/retro/.bash_profile
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    export SDL_VIDEODRIVER=wayland
    export XDG_SESSION_TYPE=wayland
    exec cage -s -- dosbox-x -conf /home/retro/retroconsole/dosbox-win98.conf
fi
EOF

# Видаляємо застарілий .xinitrc якщо він був
rm -f /home/retro/.xinitrc
chown retro:retro /home/retro/.bash_profile

echo "=== 8. Конфігурація DOSBox-X (Мережа + Win98) ==="
cat << 'EOF' > "$RETRO_DIR/dosbox-win98.conf"
[sdl]
fullscreen=true
output=opengl
autofit=true

[render]
aspect=true
scaler=none

[dosbox]
title=RetroConsole Win98
memsize=256
ver=7.10

[cpu]
core=dynamic
cputype=pentium
cycles=max

[ne2000]
ne2000=true
nicbase=300
nicirq=3
backend=slirp

[autoexec]
@echo off
ver set 7.10
imgmount c /home/retro/retroconsole/images/win98.img -t hdd -fs fat
boot -l c
EOF

chown -R retro:retro "$RETRO_DIR"

echo "=== 9. Налаштування udev для Авто-копіювання ISO з USB ==="
cat << 'EOF' > /etc/udev/rules.d/99-retro-usb.rules
ACTION=="add", SUBSYSTEMS=="usb", KERNEL=="sd[b-z][0-9]", RUN+="/usr/local/bin/retro-usb-sync.sh %k"
EOF

cat << 'EOF' > /usr/local/bin/retro-usb-sync.sh
#!/bin/bash
DEV=$1
MOUNT_POINT="/tmp/usb_retro"
SHARE_DIR="/home/retro/retroconsole/share"

mkdir -p "$MOUNT_POINT"
mkdir -p "$SHARE_DIR"

mount /dev/$DEV $MOUNT_POINT

if [ -d "$MOUNT_POINT/retro_isos" ]; then
    cp -u $MOUNT_POINT/retro_isos/*.iso "$SHARE_DIR/" 2>/dev/null || true
    chown -R retro:retro "$SHARE_DIR"
fi

umount $MOUNT_POINT
rmdir $MOUNT_POINT
EOF

chmod +x /usr/local/bin/retro-usb-sync.sh
udevadm control --reload-rules

echo "========================================================="
echo " Інсталяція RetroConsole успішно завершена!"
echo " Перезавантажте систему за допомогою команди: reboot"
echo "========================================================="
