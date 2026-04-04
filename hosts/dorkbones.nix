{
  config,
  pkgs,
  lib,
  ...
}: {
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  systemd.tmpfiles.rules = [
    "L+ /bin/bash - - - - ${pkgs.bash}/bin/bash"
    "d /var/lib/openclaw-dashboard 0750 root nginx -"
  ];
  boot.initrd.systemd.enable = true;
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  systemd.oomd.enable = true;

  systemd.services.openclaw-dashboard-autologin = {
    description = "Generate local OpenClaw dashboard autologin page";
    wantedBy = ["multi-user.target"];
    before = ["nginx.service"];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "nginx";
      StateDirectory = "openclaw-dashboard";
      UMask = "0027";
    };
    script = ''
      set -euo pipefail

      token_file=${config.sops.secrets.openclaw_gateway_token.path}
      js_file=/var/lib/openclaw-dashboard/autologin.js

      token="$(${pkgs.coreutils}/bin/tr -d '\n' < "$token_file")"
      token_json="$(printf '%s' "$token" | ${pkgs.jq}/bin/jq -Rsa .)"

      cat > "$js_file" <<EOF
      (() => {
        if (window.location.hash.includes("token=")) return;
        const token = $token_json;
        window.location.replace("/index.html#token=" + encodeURIComponent(token));
      })();
      EOF

      chmod 0640 "$js_file"
    '';
  };

  systemd.services.nginx = {
    requires = ["openclaw-dashboard-autologin.service"];
    after = ["openclaw-dashboard-autologin.service"];
  };

  environment = {
    variables = {
      XCURSOR_THEME = "Bibata-Modern-Classic";
      XCURSOR_SIZE = lib.mkDefault 24;
    };
    systemPackages = with pkgs; [parted bibata-cursors efibootmgr];
  };

  programs.kdeconnect.enable = true;

  security = {
    polkit.enable = true;

    sudo = {
      extraConfig = ''
        Defaults: ha !requiretty
      '';
      extraRules = [
        {
          users = ["ha"];
          commands = [
            {
              command = "/run/current-system/sw/bin/systemctl suspend";
              options = ["NOPASSWD"];
            }
            {
              command = "/run/current-system/sw/bin/systemctl hibernate";
              options = ["NOPASSWD"];
            }
            {
              command = "/run/current-system/sw/bin/systemctl lock-session";
              options = ["NOPASSWD"];
            }

            {
              command = "/run/current-system/sw/bin/systemctl restart sunshine.service";
              options = ["NOPASSWD"];
            }
          ];
        }
      ];
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.bas = {
      home.username = "bas";
      home.homeDirectory = "/home/bas";
      imports = [../home];
      systemd.user.startServices = lib.mkForce true;
    };
  };

  networking = {
    enableIPv6 = false;

    nameservers = ["1.1.1.1" "8.8.8.8"]; # TODO: Quad 9

    extraHosts = ''
      127.0.0.1 ai
      127.0.0.1 openclaw
      127.0.0.1 searxng
      127.0.0.1 sonarr
      127.0.0.1 radarr
      127.0.0.1 shelf
      127.0.0.1 nzb
      127.0.0.1 plex
      192.168.178.63 ha
      192.168.178.63 pihole
    '';

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
      trustedInterfaces = ["wlan0" "tailscale0"];
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
        "openclaw" = {
          locations."= /__openclaw/autologin.js" = {
            extraConfig = ''
              alias /var/lib/openclaw-dashboard/autologin.js;
              default_type application/javascript;
              add_header Cache-Control "no-store" always;
              add_header Pragma "no-cache" always;
              add_header X-Robots-Tag "noindex, nofollow" always;
              allow 127.0.0.1;
              allow ::1;
              deny all;
            '';
          };
          locations."/" = {
            proxyPass = "http://127.0.0.1:18789";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Accept-Encoding "";
              sub_filter_once on;
              sub_filter_types text/html;
              sub_filter '</head>' '<script src="/__openclaw/autologin.js"></script></head>';
            '';
          };
        };
        "searxng" = {
          locations."/" = {
            proxyPass = "http://127.0.0.1:8888";
            proxyWebsockets = true;
          };
        };
        "ha" = {
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
        "pihole" = {
          serverName = "pihole";

          locations."/" = {
            proxyPass = "http://192.168.178.63";
            proxyWebsockets = true;
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
        "shelf" = {
          locations."/" = {
            proxyPass = "http://127.0.0.1:13378";
            proxyWebsockets = true;
          };
        };
        "nzb" = {
          locations."/" = {
            proxyPass = "http://127.0.0.1:8091";
            proxyWebsockets = true;
          };
        };
        "plex" = {
          locations."/" = {
            proxyPass = "http://127.0.0.1:32400";
            proxyWebsockets = true;
          };
        };
      };
    };
  };
}
