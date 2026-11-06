#!/usr/bin/env bash
# VEILOS - Phase 1 build (Debian Stable + GNOME, Arabic/English)
# Run on Debian/Ubuntu:  chmod +x build-phase1.sh && ./build-phase1.sh
# License: GPL-3
set -euo pipefail

sudo apt update
sudo apt install -y live-build debootstrap squashfs-tools xorriso

mkdir -p veilos-build && cd veilos-build
sudo lb clean --purge || true

lb config \
  --distribution stable \
  --architectures amd64 \
  --archive-areas "main contrib non-free-firmware" \
  --binary-images iso-hybrid \
  --debian-installer live \
  --iso-application "VEILOS" \
  --iso-volume "VEILOS" \
  --iso-publisher "VEILOS Project" \
  --image-name "veilos" \
  --bootappend-live "boot=live components locales=ar_SA.UTF-8,en_US.UTF-8 keyboard-layouts=us,ara"

# ---- Packages (Phase 1) ----
mkdir -p config/package-lists
cat > config/package-lists/veilos.list.chroot <<'EOF'
task-gnome-desktop
task-arabic
task-english
fonts-noto
fonts-hosny-amiri
libreoffice
libreoffice-gnome
libreoffice-l10n-ar
vlc
gnome-software
gnome-software-plugin-flatpak
flatpak
unattended-upgrades
apt-listchanges
apparmor
apparmor-profiles
nftables
EOF

# Telemetry: make sure popularity-contest is never installed
cat > config/package-lists/veilos-remove.list.chroot <<'EOF'
EOF
mkdir -p config/hooks/normal
cat > config/hooks/normal/0100-no-telemetry.hook.chroot <<'EOF'
#!/bin/sh
apt-get purge -y popularity-contest reportbug 2>/dev/null || true
EOF

# Automatic security updates
mkdir -p config/includes.chroot/etc/apt/apt.conf.d
cat > config/includes.chroot/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Branding: OS name + logo (put your logo at ../assets/logo.jpg)
mkdir -p config/includes.chroot/etc config/includes.chroot/usr/share/veilos
cat > config/includes.chroot/etc/os-release <<'EOF'
PRETTY_NAME="VEILOS"
NAME="VEILOS"
ID=veilos
ID_LIKE=debian
HOME_URL="https://github.com/BlueW9"
EOF
for f in ../logo.jpg ../assets/logo.jpg; do
  [ -f "$f" ] && cp "$f" config/includes.chroot/usr/share/veilos/logo.jpg && break
done

sudo lb build 2>&1 | tee build.log
echo "Done. ISO: $(ls *.iso 2>/dev/null)"
