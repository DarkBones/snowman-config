{ lib, config, pkgs, pkgsUnstable, inputs, ... }:
let
  cfg = config.roles.hyprland;

  draculaIcons = pkgs.fetchzip {
    url =
      "https://github.com/m4thewz/dracula-icons/archive/refs/heads/master.zip";
    sha256 = "sha256-JUjC6oalD7teSzzdMqLTXn7eJTZQbPP/oDeLBC7bG6E=";
    stripRoot = true;
  };

  awww = inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww;
in {
  options.roles.hyprland.enable = lib.mkEnableOption "Hyprland role";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgsUnstable;
      [
        waybar
        libnotify
        swaynotificationcenter
        wofi
        dunst
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
        networkmanagerapplet
        catppuccin-gtk
        bibata-cursors
        xsettingsd
        file-roller
      ] ++ [ awww ];

    services.xsettingsd.enable = true;

    services.xsettingsd.settings = {
      "Net/ThemeName" = config.gtk.theme.name;
      "Net/IconThemeName" = config.gtk.iconTheme.name or "Papirus-Dark";
      "Gtk/CursorThemeName" = "Bibata-Modern-Classic";
      "Gtk/CursorThemeSize" = 24;
    };

    home.file.".icons/Dracula".source = draculaIcons;
  };
}
