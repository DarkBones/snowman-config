{ lib, config, pkgsUnstable, hostRoles ? [ ], ... }:
let
  cfg = config.roles.dotfiles or { };
  hasDesktopHost = hostRoles == null || lib.elem "desktop" hostRoles;

  mode = builtins.getEnv "SNOWMAN_DOTFILES_MODE";
  isDev = mode == "dev";

  repoDir = "${config.home.homeDirectory}/${cfg.dir}";
  darklingCssDev = "${repoDir}/gtk/.config/darkling.css";
  darklingCssProd = "${config.home.homeDirectory}/.config/darkling.css";

  darklingCssPath = if isDev then darklingCssDev else darklingCssProd;

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
      gtk3.extraConfig = gtkExtraCfg;
      gtk4.extraConfig = gtkExtraCfg;
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

    xdg.configFile."gtk-3.0/darkling.css".source =
      config.lib.file.mkOutOfStoreSymlink darklingCssPath;

    xdg.configFile."gtk-4.0/darkling.css".source =
      config.lib.file.mkOutOfStoreSymlink darklingCssPath;

    stylix.targets.gtk.enable = lib.mkForce false;

    xdg.configFile."gtk-3.0/gtk.css".text = lib.mkForce ''
      @import url("darkling.css");
    '';

    xdg.configFile."gtk-4.0/gtk.css".text = lib.mkForce ''
      @import url("darkling.css");
    '';
  };
}
