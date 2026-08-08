#!/usr/bin/env bash
set -e

# Експорт локалей для запобігання помилкам perl та apt
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export DEBIAN_FRONTEND=noninteractive

# ==============================================================================
# НАЛАШТУВАННЯ
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

# 🔍 ДЕТЕКТОР СЕРЕДОВИЩА (Chroot / Live-Build vs Installed OS)
IS_CHROOT=false
if [ "$(stat -c %d:%i / 2>/dev/null)" != "$(stat -c %d:%i /proc/1/root 2>/dev/null)" ] || [ -f /etc/debian_chroot ]; then
    IS_CHROOT=true
    echo "========================================================="
    echo " ==> Виявлено середовище: CHROOT / LIVE-BUILD"
    echo "========================================================="
else
    echo "========================================================="
    echo " ==> Виявлено середовище: ВСТАНОВЛЕНА СИСТЕМА"
    echo "========================================================="
fi

echo "=== 1. Оновлення системи та встановлення залежностей ==="
apt update && apt upgrade -y
apt install -y \
    xorg xinit openbox \
    build-essential git automake libsdl2-dev libsdl2-net-dev \
    libpcap-dev libslirp-dev libfluidsynth-dev fluid-soundfont-gm libpng-dev libfreetype6-dev \
    libglu1-mesa-dev libgl-dev \
    samba udev procps plymouth plymouth-themes pipewire-pulse wireplumber dbus-user-session sudo wget ca-certificates

systemctl --global disable fluidsynth 2>/dev/null || true

echo "=== 2. Створення користувача, прав sudo та системної тишини ==="
if ! id "retro" &>/dev/null; then
    useradd -m -s /bin/bash -G dialout,video,audio,input,cdrom,render retro
else
    groupadd -f retro
    usermod -aG dialout,video,audio,input,cdrom,render retro
fi

echo "retro ALL=(ALL:ALL) NOPASSWD: /sbin/poweroff" > /etc/sudoers.d/retro-poweroff
chmod 0440 /etc/sudoers.d/retro-poweroff

RETRO_DIR="/home/retro/retroconsole"
mkdir -p "$RETRO_DIR/images"
mkdir -p "$RETRO_DIR/share"

touch /home/retro/.hushlogin
truncate -s 0 /etc/issue 2>/dev/null || true
truncate -s 0 /etc/motd 2>/dev/null || true
chown -R retro:retro /home/retro

echo "=== 3. Завантаження образу Windows 98 з GitHub Releases ==="
IMG_TARGET="$RETRO_DIR/images/win98.img"
if [ ! -f "$IMG_TARGET" ]; then
    echo "Завантаження стиснутого образу Windows 98..."
    if wget --timeout=30 --tries=3 -O "$RETRO_DIR/images/win98.img.gz" "$WIN98_URL"; then
        echo "Розпакування образу..."
        gunzip -f "$RETRO_DIR/images/win98.img.gz"
    else
        echo "УВАГА: Не вдалося завантажити образ. Створення файлу-заглушки."
        rm -f "$RETRO_DIR/images/win98.img.gz"
        truncate -s 2G "$IMG_TARGET"
    fi
    chown retro:retro "$IMG_TARGET"
else
    echo "Образ $IMG_TARGET вже існує, пропускаємо завантаження."
fi

echo "=== 4. Конфігурація Samba для Windows 98 (SMBv1) ==="
cat << 'EOF' > /etc/samba/smb.conf
[global]
   netbios aliases = 10.0.2.2 RETRO-TEST
   smb ports = 139 445
   server min protocol = NT1
   client min protocol = NT1
   wins support = yes
   netbios name = RETROHOST
   name resolve order = wins lmhosts bcast
   ntlm auth = yes
   lanman auth = yes
   map to guest = Bad User
   guest account = nobody

[Retro]
   path = /home/retro/retroconsole/share
   read only = no
   guest ok = yes
   browsable = yes
   public = yes
   writeable = yes
   force user = retro
EOF

if [ "$IS_CHROOT" = false ]; then
    systemctl restart smbd nmbd 2>/dev/null || true
else
    systemctl enable smbd nmbd 2>/dev/null || true
fi

echo "=== 5. Компіляція та інсталяція DOSBox-X ==="
cd /usr/src
if [ ! -d "dosbox-x" ]; then
    git clone --depth 1 https://github.com/joncampbell123/dosbox-x.git
fi
cd dosbox-x
./build
make install

echo "=== 6. Повне маскування GRUB, KMS та Plymouth Award BIOS ==="

# Гарантуємо наявність необхідних директорій та файлів GRUB
mkdir -p /etc/default /etc/grub.d /boot/grub
touch /etc/default/grub

if [ -f /etc/grub.d/10_linux ]; then
    sed -i 's/quiet_boot=0/quiet_boot=1/g' /etc/grub.d/10_linux 2>/dev/null || true
fi

set_grub_var() {
    local key="$1"
    local val="$2"
    if grep -q "^${key}=" /etc/default/grub; then
        sed -i "s|^${key}=.*|${key}=${val}|" /etc/default/grub
    else
        echo "${key}=${val}" >> /etc/default/grub
    fi
}

set_grub_var "GRUB_TIMEOUT" "0"
set_grub_var "GRUB_TIMEOUT_STYLE" "hidden"
set_grub_var "GRUB_RECORDFAIL_TIMEOUT" "0"
set_grub_var "GRUB_DISABLE_OS_PROBER" "true"
set_grub_var "GRUB_GFXMODE" "1024x768x32"
set_grub_var "GRUB_GFXPAYLOAD_LINUX" "keep"
set_grub_var "GRUB_CMDLINE_LINUX_DEFAULT" '"quiet splash loglevel=0 vt.handoff=7 systemd.show_status=false rd.systemd.show_status=false rd.udev.log_level=0 quiet_boot fastboot vt.global_cursor_default=0"'

cat << 'EOF' > /etc/initramfs-tools/modules
simpledrm
efifb
vesafb
bochs_drm
virtio_gpu
qxl
drm
EOF

sed -i 's/^MODULES=.*/MODULES=most/' /etc/initramfs-tools/initramfs.conf 2>/dev/null || true

mkdir -p /etc/plymouth
cat << 'EOF' > /etc/plymouth/plymouthd.conf
[Daemon]
Theme=retro-bios
ShowDelay=0
DeviceTimeout=8
EOF

THEME_DIR="/usr/share/plymouth/themes/retro-bios"
mkdir -p "$THEME_DIR"

echo "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdom6EAAABDSURBVHhe7cExAQAAAMKg9U9tCj8gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA4A045AABjS24eAAAAABJRU5ErkJggg==" | tr -d '\r\n ' | base64 -d > "$THEME_DIR/energy_star.png"

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
energy_sprite.SetX(Window.GetWidth() - energy_image.GetWidth() - 50);
energy_sprite.SetY(40);

title_img = Image.Text("Award Modular BIOS v4.51PG, An Energy Star Ally", 0.8, 0.8, 0.8, "Monospace 12");
title_sp = Sprite(title_img); title_sp.SetX(40); title_sp.SetY(40);

copy_img = Image.Text("Copyright (C) 1984-98, Award Software, Inc.", 0.6, 0.6, 0.6, "Monospace 12");
copy_sp = Sprite(copy_img); copy_sp.SetX(40); copy_sp.SetY(65);

cpu_img = Image.Text("PENTIUM II CPU at 300MHz", 0.9, 0.9, 0.9, "Monospace 12");
cpu_sp = Sprite(cpu_img); cpu_sp.SetX(40); cpu_sp.SetY(105);

ram_sp = Sprite(); ram_sp.SetX(40); ram_sp.SetY(135);
disks_sp = Sprite(); disks_sp.SetX(40); disks_sp.SetY(175);

setup_img = Image.Text("Press DEL to enter SETUP", 0.8, 0.8, 0.2, "Monospace 12");
setup_sp = Sprite(setup_img); setup_sp.SetX(40); setup_sp.SetY(Window.GetHeight() - 70);

string_img = Image.Text("08/02/1998-i440BX-2A69KB0CC-00", 0.7, 0.7, 0.7, "Monospace 12");
string_sp = Sprite(string_img); string_sp.SetX(40); string_sp.SetY(Window.GetHeight() - 45);

fun boot_progress_cb(duration, progress) {
    ram_kb = Math.Int(progress * 262144);
    if (ram_kb > 262144) ram_kb = 262144;
    
    ram_txt = "Memory Testing : " + ram_kb + "K OK";
    ram_img = Image.Text(ram_txt, 0.9, 0.9, 0.9, "Monospace 12");
    ram_sp.SetImage(ram_img);

    if (progress > 0.3) {
        d_txt = "Detecting Primary Master    ... WIN98_RETRO.IMG\n";
        if (progress > 0.65) {
            d_txt = d_txt + "Detecting Primary Slave     ... DISK_E_RETRO.IMG\n";
        }
        if (progress > 0.85) {
            d_txt = d_txt + "Initializing PnP Network Adapter ... OK";
        }
        disks_img = Image.Text(d_txt, 0.0, 0.8, 0.8, "Monospace 12");
        disks_sp.SetImage(disks_img);
    }
}

Plymouth.SetBootProgressFunction(boot_progress_cb);
EOF

plymouth-set-default-theme -R retro-bios || true
update-initramfs -u -k all

if [ "$IS_CHROOT" = false ]; then
    update-grub || true
else
    echo "===> [ПРОПУЩЕНО] update-grub пропускається у середовищі chroot."
fi

echo "=== 7. Безшумний Автозапуск X11 & Kiosk Openbox ==="
mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat << 'EOF' > /etc/systemd/system/getty@tty1.service.d/autologin.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin retro --noissue --nohostname --noclear %I $TERM
Restart=always
RestartSec=2s
EOF

mkdir -p /home/retro/.config/openbox
cat << 'EOF' > /home/retro/.config/openbox/rc.xml
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <focus><focusNew>yes</focusNew><followMouse>no</followMouse><focusDelay>0</focusDelay></focus>
  <theme><name>Clearlooks</name><keepBorder>no</keepBorder></theme>
  <desktops><number>1</number></desktops>
  <mouse><context name="Client"></context></mouse>
  <applications>
    <application class="*" name="*">
      <decor>no</decor>
      <fullscreen>yes</fullscreen>
      <maximized>yes</maximized>
    </application>
  </applications>
</openbox_config>
EOF

cat << 'EOF' > /home/retro/.bash_profile
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx -- -nocursor -quiet >/dev/null 2>&1
fi
EOF

cat << 'EOF' > /home/retro/.xinitrc
#!/bin/sh
xset -dpms
xset s off
xset s noblank

openbox &

dosbox-x -conf /home/retro/retroconsole/dosbox-win98.conf -fullscreen

sudo /sbin/poweroff
EOF

chmod +x /home/retro/.xinitrc
chown -R retro:retro /home/retro/.config /home/retro/.bash_profile /home/retro/.xinitrc

echo "=== 8. Конфігурація DOSBox-X (APM + Мережа + Win98) ==="
cat << 'EOF' > "$RETRO_DIR/dosbox-win98.conf"
[sdl]
fullscreen=true
fullresolution=desktop
windowresolution=desktop
output=texture
autofit=true
autolock=true
mouse_capture=onload
clip_cursor_to_window=true
autolock_feedback=none

[render]
aspect=true
scaler=none

[dosbox]
title=RetroConsole Win98
memsize=256
ver=7.10
mouse_emulation=ps2
startbanner=false
confirm_exit=false
securemode=true
apm=true

[cpu]
core=dynamic_x86
cputype=pentium_mmx
cycles=max

[video]
vmemsize=32

[midi]
mididevice=fluidsynth

[fluidsynth]
soundfont=/usr/share/sounds/sf2/FluidR3_GM.sf2

[ne2000]
ne2000=true
nicbase=300
nicirq=3
backend=slirp

[ethernet, slirp]
mtu = 1500
mru = 1500
disable_host_loopback = false

[dos]
lba=true
file locking=false
share=true

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

umount $MOUNT_POINT 2>/dev/null || true
rmdir $MOUNT_POINT 2>/dev/null || true
EOF

chmod +x /usr/local/bin/retro-usb-sync.sh

if [ "$IS_CHROOT" = false ]; then
    udevadm control --reload-rules 2>/dev/null || true
fi

echo "========================================================="
echo " Інсталяція RetroConsole успішно завершена!"
echo "========================================================="
