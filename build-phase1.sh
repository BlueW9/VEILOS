#!/usr/bin/env bash
# VEILOS - Phase 1 + 2 + 3a + 3b + 3c + 3d + 4 build (Debian Stable + GNOME, Arabic/English)
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
systemd-resolved
pkexec
polkitd
dconf-cli
apparmor-utils
clamav
clamav-daemon
clamav-freshclam
curl
ca-certificates
gnupg
gnome-shell-extension-appindicator
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
PRETTY_NAME="VEILOS 26.11 (Sitar)"
NAME="VEILOS"
VERSION_ID="13"
VERSION="26.11 (Sitar)"
VERSION_CODENAME=trixie
ID=debian
HOME_URL="https://github.com/BlueW9/VEILOS"
VEILOS_VERSION="26.11"
VEILOS_CODENAME="Sitar"
VEILOS_STAGE="alpha"
EOF
for f in ../logo.jpg ../assets/logo.jpg; do
  [ -f "$f" ] && cp "$f" config/includes.chroot/usr/share/veilos/logo.jpg && break
done

# ================= PHASE 2: hardening & privacy =================

# --- Kernel / network hardening ---
mkdir -p config/includes.chroot/etc/sysctl.d
cat > config/includes.chroot/etc/sysctl.d/99-veilos-hardening.conf <<'EOF'
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
kernel.yama.ptrace_scope = 1
kernel.randomize_va_space = 2
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
EOF

mkdir -p config/includes.chroot/etc/modprobe.d
cat > config/includes.chroot/etc/modprobe.d/veilos-blacklist.conf <<'EOF'
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false
install firewire-core /bin/false
EOF

# --- Firewall: block all incoming by default ---
cat > config/includes.chroot/etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f
flush ruleset
table inet filter {
  chain input {
    type filter hook input priority filter; policy drop;
    iif lo accept
    ct state established,related accept
    ct state invalid drop
    ip protocol icmp accept
    ip6 nexthdr icmpv6 accept
    udp sport 67 udp dport 68 accept
    udp sport 547 udp dport 546 accept
  }
  chain forward {
    type filter hook forward priority filter; policy drop;
  }
  chain output {
    type filter hook output priority filter; policy accept;
  }
}
EOF

# --- Quad9 encrypted DNS (DNS-over-TLS), on by default, with on/off switch ---
mkdir -p config/includes.chroot/usr/share/veilos \
         config/includes.chroot/etc/systemd/resolved.conf.d \
         config/includes.chroot/etc/tmpfiles.d \
         config/includes.chroot/usr/local/bin \
         config/includes.chroot/usr/share/applications

cat > config/includes.chroot/usr/share/veilos/quad9.conf <<'EOF'
[Resolve]
DNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net 2620:fe::9#dns.quad9.net
Domains=~.
DNSOverTLS=yes
DNSSEC=allow-downgrade
FallbackDNS=
EOF
cp config/includes.chroot/usr/share/veilos/quad9.conf \
   config/includes.chroot/etc/systemd/resolved.conf.d/10-veilos-quad9.conf

# make /etc/resolv.conf point to systemd-resolved at every boot
cat > config/includes.chroot/etc/tmpfiles.d/veilos-resolv.conf <<'EOF'
L+ /etc/resolv.conf - - - - /run/systemd/resolve/stub-resolv.conf
EOF

cat > config/includes.chroot/usr/local/bin/veilos-dns <<'EOF'
#!/bin/sh
# Usage: veilos-dns on|off|status   (run as root)
DEST=/etc/systemd/resolved.conf.d/10-veilos-quad9.conf
SRC=/usr/share/veilos/quad9.conf
case "$1" in
  on)  mkdir -p /etc/systemd/resolved.conf.d && cp "$SRC" "$DEST" \
         && systemctl restart systemd-resolved && echo "Quad9 DNS: ON" ;;
  off) rm -f "$DEST" && systemctl restart systemd-resolved && echo "Quad9 DNS: OFF" ;;
  status) if [ -f "$DEST" ]; then echo "Quad9 DNS: ON"; else echo "Quad9 DNS: OFF"; fi ;;
  *) echo "usage: veilos-dns on|off|status"; exit 1 ;;
esac
EOF
chmod +x config/includes.chroot/usr/local/bin/veilos-dns

cat > config/includes.chroot/usr/share/applications/veilos-dns-on.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Quad9 DNS: Enable
Name[ar]=Quad9 DNS: تفعيل
Exec=pkexec /usr/local/bin/veilos-dns on
Icon=network-wired
Categories=Network;Settings;
EOF

cat > config/includes.chroot/usr/share/applications/veilos-dns-off.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Quad9 DNS: Disable
Name[ar]=Quad9 DNS: إيقاف
Exec=pkexec /usr/local/bin/veilos-dns off
Icon=network-offline
Categories=Network;Settings;
EOF

# --- GNOME privacy defaults, screen lock, keyboard layouts ---
mkdir -p config/includes.chroot/etc/dconf/profile config/includes.chroot/etc/dconf/db/local.d
printf 'user-db:user\nsystem-db:local\n' > config/includes.chroot/etc/dconf/profile/user
cat > config/includes.chroot/etc/dconf/db/local.d/00-veilos <<'EOF'
[org/gnome/desktop/privacy]
report-technical-problems=false
send-software-usage-stats=false

[org/gnome/system/location]
enabled=false

[org/gnome/desktop/screensaver]
lock-enabled=true
lock-delay=uint32 0

[org/gnome/desktop/session]
idle-delay=uint32 300

[org/gnome/desktop/input-sources]
sources=[('xkb', 'us'), ('xkb', 'ara')]
xkb-options=['grp:alt_shift_toggle']
EOF

# --- Hook: enable services, apply dconf, disable network-discovery services ---
cat > config/hooks/normal/0200-hardening.hook.chroot <<'EOF'
#!/bin/sh
dconf update || true
systemctl enable nftables apparmor systemd-resolved unattended-upgrades 2>/dev/null || true
systemctl disable avahi-daemon cups-browsed 2>/dev/null || true
EOF

# --- Installer: hardened kernel parameters, no popularity-contest ---
mkdir -p config/includes.installer
cat > config/includes.installer/preseed.cfg <<'EOF'
d-i debian-installer/add-kernel-opts string slab_nomerge init_on_alloc=1 page_alloc.shuffle=1 randomize_kstack_offset=on vsyscall=none debugfs=off
popularity-contest popularity-contest/participate boolean false
EOF

# ================= end of phase 2 =================

# ================= PHASE 3 (batch 1): LibreWolf + ClamAV =================

# --- LibreWolf from its official repo (via Debian's extrepo tool) ---
cat > config/hooks/normal/0150-librewolf.hook.chroot <<'EOF'
#!/bin/sh
set -e
apt-get update
apt-get install -y extrepo
extrepo enable librewolf
apt-get update
apt-get install -y librewolf
EOF

# let unattended-upgrades also update LibreWolf automatically
cat > config/includes.chroot/etc/apt/apt.conf.d/52veilos-unattended <<'EOF'
Unattended-Upgrade::Origins-Pattern {
  "site=repo.librewolf.net";
  "site=repo.protonvpn.com";
  "site=updates.signal.org";
};
EOF

# LibreWolf as the default browser
mkdir -p config/includes.chroot/etc/xdg
cat > config/includes.chroot/etc/xdg/mimeapps.list <<'EOF'
[Default Applications]
text/html=librewolf.desktop
x-scheme-handler/http=librewolf.desktop
x-scheme-handler/https=librewolf.desktop
EOF

cat > config/includes.chroot/etc/dconf/db/local.d/01-veilos-apps <<'EOF'
[org/gnome/shell]
favorite-apps=['librewolf.desktop', 'org.gnome.Nautilus.desktop', 'vlc.desktop', 'io.freetubeapp.FreeTube.desktop', 'signal-desktop.desktop', 'chat.simplex.simplex.desktop', 'org.standardnotes.standardnotes.desktop', 'libreoffice-startcenter.desktop', 'org.gnome.Software.desktop']
EOF

# --- ClamAV with real-time (on-access) scanning ---
mkdir -p config/includes.chroot/etc/systemd/system
cat > config/includes.chroot/etc/systemd/system/clamonacc.service <<'EOF'
[Unit]
Description=ClamAV On-Access Scanner
Requires=clamav-daemon.service
After=clamav-daemon.service

[Service]
Type=simple
ExecStart=/bin/sh -c 'exec "$(command -v clamonacc)" -F --fdpass --log=/var/log/clamav/clamonacc.log'
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

cat > config/hooks/normal/0300-clamav.hook.chroot <<'EOF'
#!/bin/sh
cat >> /etc/clamav/clamd.conf <<'CONF'

# VEILOS on-access scanning
OnAccessIncludePath /home
OnAccessPrevention yes
OnAccessExcludeUname clamav
OnAccessExcludeRootUID yes
CONF
# bake in an initial signature database (needs network at build time)
freshclam || true
systemctl enable clamav-daemon clamav-freshclam clamonacc || true
EOF

chmod +x config/hooks/normal/*.hook.chroot

# ================= end of phase 3 (batch 1) =================

# ================= PHASE 3 (batch 2): Proton VPN, FreeTube, Standard Notes =================

# --- Proton VPN from Proton's official apt repository ---
cat > config/hooks/normal/0400-protonvpn.hook.chroot <<'EOF'
#!/bin/sh
V=$(curl -fsSL https://repo.protonvpn.com/debian/dists/stable/main/binary-all/ 2>/dev/null \
    | grep -o 'protonvpn-stable-release_[0-9.]*_all\.deb' | sort -uV | tail -1)
[ -z "$V" ] && V=protonvpn-stable-release_1.0.10_all.deb
echo "Proton VPN release package: $V"
curl -fsSL -o /tmp/protonvpn-release.deb \
  "https://repo.protonvpn.com/debian/dists/stable/main/binary-all/$V" \
  && dpkg -i /tmp/protonvpn-release.deb \
  && apt-get update \
  && apt-get install -y proton-vpn-gnome-desktop \
  || echo "VEILOS-WARN: Proton VPN install failed"
rm -f /tmp/protonvpn-release.deb
EOF

# --- FreeTube + Standard Notes from Flathub (Flatpak) ---
cat > config/hooks/normal/0500-flatpak-apps.hook.chroot <<'EOF'
#!/bin/sh
flatpak remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
  || echo "VEILOS-WARN: could not add Flathub"
flatpak install --system -y --noninteractive flathub \
  io.freetubeapp.FreeTube \
  org.standardnotes.standardnotes \
  chat.simplex.simplex \
  || echo "VEILOS-WARN: Flatpak apps (FreeTube / Standard Notes) install failed"
EOF

# automatic Flatpak updates (boot + daily)
cat > config/includes.chroot/etc/systemd/system/veilos-flatpak-update.service <<'EOF'
[Unit]
Description=Update Flatpak apps
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/flatpak update --system -y --noninteractive
EOF

cat > config/includes.chroot/etc/systemd/system/veilos-flatpak-update.timer <<'EOF'
[Unit]
Description=Daily Flatpak app updates

[Timer]
OnBootSec=10min
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF

cat > config/hooks/normal/0600-enable-timers.hook.chroot <<'EOF'
#!/bin/sh
systemctl enable veilos-flatpak-update.timer || true
EOF

chmod +x config/hooks/normal/*.hook.chroot

# ================= end of phase 3 (batch 2) =================

# ================= PHASE 3 (batch 3): AsterMail + updater for .deb apps =================

# Updater for apps that ship only a .deb (no apt repository).
# Each app has a small config file in /usr/share/veilos/apps/*.conf (NAME, PKG, URL).
cat > config/includes.chroot/usr/local/bin/veilos-app-update <<'EOF'
#!/bin/sh
# Updates .deb apps that have no apt repository. Runs as root from a systemd timer.
for conf in /usr/share/veilos/apps/*.conf; do
  [ -f "$conf" ] || continue
  NAME=; PKG=; URL=
  . "$conf"
  [ -n "$PKG" ] && [ -n "$URL" ] || continue
  tmp=$(mktemp -d)
  if curl -fsSL --max-time 900 -o "$tmp/app.deb" "$URL"; then
    newpkg=$(dpkg-deb -f "$tmp/app.deb" Package 2>/dev/null)
    newver=$(dpkg-deb -f "$tmp/app.deb" Version 2>/dev/null)
    curver=$(dpkg-query -W -f='${Version}' "$PKG" 2>/dev/null)
    # safety: only install if it is the same package and a newer version
    if [ "$newpkg" = "$PKG" ] && [ -n "$newver" ] \
       && dpkg --compare-versions "$newver" gt "${curver:-0}"; then
      apt-get install -y "$tmp/app.deb" && echo "$NAME updated to $newver"
    fi
  fi
  rm -rf "$tmp"
done
EOF
chmod +x config/includes.chroot/usr/local/bin/veilos-app-update

cat > config/includes.chroot/etc/systemd/system/veilos-app-update.service <<'EOF'
[Unit]
Description=Update VEILOS .deb apps
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/veilos-app-update
EOF

cat > config/includes.chroot/etc/systemd/system/veilos-app-update.timer <<'EOF'
[Unit]
Description=Daily check for VEILOS .deb app updates

[Timer]
OnBootSec=15min
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF

cat >> config/hooks/normal/0600-enable-timers.hook.chroot <<'EOF'
systemctl enable veilos-app-update.timer || true
EOF

# --- AsterMail (official .deb) ---
cat > config/hooks/normal/0700-astermail.hook.chroot <<'EOF'
#!/bin/sh
mkdir -p /usr/share/veilos/apps
URL=https://astermail.org/dl/linux-deb
if curl -fsSL -o /tmp/aster.deb "$URL"; then
  PKG=$(dpkg-deb -f /tmp/aster.deb Package 2>/dev/null)
  if [ -n "$PKG" ] && apt-get install -y /tmp/aster.deb; then
    printf 'NAME=AsterMail\nPKG=%s\nURL=%s\n' "$PKG" "$URL" > /usr/share/veilos/apps/astermail.conf
  else
    echo "VEILOS-WARN: AsterMail install failed"
  fi
else
  echo "VEILOS-WARN: AsterMail download failed"
fi
rm -f /tmp/aster.deb
EOF

chmod +x config/hooks/normal/*.hook.chroot

# ================= end of phase 3 (batch 3) =================

# ================= PHASE 3 (batch 4): Signal, Proton Pass, Proton Authenticator =================

# --- Signal Desktop from Signal's official apt repository ---
cat > config/hooks/normal/0650-signal.hook.chroot <<'EOF'
#!/bin/sh
curl -fsSL https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > /usr/share/keyrings/signal-desktop-keyring.gpg \
  && curl -fsSL -o /etc/apt/sources.list.d/signal-desktop.sources https://updates.signal.org/static/desktop/apt/signal-desktop.sources \
  && apt-get update \
  && apt-get install -y signal-desktop \
  || echo "VEILOS-WARN: Signal install failed"
EOF

# --- Proton Pass + Proton Authenticator (official .deb files, kept updated by veilos-app-update) ---
cat > config/hooks/normal/0710-proton-debs.hook.chroot <<'EOF'
#!/bin/sh
mkdir -p /usr/share/veilos/apps
for item in \
  "ProtonPass|https://proton.me/download/PassDesktop/linux/x64/ProtonPass.deb" \
  "ProtonAuthenticator|https://proton.me/download/authenticator/linux/ProtonAuthenticator.deb"; do
  NAME=${item%%|*}
  URL=${item#*|}
  if curl -fsSL -o "/tmp/$NAME.deb" "$URL"; then
    PKG=$(dpkg-deb -f "/tmp/$NAME.deb" Package 2>/dev/null)
    if [ -n "$PKG" ] && apt-get install -y "/tmp/$NAME.deb"; then
      printf 'NAME=%s\nPKG=%s\nURL=%s\n' "$NAME" "$PKG" "$URL" > "/usr/share/veilos/apps/$NAME.conf"
    else
      echo "VEILOS-WARN: $NAME install failed"
    fi
  else
    echo "VEILOS-WARN: $NAME download failed"
  fi
  rm -f "/tmp/$NAME.deb"
done
EOF

chmod +x config/hooks/normal/*.hook.chroot

# ================= end of phase 3 (batch 4) =================

# ================= PHASE 4: branding (wallpaper + logo) =================
mkdir -p config/includes.chroot/usr/share/backgrounds/veilos config/includes.chroot/usr/share/pixmaps
for f in ../veilos-wallpaper.png ../branding/wallpaper.png; do
  [ -f "$f" ] && cp "$f" config/includes.chroot/usr/share/backgrounds/veilos/wallpaper.png && break
done
for f in ../veilos-logo.png ../branding/logo.png; do
  [ -f "$f" ] && cp "$f" config/includes.chroot/usr/share/pixmaps/veilos-logo.png && break
done
cat > config/includes.chroot/etc/dconf/db/local.d/02-veilos-background <<'EOF'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/veilos/wallpaper.png'
picture-uri-dark='file:///usr/share/backgrounds/veilos/wallpaper.png'
picture-options='zoom'
primary-color='#0d0e15'

[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/veilos/wallpaper.png'
picture-options='zoom'
primary-color='#0d0e15'
EOF
# ================= end of phase 4 =================

sudo lb build 2>&1 | tee build.log

# ---------- verify what actually ended up inside the image ----------
# Any problem is appended to build.log as a VEILOS-WARN line, so the
# GitHub run summary shows it.
warn() { echo "VEILOS-WARN: $1" | tee -a build.log; }
chk_pkg() {
  c=$(grep -A8 "^Package: $1\$" chroot/var/lib/dpkg/status 2>/dev/null | grep -c "^Status: install ok installed" || true)
  [ "${c:-0}" -ge 1 ] || warn "package not installed in image: $1"
}
if [ ! -d chroot ]; then warn "verify: chroot directory not found, could not check image contents"; fi
for p in librewolf signal-desktop proton-vpn-gnome-desktop vlc libreoffice-core clamav-daemon \
         gnome-software nftables unattended-upgrades systemd-resolved flatpak; do
  chk_pkg "$p"
done
n=$(ls chroot/usr/share/veilos/apps/*.conf 2>/dev/null | wc -l)
[ "$n" -eq 3 ] || warn "expected 3 .deb apps (AsterMail, ProtonPass, ProtonAuthenticator), found $n"
for f in chroot/usr/share/veilos/apps/*.conf; do
  [ -f "$f" ] || continue
  chk_pkg "$(sed -n 's/^PKG=//p' "$f")"
done
for id in io.freetubeapp.FreeTube org.standardnotes.standardnotes chat.simplex.simplex; do
  [ -d "chroot/var/lib/flatpak/app/$id" ] || warn "flatpak app missing in image: $id"
done
for f in usr/share/backgrounds/veilos/wallpaper.png usr/share/pixmaps/veilos-logo.png \
         etc/nftables.conf etc/sysctl.d/99-veilos-hardening.conf \
         etc/systemd/resolved.conf.d/10-veilos-quad9.conf etc/dconf/db/local \
         usr/local/bin/veilos-dns usr/local/bin/veilos-app-update; do
  [ -e "chroot/$f" ] || warn "file missing in image: $f"
done
grep -q '^VERSION_CODENAME=trixie' chroot/etc/os-release 2>/dev/null \
  || warn "os-release VERSION_CODENAME is not trixie (automatic security updates could break)"
grep -h "VEILOS-WARN" build.log || echo "No VEILOS-WARN: all app installs reported OK"
echo "Done. ISO: $(ls *.iso 2>/dev/null)"
