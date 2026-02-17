{ ... }: {
  services.taskserver = {
    enable = true;
    dataDir = "/var/lib/taskserver";

    config = { "server.listen" = "0.0.0.0:53589"; };
  };

  networking.firewall.allowedTCPPorts = [ 53589 ];
}
