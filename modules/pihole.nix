{ lib, ... }: {
  services.resolved.enable = lib.mkForce false;

  networking.nameservers = [ "127.0.0.1" "1.1.1.1" ];

  services.pihole-ftl = {
    enable = true;
    openFirewallDNS = true;

    settings = {
      dns = {
        upstreams =
          [ "1.1.1.1" "1.0.0.1" "2606:4700:4700::1111" "2606:4700:4700::1001" ];
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
