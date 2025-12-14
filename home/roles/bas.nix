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
      ghostty
      less
      neofetch
      networkmanager
      ripgrep
      spotify
      tmux
      zen-browser
      zoxide
    ]) ++ [ neovim ];
  };
}
