{ lib, pkgs, config, ... }:
let cfg = config.roles.hyprland;
in {
  options.roles.hyprland.enable =
    lib.mkEnableOption "Hyprland Desktop Environment";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      waybar
      wofi
      dunst
      hyprpaper
      hyprlock
      hypridle
      wlogout
      wl-clipboard

      # Tools
      grim
      slurp
      nwg-look
      pavucontrol
      baobab
      # swaync

      # Bluetooth
      papirus-icon-theme
      adwaita-icon-theme
      hicolor-icon-theme
      blueman

      # Theming
      catppuccin-gtk
      papirus-icon-theme
    ];

    gtk = {
      enable = true;
        
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };

      theme = {
        name = "Catppuccin-Mocha-Standard-Blue-Dark";
        package = pkgs.catppuccin-gtk.override {
          accents = [ "blue" ];
          size = "standard";
          tweaks = [ "rimless" "black" ];
          variant = "mocha";
        };
      };
    };
  };
}
