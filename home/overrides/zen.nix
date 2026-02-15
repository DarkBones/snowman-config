{ lib, pkgs, config, ... }: {
  config = lib.mkIf pkgs.stdenv.isLinux {
    xdg.configFile."gtk/darkling.css".source =
      config.lib.file.mkOutOfStoreSymlink
      "${config.dotfiles.root}/gtk/.config/gtk/darkling.css";
  };
}
