{ lib, pkgs, config, ... }:
let agent = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
in {
  config = lib.mkIf (config.roles.desktop.enable or false) {
    home.packages = [ pkgs.polkit_gnome ];

    systemd.user.startServices = "sd-switch";

    xdg.configFile."autostart/polkit-gnome-authentication-agent-1.desktop".text =
      ''
        [Desktop Entry]
        Type=Application
        Name=polkit-gnome-authentication-agent-1
        Exec=${agent}
        Hidden=true
        NoDisplay=true
      '';

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
