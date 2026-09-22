pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Wallpaper bridge: keeps a warm in-memory snapshot of the wallpaper folder so
 * the wallpaper strip opens instantly without shelling out on demand. A
 * refresh first runs the thumbnail script (generating missing 512px previews
 * and pruning ones whose source is gone), then re-lists the directory
 * newest-first and finally re-reads the state file zos-wallpaper-apply maintains, so
 * `current` always names the wallpaper on screen. Thumbnails land before the
 * list so strip delegates never bind to a not-yet-existing file; a refresh
 * arriving while the pipeline runs sets `pending` and replays once the state
 * lands. Applying routes through zos-wallpaper-apply so the picker shares the exact
 * transition, palette and state path with the walker keybind.
 *
 * The folder resolves through one chain, first hit wins: an explicit
 * `wallpaperDir` in flags.json, then the dir zos-wallpaper-thumbs resolve last resolved and
 * wrote to the zos-wallpaper-dir state file on its last run, then
 * ~/Pictures/Wallpapers for a first boot before any resolve has run.
 *
 * Entries are plain objects: { path, name, mtime, thumb } where path is the
 * absolute source file, mtime its modification time in epoch seconds and
 * thumb the absolute path of the cached preview png.
 */
Singleton {
    id: root

    property var entries: []
    readonly property int count: entries.length
    property string current: ""
    property bool pending: false

    property string resolvedDir: ""
    readonly property string wpDir: Flags.wallpaperDir.length > 0 ? Flags.wallpaperDir
        : (resolvedDir.length > 0 ? resolvedDir : Quickshell.env("HOME") + "/Pictures/Wallpapers")
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/zos-wallpaper-thumbs/"
    readonly property string thumbScript: "zos-wallpaper-thumbs"
    readonly property string setScript: "zos-wallpaper-apply"
    /**
     * Mirror of zos.matugenOnWallpaper. Injected into the ricelin-pill
     * systemd service's Environment by modules/home/matugen/ricelin-env.nix;
     * read here so the pill can fire zos-theme-set image explicitly after
     * each pick (today's stand-in for ricelin's own wallcolors.py port).
     * Same gate as the matugen hook inside zos-wallpaper-apply, so toggling
     * the option off silences both paths at once.
     */
    readonly property bool matugenOnWallpaper:
        Quickshell.env("ZOS_MATUGEN_ON_WALLPAPER") === "1"
    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/zos-wallpaper"
    readonly property string dirStateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/zos-wallpaper-dir"

    onWpDirChanged: refresh()

    FileView {
        id: dirFile
        path: root.dirStateFile
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.resolvedDir = dirFile.text().trim()
        onFileChanged: reload()
        onLoadFailed: root.resolvedDir = ""
    }

    function refresh() {
        if (resolveProc.running || thumbProc.running || listProc.running || stateProc.running) {
            pending = true;
            return;
        }
        /**
         * Re-resolve the folder first when autodetect is in play: it only runs
         * inside zos-wallpaper-thumbs resolve, so a shell restart used to leave
         * the strip on the stale state file. An explicit folder skips that
         * hop entirely and swaps straight away.
         */
        if (Flags.wallpaperDir.length > 0) {
            thumbProc.running = true;
            return;
        }
        resolveProc.command = [root.thumbScript, "resolve"];
        resolveProc.running = true;
    }

    Process {
        id: resolveProc
        onExited: thumbProc.running = true
    }

    /**
     * zos-wallpaper-apply blocks through the whole transition (awww wave,
     * matugen, reload), easily 1-2s; a pick landing in that window used to
     * be silently swallowed. Now the newest request is queued and replayed
     * once the running transition exits, so rapid iteration converges on the
     * last pick.
     */
    property string queuedApply: ""
    property string queuedOutput: ""
    /** Snapshot of matugenOnWallpaper at queue time; replayed on the
     *  next applyProc.onExited so the queue doesn't lose its matugen
     *  intent when the option flips between picks. */
    property bool queuedMatugen: false

    function apply(path, output) {
        var out = output === undefined ? "" : output;
        if (applyProc.running) {
            queuedApply = path;
            queuedOutput = out;
            queuedMatugen = root.matugenOnWallpaper;
            return;
        }
        applyProc.command = out === "all"
            ? [root.setScript, path, "--all"]
            : (out.length > 0
                ? [root.setScript, path, "--target=" + out]
                : [root.setScript, path]);
        applyProc.running = true;
        // Fire matugen in parallel with the wallpaper apply. Today's
        // zos-wallpaper-apply also has its own matugen hook (gated by
        // zos.matugenOnWallpaper), so we update the .prev cache via
        // zos-theme-set to keep the two paths idempotent: zos-theme-set
        // is itself idempotent and skips re-runs within ~30s.
        fireMatugen(path);
    }

    /**
     * Spawn the matugen regen + the matching notify-send. Gated by
     * matugenOnWallpaper so toggling the option off silences both this
     * path AND the one inside zos-wallpaper-apply.
     */
    function fireMatugen(path) {
        if (!root.matugenOnWallpaper)
            return;
        matugenProc.command = ["sh", "-c",
            "notify-send -u low Wallpaper 'Regenerating theme palette…'\n" +
            "exec zos-theme-set image \"$1\"",
            "sh", path];
        matugenProc.running = true;
    }

    Process {
        id: matugenProc
        onExited: function(exitCode) {
            if (exitCode !== 0)
                wp_log("matugen failed (non-fatal)")
        }
    }

    /**
     * wp_log: print debug messages only when the user opts in. Mirrors
     * the helper inside zos-wallpaper-lib.
     */
    function wp_log(msg) {
        if (Quickshell.env("WP_DEBUG") === "1")
            console.log("[zos-wallpaper] " + msg)
    }

    function trash(path) {
        trashProc.command = ["gio", "trash", path];
        trashProc.running = true;
        var kept = [];
        for (var i = 0; i < entries.length; i++)
            if (entries[i].path !== path)
                kept.push(entries[i]);
        entries = kept;
    }

    Process {
        id: trashProc
        onExited: function(exitCode) {
            if (exitCode !== 0)
                root.refresh();
        }
    }

    Process {
        id: thumbProc
        command: ["sh", root.thumbScript]
        onExited: listProc.running = true
    }

    Process {
        id: listProc
        command: ["sh", "-c", "find \"$1\" -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.avif' -o -iname '*.bmp' -o -iname '*.tiff' -o -iname '*.tif' -o -iname '*.jxl' -o -iname '*.heic' -o -iname '*.heif' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.m4v' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.avi' -o -iname '*.flv' -o -iname '*.wmv' -o -iname '*.mpg' -o -iname '*.mpeg' -o -iname '*.ts' -o -iname '*.ogv' -o -iname '*.vob' -o -iname '*.m2ts' -o -iname '*.mts' -o -iname '*.3gp' -o -iname '*.3g2' -o -iname '*.asf' \\) -printf '%T@\\t%p\\n' | sort -rn", "_", root.wpDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var out = [];
                for (var i = 0; i < lines.length; i++) {
                    var tab = lines[i].indexOf("\t");
                    if (tab < 1)
                        continue;
                    var path = lines[i].substring(tab + 1);
                    var name = path.substring(path.lastIndexOf("/") + 1);
                    out.push({
                        path: path,
                        name: name,
                        mtime: parseFloat(lines[i].substring(0, tab)),
                        thumb: root.thumbDir + name + ".png"
                    });
                }
                root.entries = out;
                stateProc.running = true;
            }
        }
    }

    Process {
        id: stateProc
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null || true", "_", root.stateFile]
        stdout: StdioCollector {
            onStreamFinished: {
                root.current = this.text.trim();
                if (root.pending) {
                    root.pending = false;
                    Qt.callLater(root.refresh);
                }
            }
        }
    }

    Process {
        id: applyProc
        onExited: {
            if (root.queuedApply.length) {
                var next = root.queuedApply;
                var nextOut = root.queuedOutput;
                var nextMatugen = root.queuedMatugen;
                root.queuedApply = "";
                root.queuedOutput = "";
                root.queuedMatugen = false;
                applyProc.command = nextOut === "all"
                    ? [root.setScript, next, "--all"]
                    : (nextOut.length > 0
                        ? [root.setScript, next, "--target=" + nextOut]
                        : [root.setScript, next]);
                applyProc.running = true;
                if (nextMatugen)
                    fireMatugen(next);
                return;
            }
            stateProc.running = true;
        }
    }

    Component.onCompleted: refresh()
}
