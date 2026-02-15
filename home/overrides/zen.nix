{ lib, pkgs, config, ... }:
let dotfilesEnabled = (config.roles.dotfiles.enable or false);
in {
  config = lib.mkIf (pkgs.stdenv.isLinux && !dotfilesEnabled) {
    xdg.configFile."gtk/darkling.css".source =
      config.lib.file.mkOutOfStoreSymlink
      "${config.dotfiles.root}/gtk/.config/gtk/darkling.css";
  };
}
