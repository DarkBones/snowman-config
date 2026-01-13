{ lib, config, ... }:
# let
#   cfg = config.roles.dotfiles or { };
#
#   mode = builtins.getEnv "SNOWMAN_DOTFILES_MODE";
#   isDev = mode == "dev";
#
#   # Path to your dotfiles repo
#   repoDir = "${config.home.homeDirectory}/${cfg.dir}";
#
#   # GTK CSS file in your dotfiles
#   darklingCss = "${repoDir}/gtk/.config/darkling.css";
#
# in {
#   config = lib.mkIf (cfg.enable or false) {
#
#     gtk = {
#       enable = true;
#
#       # In dev mode: import from your live dotfiles
#       # In prod mode: import from Nix store (via dotfiles flake input)
#       gtk3.extraCss = if isDev then ''
#         @import url("file://${darklingCss}");
#       '' else if (cfg.sourceKey or null) != null then ''
#         @import url("file://${config.home.homeDirectory}/.config/darkling.css");
#       '' else
#         "";
#
#       gtk4.extraCss = if isDev then ''
#         @import url("file://${darklingCss}");
#       '' else if (cfg.sourceKey or null) != null then ''
#         @import url("file://${config.home.homeDirectory}/.config/darkling.css");
#       '' else
#         "";
#     };
#
#     # Disable Stylix GTK management so it doesn't fight us
#     stylix.targets.gtk.enable = lib.mkForce false;
#   };
# }
{}
