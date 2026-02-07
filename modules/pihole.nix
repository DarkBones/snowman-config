{ lib, ... }: {
  services.resolved.enable = lib.mkForce false;

  networking.nameservers = [ "127.0.0.1" "1.1.1.1" ];

  services.pihole-ftl = {
    enable = true;
    openFirewallDNS = true;

    settings = {
      dns = {
        upstreams = [ "1.1.1.1" "1.0.0.1" ];
        listeningMode = "LOCAL";
        interface = "end0";
      };

      hosts = [ "192.168.178.63 pihole" "192.168.178.63 ha" ];
    };
  };

  services.pihole-web = {
    enable = true;
    ports = [ 80 ];
  };

  # also open HTTP on the firewall
  networking.firewall.allowedTCPPorts = [ 80 ];
}
