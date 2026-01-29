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
      glib
      jq
      less
      fastfetch
      networkmanager
      ripgrep
      taskwarrior2
      tmux
      tmuxinator
      unzip
      wget
      xclip
      zoxide
    ]) ++ [ neovim ];

    home.file.".tmux/plugins/tpm".source = pkgs.fetchFromGitHub {
      owner = "tmux-plugins";
      repo = "tpm";
      rev = "v3.1.0";
      sha256 = "sha256-CeI9Wq6tHqV68woE11lIY4cLoNY8XWyXyMHTDmFKJKI=";
    };
  };
}
