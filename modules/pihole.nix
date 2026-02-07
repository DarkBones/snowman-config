{ lib, config, ... }: {
  # Pi-hole wants port 53. systemd-resolved can grab it, so don’t let it.
  services.resolved.enable = lib.mkForce false;

  networking.nameservers = [ "127.0.0.1" "1.1.1.1" ];

  services.pihole-ftl = {
    enable = true;
    openFirewallDNS = true;

    settings = {
      dns.upstreams = [ "1.1.1.1" "1.0.0.1" ];

      dns.listeningMode = "BIND";

      # Optional: local host overrides
      hosts = [
        "192.168.178.66 ha"
        # TODO: Add pihole host?
      ];
    };

    lists = [{
      url =
        "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.txt";
      type = "block";
      enabled = true;
      description = "HaGeZi pro";
    }]; # TODO: Find more lists
  };

  services.pihole-web = {
    enable = true;
    ports = [ 80 ];
  };
}
