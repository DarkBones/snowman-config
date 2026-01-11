{ lib, config, pkgs, pkgsUnstable, ... }:
let
  cfg = config.roles.hyprland;

  draculaIcons = pkgs.fetchzip {
    url =
      "https://github.com/m4thewz/dracula-icons/archive/refs/heads/master.zip";
    sha256 = "sha256-JUjC6oalD7teSzzdMqLTXn7eJTZQbPP/oDeLBC7bG6E=";
    stripRoot = true;
  };
in {
  options.roles.hyprland.enable = lib.mkEnableOption "Hyprland role";

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
      grim
      slurp
      nwg-look
      pavucontrol
      baobab
      blueman
      adwaita-icon-theme
      hicolor-icon-theme
      papirus-icon-theme
      networkmanagerapplet
      catppuccin-gtk
      bibata-cursors
    ];

    home.file.".icons/Dracula".source = draculaIcons;

    xdg.configFile."darkling.css".source = ../gtk/darkling.css;
    gtk = {
      enable = true;

      gtk3.extraCss = ''
        @import url("file://${config.home.homeDirectory}/.config/darkling.css");
      '';
      gtk4.extraCss = ''
        @import url("file://${config.home.homeDirectory}/.config/darkling.css");
      '';
    };

    stylix.targets.gtk.enable = lib.mkForce false;
  };
}
