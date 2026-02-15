{ lib, pkgs, config, ... }:
let agent = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
in {
  config = lib.mkIf (pkgs.stdenv.isLinux && config.roles.desktop.enable or false) {
    home.packages = [ pkgs.polkit_gnome ];

    systemd.user.services.polkit-gnome-agent = {
      Unit = {
        Description = "Polkit GNOME Authentication Agent";
        After = [ "graphical-session.target" "dbus.service" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = agent;
        Restart = "on-failure";
        RestartSec = 1;
      };

      Install = { WantedBy = [ "graphical-session.target" ]; };
    };
  };
}
