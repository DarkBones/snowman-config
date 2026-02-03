{ lib, config, ... }:
let
  cfg = config.roles.dotfiles or { };
  root = config.dotfiles.root;
in {
  config = lib.mkIf (cfg.enable or false) {
    home.activation.dotfilesSync = lib.mkForce "";

    home.file = lib.mapAttrs (_target: srcPath: {
      source = config.lib.file.mkOutOfStoreSymlink "${root}/${srcPath}";
    }) (cfg.linkMap or { });
  };
}
