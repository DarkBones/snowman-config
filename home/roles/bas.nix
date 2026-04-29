{
  lib,
  pkgs,
  pkgsUnstable,
  config,
  ...
}:
let
  cfg = config.roles.bas;

  neovim = import ../pkgs/neovim.nix { inherit pkgs pkgsUnstable; };

  tmuxinator = pkgs.symlinkJoin {
    name = "tmuxinator-${pkgsUnstable.tmuxinator.version}-isolated";
    paths = [ pkgsUnstable.tmuxinator ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/tmuxinator" \
        --set GEM_HOME "${pkgsUnstable.tmuxinator}/${pkgsUnstable.tmuxinator.ruby.gemPath}"
    '';
  };

  commonPkgs = with pkgsUnstable; [
    bat
    btop
    eza
    fzf
    htop
    jq
    less
    fastfetch
    ripgrep
    taskwarrior2
    tmux
    unzip
    wget
    zoxide
  ];

  linuxPkgs = with pkgsUnstable; [
    dnsutils
    glib
    networkmanager
    xclip
    gnutls.bin
  ];

  darwinPkgs = with pkgsUnstable; [ ];
in
{
  options.roles.bas.enable = lib.mkEnableOption "Bas role";

  config = lib.mkIf cfg.enable {
    home.packages =
      commonPkgs
      ++ lib.optionals pkgs.stdenv.isLinux linuxPkgs
      ++ lib.optionals pkgs.stdenv.isDarwin darwinPkgs
      ++ [
        neovim
        tmuxinator
      ];

    home.file.".tmux/plugins/tpm".source = pkgs.fetchFromGitHub {
      owner = "tmux-plugins";
      repo = "tpm";
      rev = "v3.1.0";
      sha256 = "sha256-CeI9Wq6tHqV68woE11lIY4cLoNY8XWyXyMHTDmFKJKI=";
    };
  };
}
