#!/bin/bash
set -euo pipefail

while true; do
    if ! /usr/local/bin/img-frame-config --get >/dev/null 2>&1; then
        /usr/local/bin/img-frame-config || { sleep 2; continue; }
    fi
    startx /usr/bin/dbus-run-session /usr/local/lib/img-frame/session -- :0 vt1 -keeptty -nolisten tcp || true
    sleep 3
done