#!/bin/sh
# RICELIN-FORK: configs live at $QS_DIR/<name>, not at the root of quickshell/,
# so `qs -c <name>` won't resolve. Use -p with the full config path.
#
# With one arg the call is `ipc call pill <surface> ""` (the empty second arg
# matches functions that take a monitor name). With more args they pass through
# verbatim, so callers can hit multi-arg IPC like `open-surface.sh page "" wifi`
# to drive pill.page("", "wifi").
QS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ricelin"
[ "$#" -eq 1 ] && set -- "$1" ""
exec qs -p "$QS_DIR/pill" ipc call pill "$@"
