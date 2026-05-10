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

  # Use real S3 sleep on this desktop. s2idle resumes more like "modern standby"
  # here: fans stay up, board power stays high, and NVIDIA/Hyprland has resumed
  # with a broken lock surface.
  boot.kernelParams = [
    "mem_sleep_default=deep"
    "usbcore.autosuspend=-1"
  ];
  systemd.sleep.extraConfig = ''
    SuspendState=mem
    MemorySleepMode=deep
  '';

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="change", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="pci", DRIVER=="xhci_hcd", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="change", SUBSYSTEM=="pci", DRIVER=="xhci_hcd", TEST=="power/control", ATTR{power/control}="on"
  '';

  systemd.services.NetworkManager-wait-online.serviceConfig.ExecStart = [
    ""
    "${pkgs.networkmanager}/bin/nm-online -q --timeout=30"
  ];

  system.activationScripts."dorkbones-remove-wifi-profiles" = ''
    ${pkgs.coreutils}/bin/rm -f /etc/NetworkManager/system-connections/snowman-home.nmconnection
    ${pkgs.coreutils}/bin/rm -f /etc/NetworkManager/system-connections/snowman-s10.nmconnection
    ${pkgs.networkmanager}/bin/nmcli connection reload >/dev/null 2>&1 || true
    ${pkgs.networkmanager}/bin/nmcli -t -f UUID,TYPE connection show 2>/dev/null | while IFS=: read -r uuid type; do
      if [ "$type" = "802-11-wireless" ]; then
        ${pkgs.networkmanager}/bin/nmcli connection modify "$uuid" connection.autoconnect no >/dev/null 2>&1 || true
      fi
    done
    ${pkgs.networkmanager}/bin/nmcli radio wifi off >/dev/null 2>&1 || true
  '';

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
