{ lib, config, ... }:
let
  cfg = config.roles.dotfiles or { };
  # Use the engine's resolved root and dev flag
  root = config.dotfiles.root;
  isDev = config.dotfiles.isDev;
in {
  config = lib.mkIf (cfg.enable or false) {
    # Disable the engine's built-in dotfilesSync because we use linkMap
    home.activation.dotfilesSync = lib.mkForce "";

    home.file = lib.mapAttrs (_target: srcPath: {
      # Use out-of-store symlinks ONLY in dev mode
      source = if isDev 
        then config.lib.file.mkOutOfStoreSymlink "${root}/${srcPath}"
        else "${root}/${srcPath}";
    }) (cfg.linkMap or { });
  };
}
