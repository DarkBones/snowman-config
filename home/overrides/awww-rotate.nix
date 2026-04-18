{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  wallpaperDir = "${config.home.homeDirectory}/wallpapers";
in
{
  config = lib.mkIf (pkgs.stdenv.isLinux && (config.roles.hyprland.enable or false)) (
    let
      awww = inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww;

      awwwSetRandom = pkgs.writeShellScriptBin "awww-set-random" ''
        set -euo pipefail
        dir="${wallpaperDir}/"
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

        if ! ${awww}/bin/awww query >&2; then
          echo "[awww-set-random] WARN: awww query failed; restarting daemon" >&2
          ${pkgs.systemd}/bin/systemctl --user restart awww-daemon.service
          ${pkgs.coreutils}/bin/sleep 1
          ${awww}/bin/awww query >&2 || {
            echo "[awww-set-random] ERROR: awww query failed after daemon restart" >&2
            exit 1
          }
        fi

        exec ${awww}/bin/awww img --transition-step 255 "$pic"
      '';
    in
    {
      home.packages = [ awwwSetRandom ];

      systemd.user.services.awww-daemon = {
        Unit = {
          Description = "Awww wallpaper daemon";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${awww}/bin/awww-daemon --no-cache";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      systemd.user.services.awww-rotate = {
        Unit = {
          Description = "Rotate wallpaper with awww";
          After = [
            "graphical-session.target"
            "awww-daemon.service"
          ];
          Wants = [ "awww-daemon.service" ];
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
    }
  );
}
