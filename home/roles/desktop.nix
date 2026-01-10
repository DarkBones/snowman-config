{ lib, pkgsUnstable, config, inputs, ... }:
let cfg = config.roles.desktop;
in {
  options.roles.desktop.enable = lib.mkEnableOption "Desktop role";

  imports = [ inputs.zen-browser.homeModules.twilight ];

  config = lib.mkIf cfg.enable {
    programs.zen-browser.enable = true;

    home.packages = with pkgsUnstable; [
      ghostty
      playerctl
      spotify
      polkit_gnome
    ];

    # If you manage Hyprland config via Home Manager, add an exec-once:
    wayland.windowManager.hyprland.settings.exec-once = [
      "${pkgsUnstable.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
    ];
  };
}
