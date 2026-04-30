{ pkgs, ... }:
let
  wideResultsTemplates = pkgs.runCommand "searxng-wide-results-templates" { } ''
    cp -R ${pkgs.searxng}/lib/python*/site-packages/searx/templates "$out"
    chmod -R u+w "$out"

    cat > wide-results-style.html <<'EOF'
  <style>
    @media screen and (min-width: 92rem) {
      #main_results .search_box {
        max-width: 62rem;
      }

      #main_results div#results:not(.only_template_images, .image-detail-open) {
        grid-template:
          "corrections sidebar" min-content
          "answers sidebar" min-content
          "urls sidebar" 1fr
          "pagination sidebar" min-content / 62rem 25rem !important;
      }

      #main_results div#results:not(.only_template_images, .image-detail-open) #backToTop {
        left: 73.3rem;
      }

      .center-alignment-yes #main_results {
        --center-page-width: 92rem !important;
      }

      #main_results .result .content,
      #main_results .result .stat {
        max-width: none;
      }
    }
  </style>
EOF

    substituteInPlace "$out/simple/base.html" \
      --replace-fail '</head>' "$(cat wide-results-style.html)
</head>"
  '';
in
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
        autocomplete = "google";
        formats = [
          "html"
          "json"
        ];
        favicon_resolver = "duckduckgo";
        safe_search = 0;
      };

      general.instance_name = "SearXNG";

      ui.templates_path = "${wideResultsTemplates}";
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
