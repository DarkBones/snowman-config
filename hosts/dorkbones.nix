{ pkgs, lib, ... }:
let
  polkitAgent =
    "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
in {
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  boot.initrd.systemd.enable = true;

  environment = {
    variables = {
      XCURSOR_THEME = "Bibata-Modern-Classic";
      XCURSOR_SIZE = lib.mkDefault 24;
    };
    systemPackages = with pkgs; [ parted bibata-cursors efibootmgr ];
  };

  programs.kdeconnect.enable = true;

  security = {
    polkit.enable = true;

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

  systemd.user.services.polkit-gnome-agent = {
    description = "Polkit GNOME Authentication Agent";
    wantedBy = [ "default.target" ];
    after = [ "graphical-session-pre.target" "dbus.service" ];
    serviceConfig = {
      ExecStart = polkitAgent;
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  home-manager.users.bas = {
    home.username = "bas";
    home.homeDirectory = "/home/bas";
    imports = [ ../home ];
    systemd.user.startServices = lib.mkForce true;
  };

  networking = {
    enableIPv6 = false;

    nameservers = [ "1.1.1.1" "8.8.8.8" ]; # TODO: Quad 9

    extraHosts = ''
      127.0.0.1 ai
      127.0.0.1 sonarr
      127.0.0.1 radarr
      127.0.0.1 nzb
      192.168.178.66 ha
    '';

    firewall = {
      enable = true;
      allowPing = true;

      # LAN access: SSH
      allowedTCPPorts = [ 22 80 ];

      # LAN discovery
      allowedUDPPorts = [ 5353 ];

      checkReversePath = "loose";

      # Trust LAN + Tailscale interfaces
      trustedInterfaces = [ "wlan0" "tailscale0" ];
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services = {
    tailscale = {
      enable = true;
      openFirewall = true;
    };

    pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
      wireplumber.enable = true;
    };

    blueman.enable = true;

    displayManager.sddm = {
      enable = true;
      theme = "breeze";
    };

    nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;

      virtualHosts = {
        "ai" = {
          locations."/" = {
            proxyPass = "http://127.0.0.1:4080";
            proxyWebsockets = true;
          };
        };
        "ha" = {
          serverName = "ha";

          locations."/" = {
            proxyPass = "http://192.168.178.66:8123";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header X-Forwarded-Host $host;
            '';
          };
        };
        "sonarr" = {
          locations."/" = {
            proxyPass = "http://127.0.0.1:8989";
            proxyWebsockets = true;
          };
        };
        "radarr" = {
          locations."/" = {
            proxyPass = "http://127.0.0.1:7878";
            proxyWebsockets = true;
          };
        };
        "nzb" = {
          locations."/" = {
            proxyPass = "http://127.0.0.1:8091";
            proxyWebsockets = true;
          };
        };
      };
    };
  };
}
