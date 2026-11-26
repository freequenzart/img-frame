#!/bin/bash
set -euo pipefail
SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
DESTINATION=${1:?Aufruf: bash image/prepare.sh /pfad/zum/neuen/pi-gen-verzeichnis [auto|armhf|arm64]}
TARGET_ARCH=${2:-auto}
if [[ $# -gt 2 ]]; then
    echo 'Aufruf: bash image/prepare.sh ZIEL [auto|armhf|arm64]' >&2
    exit 1
fi
if [[ $TARGET_ARCH == auto ]]; then
    if ! TARGET_ARCH=$(dpkg --print-architecture); then
        echo 'Architektur nicht erkennbar. Bitte armhf oder arm64 explizit angeben.' >&2
        exit 1
    fi
fi
case "$TARGET_ARCH" in
    armhf) PI_GEN_BRANCH=master ;;
    arm64) PI_GEN_BRANCH=arm64 ;;
    *)
        echo "Nicht unterstuetzte Zielarchitektur: $TARGET_ARCH. Bitte armhf oder arm64 angeben." >&2
        exit 1
        ;;
esac
if [[ $DESTINATION == *' '* || -e $DESTINATION ]]; then
    echo 'Bitte einen neuen Zielpfad ohne Leerzeichen waehlen.' >&2
    exit 1
fi
git clone --depth 1 --branch "$PI_GEN_BRANCH" https://github.com/RPi-Distro/pi-gen.git "$DESTINATION"
cp "$SOURCE_DIR/image/config" "$DESTINATION/config"
printf "\nIMG_NAME='img-frame-%s'\n" "$TARGET_ARCH" >> "$DESTINATION/config"
cp -a "$SOURCE_DIR/image/stage-img-frame" "$DESTINATION/stage-img-frame"
PAYLOAD="$DESTINATION/stage-img-frame/00-install/files"
mkdir -p "$PAYLOAD"
cp "$SOURCE_DIR/install.sh" "$PAYLOAD/"
cp -a "$SOURCE_DIR/files" "$PAYLOAD/files"
chmod +x "$DESTINATION/stage-img-frame/prerun.sh" "$DESTINATION/stage-img-frame/00-install/00-run.sh"
touch "$DESTINATION/stage2/SKIP_IMAGES"
git -C "$DESTINATION" rev-parse HEAD
printf '\nVorbereitet: %s\nArchitektur: %s (pi-gen-Zweig: %s)\nBuild-Anleitung: README.md im img-frame-Projekt.\n' "$DESTINATION" "$TARGET_ARCH" "$PI_GEN_BRANCH"