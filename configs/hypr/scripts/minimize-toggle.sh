#!/bin/sh
#
# SUPER+M minimize toggle. A window on the desktop drops into the special
# "minimized" stash; the same key on a window already in the stash brings it
# back to the monitor's real workspace. The pill does the actual move over its
# IPC so the lua dispatcher runs the way the tray restore already does.

# RICELIN-FORK: configs at $QS_DIR/<name>, not root; use -p with full path.
QS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ricelin"

aw=$(hyprctl activewindow -j 2>/dev/null)
addr=$(printf '%s' "$aw" | jq -r '.address // ""')
ws=$(printf '%s' "$aw" | jq -r '.workspace.name // ""')

[ -n "$addr" ] || exit 0

if [ "$ws" = "special:minimized" ]; then
	real=$(hyprctl monitors -j | jq -r 'map(select(.focused)) | .[0].activeWorkspace.id // 1')
	qs -p "$QS_DIR/pill" ipc call pill restoreWindow "$addr|$real"
else
	qs -p "$QS_DIR/pill" ipc call pill minimizeWindow "$addr"
fi
