{ lib, ... }: {
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "plexmediaserver" ];

  services.plex = {
    enable = true;
    openFirewall = false;
    dataDir = "/var/lib/plex";
  };

  users.users.plex.extraGroups = [ "media" ];

  networking.hosts."127.0.0.1" = [ "plex" ];

  services.nginx.virtualHosts.plex = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:32400";
      proxyWebsockets = true;
    };
  };

  systemd.tmpfiles.rules = [
    "z /srv/media 2775 bas media - -"
    "z /srv/media/Movies 2775 bas media - -"
    "z /srv/media/Series 2775 bas media - -"
  ];
}
