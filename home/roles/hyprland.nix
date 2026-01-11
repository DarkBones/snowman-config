{ lib, pkgsUnstable, pkgs, config, ... }:
let
  cfg = config.roles.hyprland;

  draculaIcons = pkgs.fetchzip {
    url =
      "https://github.com/m4thewz/dracula-icons/archive/refs/heads/master.zip";
    sha256 = "sha256-JUjC6oalD7teSzzdMqLTXn7eJTZQbPP/oDeLBC7bG6E=";
    stripRoot = true;
  };
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

    # Install the icon theme into ~/.icons
    home.file.".icons/Dracula".source = draculaIcons;

    gtk = {
      enable = true;
      iconTheme = { name = "Dracula"; };
    };
  };
}
