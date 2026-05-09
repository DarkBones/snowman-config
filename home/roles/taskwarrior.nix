{
  lib,
  pkgs,
  pkgsUnstable,
  config,
  osConfig ? null,
  currentHost ? null,
  ...
}:
let
  cfg = config.roles.taskwarrior;
  homeDir = config.home.homeDirectory;
  syncRc = "${homeDir}/.task/sync.rc";
  sopsFile = ../../users/secrets/bas_secrets.yml;
  systemSecretPath =
    if
      osConfig != null
      && osConfig ? sops
      && osConfig.sops ? secrets
      && builtins.hasAttr cfg.secretName osConfig.sops.secrets
    then
      osConfig.sops.secrets.${cfg.secretName}.path
    else
      "";
in
{
  options.roles.taskwarrior = {
    enable = lib.mkEnableOption "Taskwarrior 3 client";

    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://100.126.175.104:53589";
      description = "TaskChampion sync server URL.";
    };

    clientId = lib.mkOption {
      type = lib.types.str;
      default = "c97db027-a4d3-4ff9-9e8e-ac4d1987399a";
      description = "TaskChampion sync client ID shared by this replica set.";
    };

    primaryHost = lib.mkOption {
      type = lib.types.str;
      default = "dorkbones";
      description = "Host that should generate recurring tasks.";
    };

    secretName = lib.mkOption {
      type = lib.types.str;
      default = "taskwarrior_sync_encryption_secret";
      description = "SOPS key containing sync.encryption_secret.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgsUnstable.taskwarrior3 ];

    home.file.".taskrc" = {
      force = true;
      text = ''
        # Managed by Snowman. Taskwarrior 3 sync uses TaskChampion.
        # The included sync rc is rendered from SOPS at activation time
        # because sync.encryption_secret must not enter the Nix store.
        data.location=${homeDir}/.task
        news.version=3.4.2
        editor=nvim
        uda.link.type=string
        uda.link.label=Link
        sync.server.url=${cfg.serverUrl}
        sync.server.client_id=${cfg.clientId}
        recurrence=${if currentHost == cfg.primaryHost then "on" else "off"}
        include ${syncRc}
      '';
    };

    home.activation.ensureTaskwarriorSyncRc = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      task_dir=${lib.escapeShellArg "${homeDir}/.task"}
      sync_rc=${lib.escapeShellArg syncRc}
      system_secret=${lib.escapeShellArg systemSecretPath}
      sops_file=${lib.escapeShellArg (toString sopsFile)}
      secret=""

      mkdir -p "$task_dir"
      chmod 700 "$task_dir"

      if [ -n "$system_secret" ] && [ -r "$system_secret" ]; then
        secret="$(${pkgs.coreutils}/bin/tr -d '\r\n' < "$system_secret")"
      elif [ -r "$sops_file" ]; then
        key_file="$(${pkgs.coreutils}/bin/mktemp "''${TMPDIR:-/tmp}/taskwarrior-sops-age.XXXXXX")"
        cleanup_taskwarrior_key() {
          ${pkgs.coreutils}/bin/rm -f "$key_file"
        }
        trap cleanup_taskwarrior_key EXIT

        for ssh_key in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
          if [ -r "$ssh_key" ]; then
            if ${pkgsUnstable.ssh-to-age}/bin/ssh-to-age -private-key -i "$ssh_key" > "$key_file" 2>/dev/null; then
              if secret="$(
                SOPS_AGE_KEY_FILE="$key_file" \
                  ${pkgsUnstable.sops}/bin/sops --decrypt \
                  --extract '["${cfg.secretName}"]' \
                  "$sops_file" 2>/dev/null
              )"; then
                secret="$(printf '%s' "$secret" | ${pkgs.coreutils}/bin/tr -d '\r\n')"
                break
              fi
            fi
          fi
        done

        cleanup_taskwarrior_key
        trap - EXIT
      fi

      if [ -n "$secret" ]; then
        tmp_rc="$(${pkgs.coreutils}/bin/mktemp "$task_dir/sync.rc.XXXXXX")"
        printf 'sync.encryption_secret=%s\n' "$secret" > "$tmp_rc"
        chmod 600 "$tmp_rc"
        ${pkgs.coreutils}/bin/mv "$tmp_rc" "$sync_rc"
      elif [ ! -e "$sync_rc" ]; then
        {
          echo "# Local Taskwarrior sync secret."
          echo "# Add ${cfg.secretName} to users/secrets/bas_secrets.yml."
          echo "# sync.encryption_secret=<shared secret>"
        } > "$sync_rc"
        chmod 600 "$sync_rc"
      fi
    '';
  };
}
