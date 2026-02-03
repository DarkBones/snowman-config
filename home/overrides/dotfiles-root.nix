{ lib, config, dotfilesSources, ... }:
let
  cfg = config.roles.dotfiles or { };
  sourceKey = cfg.sourceKey or config.home.username;
  dotfilesRepo = dotfilesSources.${sourceKey} or null;

  mode = builtins.getEnv "SNOWMAN_DOTFILES_MODE";
  isDev = mode == "dev";

  repoDir = "${config.home.homeDirectory}/${cfg.dir or "Developer/dotfiles"}";

  root = if isDev then
    repoDir
  else if dotfilesRepo != null then
    toString dotfilesRepo
  else
    throw "dotfiles: PROD mode but no pinned dotfiles source for ${sourceKey}";
in {
  options.dotfiles.root = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    default = root;
    description = "Resolved dotfiles root (DEV checkout or PROD pinned input).";
  };
}
