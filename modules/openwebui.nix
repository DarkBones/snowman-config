{ ... }:
{
  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 4080;
    environment = {
      HOME = "/var/lib/open-webui";
      NLTK_DATA = "/var/lib/open-webui/nltk_data";
    };
  };

  networking.hosts."127.0.0.1" = [ "ai" ];

  services.nginx.virtualHosts.ai = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:4080";
      proxyWebsockets = true;
    };
  };
}
