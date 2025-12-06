{ lib, dotfilesSources, ... }:
let
  dotfilesProd = dotfilesSources.bas;
  dotfilesDev = "/home/bas/Developer/dotfiles";

  mode = builtins.getEnv "SNOWMAN_DOTFILES_MODE";
  useDev = mode == "dev";
in {
  home.file.".config/nvim".source = lib.mkForce (if useDev then
    "${dotfilesDev}/nvim/.config/nvim"
  else
    "${dotfilesProd}/nvim/.config/nvim");
}
