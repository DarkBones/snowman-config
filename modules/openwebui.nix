{ pkgs, ... }: {
  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 4080;
    environment = {
      HOME = "/var/lib/open-webui";
      NLTK_DATA = "/var/lib/open-webui/nltk_data";
    };
  };

  services.searx = {
    enable = true;
    environmentFile = "/var/lib/searxng/searx.env";

    settings = {
      server = {
        bind_address = "127.0.0.1";
        port = 8888;
        base_url = "http://search/";
        secret_key = "$SEARX_SECRET_KEY";
      };

      search = {
        formats = [ "html" "json" ];
        safe_search = 0;
      };

      general.instance_name = "SearXNG";

      # TODO: Trim engines for Reddit-heavy use once you've confirmed which
      # upstream sources are the most reliable for your Open WebUI workflow.
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/searxng 0750 searx searx -"
  ];

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
}
