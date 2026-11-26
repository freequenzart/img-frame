if [[ -z ${DISPLAY:-} && $(tty) == /dev/tty1 ]]; then
    exec /usr/local/lib/img-frame/launch
fi