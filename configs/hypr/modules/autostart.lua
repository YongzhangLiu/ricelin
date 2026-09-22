hl.on("hyprland.start", function()
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/cliphist-watch.sh")
    -- wallpaper restore is now handled by ZOS's zos-wallpaper-restore (run at
    -- hyprland startup via modules/home/hyprland/core/autostart.lua). Drop the
    -- local wallpaper.sh init call; the script no longer exists on this host.
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
    hl.exec_cmd("systemctl --user start hyprland-session.target")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/watchdog.sh pill")
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/watchdog.sh lock")
    hl.exec_cmd("systemctl --user restart hypridle")
    -- warm the page cache so a user's first fastfetch run doesn't stall on cold pacman db reads
    hl.exec_cmd("fastfetch")
end)
