{ config, pkgs, ... }:
let
  dataDir = "/var/lib/taskchampion-sync-server";
  listen = "0.0.0.0:53589";
  clientIdSecretName = "taskwarrior_sync_client_id";
  clientIdCredentialName = "taskchampion-client-id";
  startScript = pkgs.writeShellScript "taskchampion-sync-server-start" ''
    set -euo pipefail

    client_id_file="$CREDENTIALS_DIRECTORY/${clientIdCredentialName}"
    export CLIENT_ID="$(${pkgs.coreutils}/bin/tr -d '\r\n' < "$client_id_file")"

    exec ${pkgs.taskchampion-sync-server}/bin/taskchampion-sync-server
  '';
in
{
  users.groups.taskchampion-sync-server = { };
  users.users.taskchampion-sync-server = {
    isSystemUser = true;
    group = "taskchampion-sync-server";
    home = dataDir;
  };

  environment.systemPackages = [ pkgs.taskchampion-sync-server ];

  systemd.services.taskchampion-sync-server = {
    description = "TaskChampion Sync Server";
    documentation = [ "https://gothenburgbitfactory.org/taskchampion-sync-server/" ];
    wantedBy = [ "multi-user.target" ];
    wants = [
      "network-online.target"
      "sops-nix.service"
    ];
    after = [
      "network-online.target"
      "sops-nix.service"
    ];

    environment = {
      DATA_DIR = dataDir;
      LISTEN = listen;
      RUST_LOG = "info";
    };

    serviceConfig = {
      Type = "simple";
      ExecStart = startScript;
      LoadCredential = "${clientIdCredentialName}:${config.sops.secrets.${clientIdSecretName}.path}";
      User = "taskchampion-sync-server";
      Group = "taskchampion-sync-server";
      StateDirectory = "taskchampion-sync-server";
      Restart = "on-failure";
      RestartSec = "5s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
    };
  };

  networking.firewall.allowedTCPPorts = [ 53589 ];
}
