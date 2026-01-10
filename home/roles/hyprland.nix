{ lib, pkgsUnstable, config, ... }:
let cfg = config.roles.hyprland;
in {
  options.roles.hyprland.enable =
    lib.mkEnableOption "Hyprland Desktop Environment";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgsUnstable; [
      waybar
      wofi
      dunst
      hyprpaper
      hyprlock
      hypridle
      hyprshot
      wlogout
      wl-clipboard

      # Tools
      grim
      slurp
      nwg-look
      pavucontrol
      baobab

      # Bluetooth
      blueman
      adwaita-icon-theme
      hicolor-icon-theme
      papirus-icon-theme

      # Networking
      networkmanagerapplet

      # Theming
      catppuccin-gtk
      bibata-cursors
    ];
  };
}
