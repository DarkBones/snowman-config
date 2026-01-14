{ lib, config, dotfilesSources, ... }:
let
  cfg = config.roles.dotfiles or { };

  sourceKey = cfg.sourceKey or config.home.username;
  dotfilesRepo = dotfilesSources.${sourceKey} or null;

  mode = builtins.getEnv "SNOWMAN_DOTFILES_MODE";
  isDev = mode == "dev";

  # Calculate the absolute path to your local repo for Dev mode
  # e.g. /home/bas/Developer/dotfiles
  repoDir = "${config.home.homeDirectory}/${cfg.dir}";

  # Determine if we should replace the activation script
  # We do this if we are managing the files via home.file (Dev or Prod-Pinned)
  shouldReplaceScript = isDev || dotfilesRepo != null;

in {
  config = lib.mkIf (cfg.enable or false) {

    # 1. Disable the Base activation script so it doesn't fight us
    home.activation.dotfilesSync =
      lib.mkIf shouldReplaceScript (lib.mkForce "");

    # 2. Generate home.file entries
    home.file = lib.mapAttrs (target: srcPath:
      if isDev then
      # Dev Mode: Home Manager creates a symlink to your local repo
      {
        source = config.lib.file.mkOutOfStoreSymlink "${repoDir}/${srcPath}";
      } else if dotfilesRepo != null then
      # Prod Mode: Home Manager creates a symlink to the Nix Store
      {
        source = "${dotfilesRepo}/${srcPath}";
      } else
      # Git Mode (Fallback): Do nothing, let the activation script handle it
        { }) (cfg.linkMap or { });
  };
}
