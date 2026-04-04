{ pkgs, ... }: {
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  environment = { systemPackages = with pkgs; [ parted efibootmgr ]; };

  security = {
    sudo = {
      extraConfig = ''
        Defaults: ha !requiretty
      '';
      extraRules = [{
        users = [ "ha" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl suspend";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl hibernate";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl lock-session";
            options = [ "NOPASSWD" ];
          }

          {
            command =
              "/run/current-system/sw/bin/systemctl restart sunshine.service";
            options = [ "NOPASSWD" ];
          }
        ];
      }];
    };
  };

  networking = {
    enableIPv6 = false;

    nameservers = [ "1.1.1.1" "8.8.8.8" ]; # TODO: Quad 9

    firewall = {
      enable = true;
      allowPing = true;

      # LAN access: SSH
      allowedTCPPorts = [
        22
        80
        13378
        27036 # Steam link
        27037 # Steam link
      ];

      # LAN discovery
      allowedUDPPorts = [
        5353
        27031 # Steam link
        27036 # Steam link
        10400 # Steam link
        10401 # Steam link
      ];

      checkReversePath = "loose";

      # Trust LAN + Tailscale interfaces
      trustedInterfaces = [ "wlan0" "tailscale0" ];
    };
  };

  networking.hosts = { "192.168.178.63" = [ "ha" "pihole" ]; };

  snowman.reverseProxy.enable = true;

  services.searx.settings.server.base_url = "http://searxng/";

  services.nginx.virtualHosts = {
    ha = {
      serverName = "ha";

      locations."/" = {
        proxyPass = "http://192.168.178.63:8123";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host;
        '';
      };
    };

    pihole = {
      serverName = "pihole";

      locations."/" = {
        proxyPass = "http://192.168.178.63";
        proxyWebsockets = true;
      };
    };
  };
}
