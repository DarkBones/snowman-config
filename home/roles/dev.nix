{ lib, pkgs, pkgsUnstable, config, ... }:
let
  cfg = config.roles.dev;
  neovim = import ../pkgs/neovim.nix { inherit pkgs pkgsUnstable; };
in {
  options.roles.dev.enable = lib.mkEnableOption "Dev role";

  config = lib.mkIf cfg.enable {
    home.packages = (with pkgsUnstable; [
      cowsay
      docker
      entr
      figlet
      fzf
      gcc
      pkgs.git
      pnpm
      tokei
    ]) ++ [ neovim ];

    home.file.".tmux/plugins/tpm".source = pkgs.fetchFromGitHub {
      owner = "tmux-plugins";
      repo = "tpm";
      rev = "v3.1.0";
      sha256 = "sha256-CeI9Wq6tHqV68woE11lIY4cLoNY8XWyXyMHTDmFKJKI=";
    };
  };
}
