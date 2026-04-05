args@{ lib, config, dotfilesSources, ... }:
let
  snowmanDotfilesMode = args.snowmanDotfilesMode or null;
  snowmanDotfilesIsDev = args.snowmanDotfilesIsDev or null;

  cfg = config.roles.dotfiles or { };
  sourceKey = cfg.sourceKey or config.home.username;
  dotfilesRepo = dotfilesSources.${sourceKey} or null;

  rawMode = builtins.getEnv "SNOWMAN_DOTFILES_MODE";
  fallbackMode = if rawMode == "dev" || rawMode == "prod" then rawMode else "prod";
  fallbackIsDev = fallbackMode == "dev";

  mode =
    if snowmanDotfilesMode != null then
      snowmanDotfilesMode
    else if snowmanDotfilesIsDev != null then
      if snowmanDotfilesIsDev then "dev" else "prod"
    else
      fallbackMode;

  isDev =
    if snowmanDotfilesIsDev != null then
      snowmanDotfilesIsDev
    else if snowmanDotfilesMode != null then
      snowmanDotfilesMode == "dev"
    else
      fallbackIsDev;

  repoDir = "${config.home.homeDirectory}/${cfg.dir or "Developer/dotfiles"}";
  root = if isDev then
    repoDir
  else if dotfilesRepo != null then
    toString dotfilesRepo
  else
    throw "dotfiles: PROD mode but no pinned dotfiles source for ${sourceKey}";
in {
  config.assertions = [{
    assertion =
      snowmanDotfilesMode == null || snowmanDotfilesIsDev == null
      || ((snowmanDotfilesMode == "dev") == snowmanDotfilesIsDev);
    message = ''
      dotfiles-root: inconsistent Snowman dotfiles special args.
      Expected snowmanDotfilesMode and snowmanDotfilesIsDev to agree:
      "dev" iff true, "prod" iff false.
    '';
  }];

  options.dotfiles.mode = lib.mkOption {
    type = lib.types.enum [ "dev" "prod" ];
    readOnly = true;
    default = mode;
    description = "Resolved dotfiles mode.";
  };

  options.dotfiles.isDev = lib.mkOption {
    type = lib.types.bool;
    readOnly = true;
    default = isDev;
    description = "Whether dotfiles mode is dev.";
  };

  options.dotfiles.root = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    default = root;
    description = "Resolved dotfiles root (DEV checkout or PROD pinned input).";
  };
}
