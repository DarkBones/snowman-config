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
  taskwarriorSyncHosts = [
    "dorkbones"
    "papershift-mbp"
    "mbp"
  ];
  taskwarriorSyncEnabled = currentHost != null && lib.elem currentHost taskwarriorSyncHosts;
  taskwarriorPrimaryHost = "dorkbones";
  taskwarriorClientId = "c97db027-a4d3-4ff9-9e8e-ac4d1987399a";
  taskwarriorSyncRc = "${homeDir}/.task/sync.rc";

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
    taskwarrior3
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

    home.file.".taskrc" = lib.mkIf taskwarriorSyncEnabled {
      force = true;
      text = ''
        # Managed by Snowman. Taskwarrior 3 sync uses TaskChampion.
        # The included sync rc is local because it contains the shared
        # sync.encryption_secret and must not enter the Nix store.
        data.location=${homeDir}/.task
        news.version=3.4.2
        editor=nvim
        uda.link.type=string
        uda.link.label=Link
        sync.server.url=http://100.126.175.104:53589
        sync.server.client_id=${taskwarriorClientId}
        recurrence=${if currentHost == taskwarriorPrimaryHost then "on" else "off"}
        include ${taskwarriorSyncRc}
      '';
    };

    home.activation.ensureTaskwarriorSyncRc = lib.mkIf taskwarriorSyncEnabled (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        task_dir=${lib.escapeShellArg "${homeDir}/.task"}
        sync_rc=${lib.escapeShellArg taskwarriorSyncRc}

        mkdir -p "$task_dir"
        if [ ! -e "$sync_rc" ]; then
          {
            echo "# Local Taskwarrior sync secret. Not managed by Snowman."
            echo "# Put this exact setting on every replica:"
            echo "# sync.encryption_secret=<shared secret>"
          } > "$sync_rc"
          chmod 600 "$sync_rc"
        fi
      ''
    );
  };
}
