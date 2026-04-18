{
  lib,
  pkgs,
  config,
  ...
}:
let
  dotfilesEnabled = (config.roles.dotfiles.enable or false);
in
{
  config = lib.mkIf (pkgs.stdenv.isLinux && dotfilesEnabled) {
    # dev-gtk.nix owns the primary darkling.css source selection. Keep this
    # as a fallback so Linux hosts without that override can still resolve it.
    xdg.configFile."gtk/darkling.css".source = lib.mkDefault (
      config.lib.file.mkOutOfStoreSymlink "${config.dotfiles.root}/gtk/.config/gtk/darkling.css"
    );
  };
}
