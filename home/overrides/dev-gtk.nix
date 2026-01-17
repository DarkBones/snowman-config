{ lib, config, pkgsUnstable, hostRoles ? [ ], ... }:
let
  cfg = config.roles.dotfiles or { };
  hasDesktopHost = hostRoles == null || lib.elem "desktop" hostRoles;

  mode = builtins.getEnv "SNOWMAN_DOTFILES_MODE";
  isDev = mode == "dev";

  repoDir = "${config.home.homeDirectory}/${cfg.dir}";
  darklingCssDev = "${repoDir}/gtk/.config/darkling.css";
  darklingCssProd = "${config.home.homeDirectory}/.config/darkling.css";

  importLine = path: ''@import url("file://${path}");'';
  darklingImport =
    importLine (if isDev then darklingCssDev else darklingCssProd);

  gtkExtraCfg = {
    gtk-theme-name = config.gtk.theme.name;
    gtk-icon-theme-name = (config.gtk.iconTheme.name or "Papirus-Dark");
    gtk-cursor-theme-name = "Bibata-Modern-Classic";
    gtk-cursor-theme-size = 24;
  };
in {
  config = lib.mkIf (hasDesktopHost && (cfg.enable or false)) {
    gtk = {
      enable = true;

      theme = {
        package = lib.mkForce pkgsUnstable.catppuccin-gtk;
        name = lib.mkForce "catppuccin-frappe-blue-standard";
      };

      gtk3 = {
        extraConfig = gtkExtraCfg;
        extraCss = darklingImport;
      };

      gtk4 = {
        extraConfig = gtkExtraCfg;
        extraCss = darklingImport;
      };
    };

    dconf = {
      enable = true;
      settings."org/gnome/desktop/interface" = {
        gtk-theme = config.gtk.theme.name;
        icon-theme = (config.gtk.iconTheme.name or "Papirus-Dark");
        cursor-theme = "Bibata-Modern-Classic";
        cursor-size = 24;
      };
    };
  };
}
