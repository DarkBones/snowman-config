{ pkgs, ... }:
let
  taskdWrapped = pkgs.writeShellScriptBin "taskd" ''
    set -euo pipefail
    if [ "$#" -lt 1 ]; then
      exec ${pkgs.taskserver}/bin/taskd --help
    fi
    cmd="$1"
    shift
    exec ${pkgs.taskserver}/bin/taskd "$cmd" --data /var/lib/taskserver "$@"
  '';
in {
  services.taskserver = {
    enable = true;
    dataDir = "/var/lib/taskserver";
    config = { "server.listen" = "0.0.0.0:53589"; };
  };

  environment.systemPackages = [ taskdWrapped ];

  networking.firewall.allowedTCPPorts = [ 53589 ];
}
