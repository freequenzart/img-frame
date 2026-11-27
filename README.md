# img-frame

A lightweight browser kiosk based on Raspberry Pi OS Lite: no desktop, just X11,
a minimal window manager, and Chromium in fullscreen mode. Based on this
[Smart Mirror guide](https://github.com/freequenzart/Smart-Mirror-with-Home-Assistant).

Repository: [freequenzart/img-frame](https://github.com/freequenzart/img-frame).

Target hardware: Raspberry Pi Zero 2 W and newer models. Both 32-bit (`armhf`)
and 64-bit (`arm64`) systems are supported. For the Zero 2 W with its 512 MB of
RAM, 32-bit remains the recommended choice; 64-bit is possible but tends to use
more memory. Complex websites and Home Assistant dashboards may exceed the
available memory. First-generation Raspberry Pi Zero / Zero W models are not
supported.

## Behavior

- On the first kiosk start, a URL prompt appears on the text console.
  A USB keyboard is required; there is no touchscreen setup interface.
- Example: `http://homeassistant.local:8123/dashboard-mirror/0`.
- The browser then starts, and the address is preserved across reboots.
- On subsequent starts, the browser opens directly. The mouse pointer is hidden
  and the screensaver is disabled. The browser restarts if it exits or crashes.
- The browser profile and login sessions are preserved. Chromium does not run as
  root, and its sandbox remains enabled. No additional configuration web server is started.
- The Raspberry Pi Chromium launcher's RAM warning ("less than 1GB of RAM")
  is skipped in kiosk mode using `--no-memcheck`. This only suppresses the dialog;
  it does not increase available memory or disable the sandbox.

## Quick Start on a Pi

1. Write Raspberry Pi OS Lite (32-bit or 64-bit), Trixie or Bookworm, to the SD card.
   Use Raspberry Pi Imager to configure your own admin account and Wi-Fi; enable SSH only if needed.
2. Start the Pi, sign in as the admin user, and clone the repository:

  ```bash
  sudo apt update
  sudo apt install -y git
  git clone https://github.com/freequenzart/img-frame.git "$HOME/img-frame"
  ```

3. Run as the admin user:

   ```bash
   cd ~/img-frame
   sudo bash install.sh
   sudo reboot
   ```

4. Enter the URL using the connected keyboard. The kiosk then starts.

The installer requires internet access to download packages. It reserves the `kiosk`
user, that user's login profile, and automatic login on console 1 for the kiosk.
An existing login profile is backed up once. Use a different username for your admin
account. Reinstalling preserves the existing URL and browser data. The script does
not change Wi-Fi credentials or graphics drivers. `apt` automatically selects packages
for the installed OS architecture; no separate 64-bit installer is required.

## Changing the URL Later

Sign in as the admin user via SSH, or locally by pressing `Ctrl+Alt+F2`:

```bash
sudo img-frame-config --restart
```

Alternatively, set the new address directly:

```bash
sudo img-frame-config --set 'http://192.168.1.50:8123/dashboard-mirror/0' --restart
```

Press `Ctrl+Alt+F1` to return to the kiosk. `--restart` terminates and restarts the
entire running kiosk session, including on console 1. Without this option, the new
URL takes effect on the next kiosk start. An empty input keeps the current address.

```bash
sudo img-frame-config --get
sudo img-frame-config --reset --restart
```

`--reset` only restores the URL prompt; it does not clear browser login sessions.
The URL is stored in `/var/lib/img-frame/config.json`, and the browser profile in
`/home/kiosk/.config/img-frame/chromium`. URLs must not contain embedded credentials.
For Home Assistant, sign in directly in the browser using a dedicated account with
limited permissions.

## Building a Custom SD Card Image

The included stage extends the official Raspberry Pi OS Lite stage (`stage2`)
from [pi-gen](https://github.com/RPi-Distro/pi-gen). It produces an `.img.xz` file
in the `deploy` directory. No image has been built in this Windows workspace yet.

Recommended: a dedicated Raspberry Pi as the build machine, running Raspberry Pi OS
matching the target architecture (32-bit for `armhf`, 64-bit for `arm64`),
with sufficient free disk space (several tens of GB) and the
[current pi-gen build dependencies](https://github.com/RPi-Distro/pi-gen#dependencies).
Do not build on NTFS. Builds on x86 Linux using QEMU/Docker are possible, but are
not supported by pi-gen as native builds and have not been verified here.

Install Git on the Linux build machine and clone the project.
If it already exists at `~/img-frame`, skip the clone command:

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/freequenzart/img-frame.git "$HOME/img-frame"
cd "$HOME/img-frame"
bash image/prepare.sh "$HOME/pi-gen-img-frame" auto
cd "$HOME/pi-gen-img-frame"
read -rsp 'Choose your own password for frameadmin: ' IMG_FRAME_ADMIN_PASSWORD
echo
export IMG_FRAME_ADMIN_PASSWORD
sudo --preserve-env=IMG_FRAME_ADMIN_PASSWORD ./build.sh
unset IMG_FRAME_ADMIN_PASSWORD
```

Select the architecture using the second argument:

| Selection | Behavior | pi-gen Branch | Image Name |
| --- | --- | --- | --- |
| `auto` (default) | Installed OS architecture of the build machine, detected via `dpkg` | Matches the OS | Matches the OS |
| `armhf` | 32-bit target | `master` | `img-frame-armhf` |
| `arm64` | 64-bit target | `arm64` | `img-frame-arm64` |

`auto` deliberately uses the operating system architecture, not just the CPU:
a 32-bit OS on a 64-bit-capable CPU selects `armhf`. On an x86 machine, `auto`
rejects the architecture; you must explicitly specify the ARM target instead.
Explicit selection does not set up an additional cross-build or QEMU environment.

Both variants can be prepared independently in separate directories:

```bash
cd "$HOME/img-frame"
bash image/prepare.sh "$HOME/pi-gen-img-frame-armhf" armhf
bash image/prepare.sh "$HOME/pi-gen-img-frame-arm64" arm64
```

Then run the `build.sh` command shown above in each directory using a suitable
build environment. An existing build directory will not be overwritten. This
produces two separate images, not a single image that switches between 32-bit
and 64-bit at boot.

Preparation clones the current revision of the selected branch and prints its
commit ID. For reproducible builds, record that revision and the package sources
used; the online package repositories themselves are not frozen.

Flash the finished image using "Use custom" in Raspberry Pi Imager. The admin user
is `frameadmin`, with the password you chose during the build. SSH is disabled by
default. No default password is provided. This image is intended for personal use:
do not redistribute it unchanged with the same admin password. Public releases
would require a dedicated, secure first-boot admin setup.

Important: the URL prompt does not configure Wi-Fi. When using a custom image,
connect via Ethernet before the first browser start, or press `Ctrl+Alt+F2`,
sign in as `frameadmin`, and configure the network. For example, on a system
using NetworkManager:

```bash
sudo nmcli --ask device wifi connect 'YOUR-SSID'
```

OS customization in Imager is not always available for custom images. SSH can be
enabled with `sudo raspi-config` if needed. If Chromium is already showing a network
error page, restart the session after successfully configuring the network using
`sudo systemctl restart getty@tty1.service`. Automatic detection of later target
server outages and automatic page refresh are not included.

## Tested Setup and Wi-Fi Note

Successfully tested on a **Raspberry Pi 3A+ running Raspberry Pi OS Lite Trixie**.
The only issue observed in this setup was Wi-Fi connectivity, which was resolved
by restricting the saved Wi-Fi connection to **2.4 GHz** instead of allowing
automatic band selection. This is a workaround for this tested setup, not a
guaranteed fix for every Wi-Fi issue.

On systems using NetworkManager, first list the saved connection profiles:

```bash
nmcli -f NAME,TYPE,DEVICE connection show
```

Replace `YOUR-WIFI-CONNECTION` with the Wi-Fi **profile name** from that list
(which may differ from the SSID), then set the band and reconnect:

```bash
WIFI_CONNECTION='YOUR-WIFI-CONNECTION'
sudo nmcli connection modify "$WIFI_CONNECTION" 802-11-wireless.band bg
sudo nmcli connection up "$WIFI_CONNECTION"
```

NetworkManager uses `bg` for the 2.4 GHz band. The setting is saved in the profile
and persists across reboots. Your access point must provide a 2.4 GHz network.
Reconnecting may interrupt an SSH session; preferably run these commands locally
after pressing `Ctrl+Alt+F2` and signing in as the admin user.

To allow automatic band selection again:

```bash
sudo nmcli connection modify "$WIFI_CONNECTION" 802-11-wireless.band ""
sudo nmcli connection up "$WIFI_CONNECTION"
```

For this last example, keep `WIFI_CONNECTION` set to the same profile name.

## Limitations and Maintenance

Update the project files on the Pi and run the installer again:

```bash
cd "$HOME/img-frame"
git pull --ff-only
sudo bash install.sh
sudo reboot
```

The saved URL and browser profile are preserved. Review any local changes before
updating; `--ff-only` prevents automatic merge commits and does not overwrite local
changes. This does not update an already built SD card image; prepare a new build
for that instead.

- Boot and hardware tests on the Zero 2 W and other models are still pending.
  Complete pi-gen builds for both 32-bit and 64-bit must also be verified on Linux.
- Fullscreen kiosk mode does not protect against users with physical access.
  Console switching and maintenance remain intentionally available.
- KMS remains enabled. No blanket legacy/FKMS overlays or fixed screen resolution
  are configured. Display rotation and sensor control are not part of this base setup.
- HTTPS requires trusted certificates; certificate validation is not disabled.
- Chromium session data and tokens are stored on the SD card. Protect both the device and the card.
- Update the operating system and browser regularly:

  ```bash
  sudo apt update
  sudo apt full-upgrade
  sudo reboot
  ```

## Tests

```bash
python3 -m unittest discover -s tests -v
bash tests/test_prepare.sh
bash -n install.sh files/launch.sh files/session.sh image/prepare.sh
```

The Python tests cover URL validation, the first-start prompt, persistent storage,
URL changes, and recovery from corrupted configuration files. The shell tests cover
both target architectures, automatic selection, and error cases using simulated
`git` and `dpkg` commands, without downloading anything or building an image.
These tests do not replace testing on a Pi.