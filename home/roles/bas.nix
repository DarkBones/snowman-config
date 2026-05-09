{
  lib,
  pkgs,
  pkgsUnstable,
  config,
  currentHost ? null,
  ...
}:
let
  cfg = config.roles.bas;
  homeDir = config.home.homeDirectory;
  taskwarriorClientNames = {
    dorkbones = "dorkbones";
    papershift-mbp = "papershift";
    mbp = "laptop";
  };
  taskwarriorClientName =
    if currentHost != null && builtins.hasAttr currentHost taskwarriorClientNames then
      taskwarriorClientNames.${currentHost}
    else
      null;

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

    home.file.".taskrc" = lib.mkIf (taskwarriorClientName != null) {
      force = true;
      text = ''
        # Managed by Snowman. Taskserver config is host-specific because the
        # client certificate and key differ per machine.
        data.location=${homeDir}/.task
        news.version=2.6.0
        editor=nvim
        uda.link.type=string
        uda.link.label=Link
        taskd.server=100.126.175.104:53589
        taskd.credentials=bas\/bas\/c97db027-a4d3-4ff9-9e8e-ac4d1987399a
        taskd.ca=${homeDir}/.task/keys/ca.cert.pem
        taskd.trust=ignore hostname
        taskd.certificate=${homeDir}/.task/keys/${taskwarriorClientName}.cert.pem
        taskd.key=${homeDir}/.task/keys/${taskwarriorClientName}.key.pem
      '';
    };
  };
}
