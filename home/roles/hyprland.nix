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

      # Theming
      catppuccin-gtk
      papirus-icon-theme
    ];

    gtk = {
      enable = true;
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
