{ lib, config, pkgs, inputs, ... }:
let wallpaperDir = "${config.home.homeDirectory}/wallpapers/";
in {
  config =
    lib.mkIf (pkgs.stdenv.isLinux && (config.roles.hyprland.enable or false))
    (let
      awww = inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww;

      awwwSetRandom = pkgs.writeShellScriptBin "awww-set-random" ''
        set -euo pipefail
        dir="${wallpaperDir}"
        echo "[awww-set-random] dir=$dir" >&2

        if [ ! -d "$dir" ]; then
          echo "[awww-set-random] ERROR: directory does not exist: $dir" >&2
          exit 1
        fi

        pic="$(${pkgs.findutils}/bin/find "$dir" -type f \
          \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) \
          -print0 \
          | ${pkgs.coreutils}/bin/shuf -z -n1 \
          | ${pkgs.coreutils}/bin/tr -d '\0')"

        if [ -z "$pic" ]; then
          echo "[awww-set-random] ERROR: no images found in $dir" >&2
          exit 1
        fi

        echo "[awww-set-random] picked=$pic" >&2

        ${awww}/bin/awww query >&2 || {
          echo "[awww-set-random] ERROR: awww query failed (daemon not running?)" >&2
          exit 1
        }

        exec ${awww}/bin/awww img "$pic"
      '';
    in {
      home.packages = [ awwwSetRandom ];

      systemd.user.services.awww-rotate = {
        Unit = {
          Description = "Rotate wallpaper with awww";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${awwwSetRandom}/bin/awww-set-random";
        };
      };

      systemd.user.timers.awww-rotate = {
        Unit.Description = "Rotate wallpaper every 30 minutes (on the clock)";
        Timer = {
          OnCalendar = "*-*-* *:00,30:00";
          Persistent = true;
          AccuracySec = "1s";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    });
}
