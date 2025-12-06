{ lib, dotfilesSources, ... }:
let
  dotfilesProd = dotfilesSources.bas;

  mode   = builtins.getEnv "SNOWMAN_DOTFILES_MODE";
  useDev = mode == "dev";
in
{
  # In PROD mode, manage ~/.config/nvim from the Nix store.
  # In DEV mode, Home Manager leaves ~/.config/nvim alone so you can point it
  # at ~/Developer/dotfiles manually.
  home.file = lib.mkIf (!useDev) {
    ".config/nvim" = lib.mkForce {
      source    = "${dotfilesProd}/nvim/.config/nvim";
      recursive = true;
    };
  };
}
