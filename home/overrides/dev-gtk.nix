{ lib, config, pkgsUnstable, hostRoles ? [ ], ... }:
let
  cfg = config.roles.dotfiles or { };
  hasDesktopHost = hostRoles == null || lib.elem "desktop" hostRoles;

  # Path to dotfiles repo
  mode = builtins.getEnv "SNOWMAN_DOTFILES_MODE";
  isDev = mode == "dev";

  repoDir = "${config.home.homeDirectory}/${cfg.dir}";

  # In prod, prefer the HM-linked dotfile location (store-backed if dotfiles role is pinned)
  darklingCssDev = "${repoDir}/gtk/.config/darkling.css";
  darklingCssProd = "${config.home.homeDirectory}/.config/darkling.css";

  importLine = path: ''@import url("file://${path}");'';
  darklingImport =
    importLine (if isDev then darklingCssDev else darklingCssProd);
in {
  config = lib.mkIf (hasDesktopHost && (cfg.enable or false)) {
    # Let Stylix manage GTK (base theme generation)
    stylix.targets.gtk.enable = lib.mkForce false;

    gtk = {
      enable = true;

      theme = {
        package = pkgsUnstable.catppuccin-gtk;
        name = "Catppuccin-Mocha-Standard-Lavender-Dark";
      };

      gtk3.extraCss = darklingImport;
      gtk4.extraCss = darklingImport;
    };
    xdg.dataFile."themes/Catppuccin".source =
      "${pkgsUnstable.catppuccin-gtk}/share/themes";
  };
}
