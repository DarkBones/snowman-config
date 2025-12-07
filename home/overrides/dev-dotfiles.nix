{ lib, config, dotfilesSources, ... }:
let
  cfg = config.roles.dotfiles or { };
  
  sourceKey = cfg.sourceKey or config.home.username;
  dotfilesRepo = dotfilesSources.${sourceKey} or null;

  mode = builtins.getEnv "SNOWMAN_DOTFILES_MODE";
  isDev = mode == "dev";

  repoDir = "${config.home.homeDirectory}/${cfg.dir}";

  shouldReplaceScript = isDev || dotfilesRepo != null;

in {
  config = lib.mkIf (cfg.enable or false) {
    
    # 1. Disable the Base activation script so it doesn't fight us
    home.activation.dotfilesSync = lib.mkIf shouldReplaceScript (lib.mkForce "");

    # 2. Generate home.file entries
    home.file = lib.mapAttrs (target: srcPath: 
      if isDev then 
        { 
          source = config.lib.file.mkOutOfStoreSymlink "${repoDir}/${srcPath}"; 
        }
      else if dotfilesRepo != null then
        { 
          source = "${dotfilesRepo}/${srcPath}"; 
        }
      else 
        {}
    ) (cfg.linkMap or {});
  };
}
