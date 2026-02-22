{ lib, pkgs, config, pkgsUnstable, dotfilesSources ? { }, hostRoles ? null, ...
}:
let
  hasDesktopHost = hostRoles == null || lib.elem "desktop" hostRoles;

  cfg = config.roles.dotfiles or { };

  # Mode detection
  mode = builtins.getEnv "SNOWMAN_DOTFILES_MODE";
  isDev = mode == "dev";

  # DEV: real checkout
  repoDir = "${config.home.homeDirectory}/${cfg.dir or "Developer/dotfiles"}";

  # PROD: pinned flake input
  sourceKey = cfg.sourceKey or config.home.username;
  dotfilesRepo = dotfilesSources.${sourceKey} or null;
in {
  config =
    lib.mkIf (pkgs.stdenv.isLinux && hasDesktopHost && (cfg.enable or false))
    (lib.mkMerge [

      ############################################################
      # PROD safety net
      ############################################################
      (lib.mkIf (!isDev) {
        assertions = [{
          assertion = dotfilesRepo != null;
          message = ''
            dev-gtk.nix: PROD mode but no pinned dotfiles source found.

            Fix one of:
              - set dotfilesSources.${sourceKey} in flake inputs
              - export SNOWMAN_DOTFILES_MODE=dev
          '';
        }];
      })

      ############################################################
      # GTK base configuration
      ############################################################
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

        ##########################################################
        # Darkling CSS
        ##########################################################

        # ~/.config/gtk/darkling.css
        xdg.configFile."gtk/darkling.css" = if isDev then {
          source = config.lib.file.mkOutOfStoreSymlink
            "${repoDir}/gtk/.config/gtk/darkling.css";
        } else {
          source = "${dotfilesRepo}/gtk/.config/gtk/darkling.css";
        };

        # GTK3
        xdg.configFile."gtk-3.0/gtk.css" = lib.mkForce {
          text = ''
            /* Darkling user CSS (GTK3) */
            @import url("../gtk/darkling.css");
          '';
        };

        # GTK4
        xdg.configFile."gtk-4.0/gtk.css" = lib.mkForce {
          text = ''
            /* Darkling user CSS (GTK4) */
            @import url("../gtk/darkling.css");
          '';
        };
      }
    ]);
}
