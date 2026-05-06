{ pkgs, inv, ... }:
let
  rpi4HomeNetwork = inv.hosts.rpi4.network.home;
in
{
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  environment = {
    systemPackages = with pkgs; [
      parted
      efibootmgr
    ];
  };

  # Use real S3 sleep on this desktop so fans and board power down.
  boot.kernelParams = [ "mem_sleep_default=deep" ];

  powerManagement.resumeCommands = ''
    for dev in /sys/bus/usb/devices/*; do
      [ -r "$dev/idVendor" ] && [ -r "$dev/idProduct" ] || continue

      if [ "$(${pkgs.coreutils}/bin/cat "$dev/idVendor")" = "0bda" ] \
        && [ "$(${pkgs.coreutils}/bin/cat "$dev/idProduct")" = "a729" ]; then
        usb_id="$(${pkgs.coreutils}/bin/basename "$dev")"
        echo "$usb_id" > /sys/bus/usb/drivers/usb/unbind || true
        ${pkgs.coreutils}/bin/sleep 1
        echo "$usb_id" > /sys/bus/usb/drivers/usb/bind || true
      fi
    done

    ${pkgs.systemd}/bin/systemctl try-restart bluetooth.service
  '';

  systemd.services.NetworkManager-wait-online.serviceConfig.ExecStart = [
    ""
    "${pkgs.networkmanager}/bin/nm-online -q --timeout=30"
  ];

  security = {
    sudo = {
      extraConfig = ''
        Defaults: ha !requiretty
      '';
      extraRules = [
        {
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
              command = "/run/current-system/sw/bin/systemctl restart sunshine.service";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
    };
  };

  networking = {
    enableIPv6 = false;

    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ]; # TODO: Quad 9

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
      trustedInterfaces = [
        "wlan0"
        "tailscale0"
      ];
    };
  };

  networking.hosts = {
    "${rpi4HomeNetwork.ipv4}" = rpi4HomeNetwork.aliases;
  };

  snowman.reverseProxy.enable = true;
  snowman.desktopNotifySsh.enable = true;

  services.searx.settings.server.base_url = "http://searxng/";

  services.nginx.virtualHosts = {
    ha = {
      serverName = "ha";

      locations."/" = {
        proxyPass = "http://${rpi4HomeNetwork.ipv4}:8123";
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
        proxyPass = "http://${rpi4HomeNetwork.ipv4}";
        proxyWebsockets = true;
      };
    };
  };
}
