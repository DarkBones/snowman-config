{ lib, ... }: {
  services.resolved.enable = lib.mkForce false;

  networking.nameservers = [ "127.0.0.1" "1.1.1.1" ];

  environment.etc."pihole/hosts/99-local.conf".text = ''
    192.168.178.63 pihole
    192.168.178.63 ha
  '';

  services.pihole-ftl = {
    enable = true;
    openFirewallDNS = true;

    settings = {
      dns = {
        upstreams = [ "1.1.1.1" "1.0.0.1" ];
        listeningMode = "LOCAL";
        interface = "end0";
      };

      # Local DNS entries
      hosts = [ "192.168.178.63 pihole" "192.168.178.63 ha" ];
    };

    lists = [{
      url =
        "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.txt";
      type = "block";
      enabled = true;
      description = "HaGeZi pro";
    }];
  };

  services.pihole-web = {
    enable = true;
    ports = [ 80 ];
  };
}
