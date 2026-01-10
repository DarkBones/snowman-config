# home/roles/hyprland.nix
{ lib, pkgsUnstable, config, ... }:
let
  cfg = config.roles.hyprland;
  gtkTheme = "catppuccin-frappe-blue-standard";
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

    home.pointerCursor = {
      gtk.enable = true;
      x11.enable = true;
      size = 24;

      name = "Bibata-Modern-Ice";
      package = pkgsUnstable.bibata-cursors;
    };

    gtk = {
      enable = true;
      theme = {
        name = gtkTheme;
        package = pkgsUnstable.catppuccin-gtk;
      };
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgsUnstable.papirus-icon-theme;
      };
      font = {
        name = "Crimson Text";
        size = 11;
      };
    };

    services.xsettingsd.enable = true;
    services.xsettingsd.settings = {
      "Net/ThemeName" = gtkTheme;
      "Net/IconThemeName" = "Papirus-Dark";
      "Gtk/CursorThemeName" = "Bibata-Modern-Ice";
      "Gtk/FontName" = "Crimson Text 11";
    };

    dconf.enable = true;
    dconf.settings = {
      "org/gnome/desktop/interface" = {
        gtk-theme = gtkTheme;
        icon-theme = "Papirus-Dark";
        cursor-theme = "Bibata-Modern-Ice";
        font-name = "Crimson Text 11";
        color-scheme = "prefer-dark";
      };
    };
  };
}
