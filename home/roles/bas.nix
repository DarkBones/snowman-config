{ lib, pkgsUnstable, config, ... }:
let cfg = config.roles.bas;
in {
  options.roles.dev.enable = lib.mkEnableOption "Bas role";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgsUnstable; [
      bat
      btop
      entr
      eza
      fzf
      git
      less
      neofetch
      neovim
      networkmanager
      ripgrep
      secure-delete
      starship
      tmux
      zoxide
    ];
  };
}
