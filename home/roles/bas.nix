{ lib, pkgs, pkgsUnstable, config, ... }:
let
  cfg = config.roles.bas;

  neovim = import ../pkgs/neovim.nix { inherit pkgs pkgsUnstable; };
in {
  options.roles.bas.enable = lib.mkEnableOption "Bas role";

  config = lib.mkIf cfg.enable {
    home.packages = (with pkgsUnstable; [
      bat
      btop
      eza
      fzf
      less
      fastfetch
      networkmanager
      ripgrep
      tmux
      wget
      zoxide
    ]) ++ [ neovim ];
  };
}
