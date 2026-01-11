{ lib, pkgsUnstable, pkgs, config, ... }:
let
  cfg = config.roles.hyprland;

  draculaIcons = pkgs.fetchzip {
    url =
      "https://github.com/m4thewz/dracula-icons/archive/refs/heads/master.zip";
    sha256 = "sha256-JUjC6oalD7teSzzdMqLTXn7eJTZQbPP/oDeLBC7bG6E=";
    stripRoot = true;
  };

  # Reuse this string for GTK3 + GTK4
  eftelingGtkCss = ''
    /* --- global-ish surfaces --- */
    tooltip,
    .tooltip,
    popover {
      background-image: linear-gradient(
        to bottom,
        rgba(179, 139, 77, 0.22),
        rgba(13, 13, 22, 0) 55%
      );
      background-color: rgba(13, 13, 22, 0.92);

      border: 1.5px solid rgba(69, 71, 90, 0.9);
      border-radius: 14px;
      box-shadow:
        0 6px 18px rgba(0, 0, 0, 0.45),
        0 0 10px rgba(179, 139, 77, 0.12);
    }

    tooltip label,
    .tooltip label {
      color: #f5e0dc;
      text-shadow: 0 0 3px rgba(179, 139, 77, 0.25);
      font-weight: 700;
    }

    /* --- top bars / headerbars --- */
    headerbar,
    .titlebar,
    .header-bar {
      background-image: linear-gradient(
        to bottom,
        rgba(179, 139, 77, 0.22),
        rgba(13, 13, 22, 0) 45%
      );
      background-color: #0d0d16;

      border-bottom: 1px solid rgba(69, 71, 90, 0.65);
      box-shadow: inset 0 -1px 0 rgba(179, 139, 77, 0.10);
    }

    headerbar button:hover,
    .titlebar button:hover {
      box-shadow: 0 0 8px rgba(179, 139, 77, 0.12);
    }
  '';
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

    home.file.".icons/Dracula".source = draculaIcons;

    gtk = {
      enable = true;

      iconTheme = { name = "Dracula"; };

      # This is the fallback for stylix.targets.gtk.extraCss
      gtk3.extraCss = eftelingGtkCss;
      gtk4.extraCss = eftelingGtkCss;
    };
  };
}
