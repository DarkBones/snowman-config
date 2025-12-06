{ lib, dotfilesSources, ... }:
let
  dotfilesProd = dotfilesSources.bas;

  mode   = builtins.getEnv "SNOWMAN_DOTFILES_MODE";
  useDev = mode == "dev";
in
{
  home.file = lib.mkIf (!useDev) {
    ".config/nvim" = lib.mkForce {
      source    = "${dotfilesProd}/nvim/.config/nvim";
      recursive = true;
    };
  };
}
