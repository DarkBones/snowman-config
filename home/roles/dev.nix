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
      lazydocker
      lazygit
      nmap
      nodejs_24
      pkgs.git
      pnpm
      tokei
    ]) ++ [ neovim ];
  };
}
