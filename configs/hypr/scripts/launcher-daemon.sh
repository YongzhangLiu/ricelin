#!/bin/sh
# RICELIN-FORK: configs at $QS_DIR/<name>, not root; use -p with full path.
# pgrep matches the path substring "quickshell/ricelin/launcher" so it catches
# both the systemd-launched instance and any manual spawn.
QS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ricelin"
i=0
while [ "$i" -lt 10 ]; do
    pgrep -f "quickshell/ricelin/launcher" >/dev/null && exit 0
    qs -p "$QS_DIR/launcher" -d 2>/dev/null
    sleep 2
    i=$((i + 1))
done
