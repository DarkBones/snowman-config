{ lib, pkgs, pkgsUnstable, config, ... }:
let
  cfg = config.roles.dev;
  neovim = import ../pkgs/neovim.nix { inherit pkgs pkgsUnstable; };

  commonPkgs = with pkgsUnstable; [
    cowsay
    docker
    entr
    figlet
    fzf
    lazydocker
    lazygit
    nmap
    nodejs_24
    meson
    ninja
    pkgs.git
    pnpm
    tokei
  ];

  linuxPkgs = with pkgsUnstable; [ gcc ];

  darwinPkgs = with pkgsUnstable; [ ];
in {
  options.roles.dev.enable = lib.mkEnableOption "Dev role";

  config = lib.mkIf cfg.enable {
    home.packages = commonPkgs ++ lib.optionals pkgs.stdenv.isLinux linuxPkgs
      ++ lib.optionals pkgs.stdenv.isDarwin darwinPkgs ++ [ neovim ];
  };
}
