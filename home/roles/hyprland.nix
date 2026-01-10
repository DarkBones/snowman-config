# home/roles/hyprland.nix
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

      # Theming
      catppuccin-gtk
      bibata-cursors
    ];

    home.pointerCursor = {
      gtk.enable = true;
      x11.enable = true;
      size = 24;

      name = "Bibata-Modern-Ice";
      package = pkgsUnstable.bibata-cursors;
    };

    gtk = {
      enable = true;

      iconTheme = {
        name = "Papirus-Dark";
        package = pkgsUnstable.papirus-icon-theme;
      };

      theme = {
        name = "Catppuccin-Mocha-Standard-Blue-Dark";
        package = pkgsUnstable.catppuccin-gtk.override {
          accents = [ "blue" ];
          size = "standard";
          tweaks = [ "rimless" "black" ];
          variant = "mocha";
        };
      };
    };
  };
}
