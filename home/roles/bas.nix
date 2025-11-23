{ lib, pkgs, pkgsUnstable, config, ... }:
let cfg = config.roles.bas;
in {
  options.roles.bas.enable = lib.mkEnableOption "Bas role";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgsUnstable; [
      bat
      btop
      eza
      fzf
      less
      neofetch
      neovim
      networkmanager
      ripgrep
      starship
      tmux
      zoxide
    ];
  };
}
