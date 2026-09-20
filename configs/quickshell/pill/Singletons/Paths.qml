pragma Singleton
import QtQuick
import Quickshell

/**
 * Deployment paths. Held in QML so the script host layout is set in one
 * place — ZOS nests them under ~/.local/share/ricelin/scripts/, upstream
 * expects ~/.config/hypr/scripts/. Every QML Process that shells out to a
 * helper script reads Paths.scriptsDir instead of hardcoding a path.
 *
 * To relocate on a new host, edit `scriptsDir` here; nothing else in the
 * Pill needs to change.
 */
Singleton {
    readonly property string scriptsDir: Quickshell.env("HOME") + "/.local/share/ricelin/scripts"
}
