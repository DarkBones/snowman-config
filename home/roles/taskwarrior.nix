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
  maybeSystemSecret = secretName:
    if
      osConfig != null
      && osConfig ? sops
      && osConfig.sops ? secrets
      && builtins.hasAttr secretName osConfig.sops.secrets
    then
      osConfig.sops.secrets.${secretName}.path
    else
      "";
  systemEncryptionSecretPath = maybeSystemSecret cfg.secretName;
  systemClientIdSecretPath = maybeSystemSecret cfg.clientIdSecretName;
in
{
  options.roles.taskwarrior = {
    enable = lib.mkEnableOption "Taskwarrior 3 client";

    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://100.126.175.104:53589";
      description = "TaskChampion sync server URL.";
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

    clientIdSecretName = lib.mkOption {
      type = lib.types.str;
      default = "taskwarrior_sync_client_id";
      description = "SOPS key containing sync.server.client_id.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgsUnstable.taskwarrior3 ];

    home.file.".taskrc" = {
      force = true;
      text = ''
        # Managed by Snowman. Taskwarrior 3 sync uses TaskChampion.
        # The included sync rc is rendered from SOPS at activation time
        # because sync.server.client_id and sync.encryption_secret must not enter the Nix store.
        data.location=${homeDir}/.task
        news.version=3.4.2
        editor=nvim
        uda.link.type=string
        uda.link.label=Link
        sync.server.url=${cfg.serverUrl}
        recurrence=${if currentHost == cfg.primaryHost then "on" else "off"}
        include ${syncRc}
      '';
    };

    home.activation.ensureTaskwarriorSyncRc = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      task_dir=${lib.escapeShellArg "${homeDir}/.task"}
      sync_rc=${lib.escapeShellArg syncRc}
      system_encryption_secret=${lib.escapeShellArg systemEncryptionSecretPath}
      system_client_id_secret=${lib.escapeShellArg systemClientIdSecretPath}
      sops_file=${lib.escapeShellArg (toString sopsFile)}
      encryption_secret=""
      client_id=""
      encryption_secret_name=${lib.escapeShellArg cfg.secretName}
      client_id_secret_name=${lib.escapeShellArg cfg.clientIdSecretName}

      mkdir -p "$task_dir"
      chmod 700 "$task_dir"

      if [ -n "$system_encryption_secret" ] && [ -r "$system_encryption_secret" ]; then
        encryption_secret="$(${pkgs.coreutils}/bin/tr -d '\r\n' < "$system_encryption_secret")"
      fi
      if [ -n "$system_client_id_secret" ] && [ -r "$system_client_id_secret" ]; then
        client_id="$(${pkgs.coreutils}/bin/tr -d '\r\n' < "$system_client_id_secret")"
      fi

      if { [ -z "$encryption_secret" ] || [ -z "$client_id" ]; } && [ -r "$sops_file" ]; then
        key_file="$(${pkgs.coreutils}/bin/mktemp "''${TMPDIR:-/tmp}/taskwarrior-sops-age.XXXXXX")"
        cleanup_taskwarrior_key() {
          ${pkgs.coreutils}/bin/rm -f "$key_file"
        }
        trap cleanup_taskwarrior_key EXIT

        decrypt_taskwarrior_secret() {
          SOPS_AGE_KEY_FILE="$key_file" \
            ${pkgsUnstable.sops}/bin/sops --decrypt \
            --extract "[\"$1\"]" \
            "$sops_file" 2>/dev/null \
            | ${pkgs.coreutils}/bin/tr -d '\r\n'
        }

        for ssh_key in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
          if [ -r "$ssh_key" ]; then
            if ${pkgsUnstable.ssh-to-age}/bin/ssh-to-age -private-key -i "$ssh_key" > "$key_file" 2>/dev/null; then
              if [ -z "$encryption_secret" ]; then
                encryption_secret="$(decrypt_taskwarrior_secret "$encryption_secret_name" || true)"
              fi
              if [ -z "$client_id" ]; then
                client_id="$(decrypt_taskwarrior_secret "$client_id_secret_name" || true)"
              fi

              if [ -n "$encryption_secret" ] && [ -n "$client_id" ]; then
                break
              fi
            fi
          fi
        done

        cleanup_taskwarrior_key
        trap - EXIT
      fi

      if [ -n "$encryption_secret" ] && [ -n "$client_id" ]; then
        tmp_rc="$(${pkgs.coreutils}/bin/mktemp "$task_dir/sync.rc.XXXXXX")"
        printf 'sync.server.client_id=%s\n' "$client_id" > "$tmp_rc"
        printf 'sync.encryption_secret=%s\n' "$encryption_secret" >> "$tmp_rc"
        chmod 600 "$tmp_rc"
        ${pkgs.coreutils}/bin/mv "$tmp_rc" "$sync_rc"
      elif [ ! -e "$sync_rc" ]; then
        {
          echo "# Local Taskwarrior sync config."
          echo "# Add ${cfg.clientIdSecretName} and ${cfg.secretName} to users/secrets/bas_secrets.yml."
          echo "# sync.server.client_id=<shared client id>"
          echo "# sync.encryption_secret=<shared secret>"
        } > "$sync_rc"
        chmod 600 "$sync_rc"
      fi
    '';
  };
}
