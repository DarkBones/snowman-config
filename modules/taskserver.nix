{ pkgs, lib, ... }:
let
  dataDir = "/var/lib/taskserver";
in {
  services.taskserver = {
    enable = true;
    dataDir = dataDir;
  };

  systemd.services.taskserver.serviceConfig.ExecStartPre = lib.mkForce [ ];

  environment.systemPackages = [ pkgs.taskserver ];

  systemd.services.taskserver.serviceConfig.ExecStart = lib.mkForce [
    ''
      ${pkgs.taskserver}/bin/taskd server \
        --ca.cert=${dataDir}/keys/ca.cert \
        --server.cert=${dataDir}/keys/server.cert \
        --server.key=${dataDir}/keys/server.key \
        --server.crl=${dataDir}/keys/server.crl \
        --log=- \
        --daemon=false \
        --trust=strict \
        --server=0.0.0.0:53589
    ''
  ];

  networking.firewall.allowedTCPPorts = [ 53589 ];
}
