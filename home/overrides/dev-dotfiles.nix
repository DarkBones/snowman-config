{ lib, dotfilesSources, ... }:
let
  dotfilesProd = dotfilesSources.bas or null;
  mode   = builtins.getEnv "SNOWMAN_DOTFILES_MODE";
  useDev = mode == "dev";
in
{
  config = lib.mkIf (dotfilesProd != null) {
    home.file = lib.mkIf (!useDev) {
      ".config/nvim" = lib.mkForce {
        source = "${dotfilesProd}/nvim/.config/nvim";
      };
    };
  };
}
