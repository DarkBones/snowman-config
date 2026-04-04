{ config, pkgs, ... }: {
  systemd.tmpfiles.rules = [
    "d /var/lib/openclaw-dashboard 0750 root nginx -"
  ];

  systemd.services.openclaw-dashboard-autologin = {
    description = "Generate local OpenClaw dashboard autologin page";
    wantedBy = [ "multi-user.target" ];
    before = [ "nginx.service" ];
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
    requires = [ "openclaw-dashboard-autologin.service" ];
    after = [ "openclaw-dashboard-autologin.service" ];
  };

  networking.hosts."127.0.0.1" = [ "openclaw" ];

  services.nginx.virtualHosts.openclaw = {
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
}
