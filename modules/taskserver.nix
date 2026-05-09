{ pkgs, ... }:
let
  dataDir = "/var/lib/taskchampion-sync-server";
  listen = "0.0.0.0:53589";
  clientId = "c97db027-a4d3-4ff9-9e8e-ac4d1987399a";
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
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    environment = {
      DATA_DIR = dataDir;
      LISTEN = listen;
      CLIENT_ID = clientId;
      RUST_LOG = "info";
    };

    serviceConfig = {
      Type = "simple";
      User = "taskchampion-sync-server";
      Group = "taskchampion-sync-server";
      StateDirectory = "taskchampion-sync-server";
      ExecStart = "${pkgs.taskchampion-sync-server}/bin/taskchampion-sync-server";
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
