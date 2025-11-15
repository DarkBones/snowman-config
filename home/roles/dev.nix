{ lib, pkgs, pkgsUnstable, config, ... }:
let cfg = config.roles.dev;
in {
  options.roles.dev.enable = lib.mkEnableOption "Dev role";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgsUnstable; [
      neovim
      pkgs.git
      fzf
      cowsay
      pnpm
      docker
      gcc
      figlet
    ];
  };
}
