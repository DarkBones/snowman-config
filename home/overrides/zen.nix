# TODO: This is experimental. This should let zen read and write its dotfiles
{ config, lib, ... }:
let dotfilesDev = "${config.home.homeDirectory}/Developer/dotfiles";
in {
  # This does NOT go through bas-dotfiles (flake input),
  # it points straight at your real clone.
  xdg.configFile."gtk/darkling.css".source = config.lib.file.mkOutOfStoreSymlink
    "${config.dotfiles.root}/gtk/.config/gtk/darkling.css";
}
