{ pkgs, ... }:
{
  services.searx = {
    enable = true;
    environmentFile = "/var/lib/searxng/searx.env";

    settings = {
      server = {
        bind_address = "127.0.0.1";
        port = 8888;
        secret_key = "$SEARX_SECRET_KEY";
      };

      search = {
        formats = [
          "html"
          "json"
        ];
        safe_search = 0;
      };

      general.instance_name = "SearXNG";
    };
  };

  systemd.tmpfiles.rules = [ "d /var/lib/searxng 0750 searx searx -" ];

  systemd.services.searx-init-secret = {
    description = "Create persistent SearXNG secret key";
    wantedBy = [ "multi-user.target" ];
    before = [ "searx-init.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "searx";
      Group = "searx";
      StateDirectory = "searxng";
      UMask = "0077";
    };
    script = ''
      set -euo pipefail

      env_file=/var/lib/searxng/searx.env

      if [ ! -s "$env_file" ]; then
        secret_key="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
        printf 'SEARX_SECRET_KEY=%s\n' "$secret_key" > "$env_file"
      fi
    '';
  };

  systemd.services.searx-init = {
    requires = [ "searx-init-secret.service" ];
    after = [ "searx-init-secret.service" ];
  };

  networking.hosts."127.0.0.1" = [ "searxng" ];

  services.nginx.virtualHosts.searxng = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:8888";
      proxyWebsockets = true;
    };
  };
}
