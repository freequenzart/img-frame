#!/bin/bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo 'Bitte mit sudo bash install.sh starten.' >&2
    exit 1
fi
source /etc/os-release
if [[ ${ID} != raspbian && ${ID} != debian ]] || [[ ! -x /usr/bin/raspi-config ]]; then
    echo 'Dieses Installationsskript benoetigt Raspberry Pi OS Lite.' >&2
    exit 1
fi
if [[ ${VERSION_CODENAME:-} != trixie && ${VERSION_CODENAME:-} != bookworm ]]; then
    echo 'Unterstuetzt werden Raspberry Pi OS Lite Bookworm und Trixie.' >&2
    exit 1
fi
SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends chromium xserver-xorg xinit \
    x11-xserver-utils xauth unclutter matchbox-window-manager dbus-x11 \
    libpam-systemd python3 ca-certificates fonts-dejavu-core avahi-daemon

if ! id kiosk >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash kiosk
fi
if [[ $(id -u kiosk) -eq 0 ]] || id -nG kiosk | grep -qw sudo; then
    echo 'Der Benutzer kiosk darf weder root noch Mitglied der Gruppe sudo sein.' >&2
    exit 1
fi
usermod --lock kiosk
for group in video render input audio; do
    if getent group "$group" >/dev/null; then
        usermod -aG "$group" kiosk
    fi
done
KIOSK_HOME=$(getent passwd kiosk | cut -d: -f6)
install -d -o kiosk -g kiosk -m 700 /var/lib/img-frame
install -d -m 755 /usr/local/lib/img-frame
install -m 755 "$SOURCE_DIR/files/img-frame-config.py" /usr/local/bin/img-frame-config
install -m 755 "$SOURCE_DIR/files/launch.sh" /usr/local/lib/img-frame/launch
install -m 755 "$SOURCE_DIR/files/session.sh" /usr/local/lib/img-frame/session
if [[ -f "$KIOSK_HOME/.bash_profile" && ! -f "$KIOSK_HOME/.bash_profile.before-img-frame" ]]; then
    cp -a "$KIOSK_HOME/.bash_profile" "$KIOSK_HOME/.bash_profile.before-img-frame"
fi
install -o kiosk -g kiosk -m 644 "$SOURCE_DIR/files/kiosk.bash_profile" "$KIOSK_HOME/.bash_profile"
install -D -m 644 "$SOURCE_DIR/files/autologin.conf" /etc/systemd/system/getty@tty1.service.d/90-img-frame.conf
systemctl set-default multi-user.target
systemctl enable getty@tty1.service avahi-daemon.service
if [[ ${1:-} != --image ]]; then
    systemctl daemon-reload
fi
echo 'Installation abgeschlossen. Nach einem Neustart wird die Kiosk-URL abgefragt.'