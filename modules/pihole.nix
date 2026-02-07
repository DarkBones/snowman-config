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

      services.pihole-ftl.settings = {
        dns = {
          upstreams = [ "1.1.1.1" "1.0.0.1" ];
          listeningMode = "LOCAL";
          interface = "end0";
        };

        hosts = {
          pihole = "192.168.178.63";
          ha = "192.168.178.63";
        };
      };
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
