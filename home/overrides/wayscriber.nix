{ lib, config, pkgsUnstable, ... }:
let
  enabled = (config.roles.hyprland.enable or false);
  wayscriberBin = "${pkgsUnstable.wayscriber}/bin/wayscriber";
in {
  config = lib.mkIf enabled {
    home.packages = [
      pkgsUnstable.wayscriber
      # Optional: also install chameleos as a “backup plan”
      pkgsUnstable.chameleos
    ];

    # Run wayscriber in the background (daemon mode).
    # Then we can toggle it instantly via pkill -SIGUSR1 wayscriber.
    systemd.user.services.wayscriber = {
      Unit = {
        Description = "wayscriber (Wayland screen annotation overlay)";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart =
          "${pkgsUnstable.wayscriber}/bin/wayscriber --daemon --no-tray";
        Restart = "on-failure";
        RestartSec = 1;
      };

      Install = { WantedBy = [ "graphical-session.target" ]; };
    };
  };
}
