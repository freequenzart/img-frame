#!/bin/bash
set -euo pipefail

URL=$(/usr/local/bin/img-frame-config --get)
xset -dpms
xset s off
xset s noblank
unclutter -idle 1 -root &
matchbox-window-manager -use_titlebar no &
exec chromium \
    --kiosk \
    --no-first-run \
    --no-default-browser-check \
    --noerrdialogs \
    --disable-session-crashed-bubble \
    --disable-features=Translate,TranslateUI,OverscrollHistoryNavigation \
    --disable-pinch \
    --lang=de \
    --accept-lang=de-DE \
    --password-store=basic \
    --user-data-dir="$HOME/.config/img-frame/chromium" \
    "$URL"