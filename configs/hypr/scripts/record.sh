#!/bin/sh
# RICELIN-FORK: configs at $QS_DIR/<name>, not root; use -p with full path.
QS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ricelin"
mon=$(hyprctl activeworkspace -j | jq -r '.monitor')
qs -p "$QS_DIR/pill" ipc call pill quickRecord "$mon"
