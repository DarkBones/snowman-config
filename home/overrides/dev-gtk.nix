{ lib, pkgs, config, pkgsUnstable, hostRoles ? null, ... }:
let
  hasDesktopHost = hostRoles == null || lib.elem "desktop" hostRoles;
  dotfilesEnabled = config.roles.dotfiles.enable or false;
  dotRoot = config.dotfiles.root;
in {
  config =
    lib.mkIf (pkgs.stdenv.isLinux && hasDesktopHost && dotfilesEnabled)
    (lib.mkMerge [
      {
        gtk = {
          enable = true;

          theme = lib.mkForce {
            package = pkgsUnstable.catppuccin-gtk;
            name = "catppuccin-frappe-blue-standard";
          };

          iconTheme = lib.mkForce {
            package = pkgsUnstable.tela-icon-theme;
            name = "Tela-black";
          };

          cursorTheme = lib.mkForce {
            package = pkgsUnstable.bibata-cursors;
            name = "Bibata-Modern-Classic";
            size = 24;
          };
        };

        xdg.configFile."gtk/darkling.css".source =
          config.lib.file.mkOutOfStoreSymlink
          "${dotRoot}/gtk/.config/gtk/darkling.css";

        xdg.configFile."gtk-3.0/gtk.css" = lib.mkForce {
          text = ''
            /* Darkling user CSS (GTK3) */
            @import url("../gtk/darkling.css");
          '';
        };

        xdg.configFile."gtk-4.0/gtk.css" = lib.mkForce {
          text = ''
            /* Darkling user CSS (GTK4) */
            @import url("../gtk/darkling.css");
          '';
        };
      }
    ]);
}
