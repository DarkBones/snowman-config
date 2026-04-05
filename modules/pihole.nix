{ lib, inv, currentHost, ... }:
let
  lan = lib.attrByPath [ "hosts" currentHost "network" "home" ] null inv;
in {
  services.resolved.enable = lib.mkForce false;

  networking = {
    nameservers = [ "127.0.0.1" "1.1.1.1" ];
    firewall.allowedTCPPorts = [ 80 ];
    interfaces.end0.ipv6.addresses = [{
      address = "fdca:f21d:f446:0::53";
      prefixLength = 64;
    }];
  };

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

      hosts = map (alias: "${lan.ipv4} ${alias}") lan.aliases;
    };
  };

  services.pihole-web = {
    enable = true;
    ports = [ 80 ];
  };
}
