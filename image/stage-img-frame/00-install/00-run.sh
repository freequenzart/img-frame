#!/bin/bash
set -euo pipefail
install -d "${ROOTFS_DIR}/tmp/img-frame"
cp -a files/. "${ROOTFS_DIR}/tmp/img-frame/"
on_chroot <<'CHROOT'
bash /tmp/img-frame/install.sh --image
rm -rf /tmp/img-frame
CHROOT