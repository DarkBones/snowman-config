{ ... }: {
  services.audiobookshelf = {
    enable = true;
    openFirewall = true;

    host = "0.0.0.0";
    port = 13378;

    dataDir = "var/lib/audiobookshelf";
  };

  users.users.audiobookshelf.extraGroups = [ "media" ];

  networking.hosts."127.0.0.1" = [ "shelf" ];

  services.nginx.virtualHosts.shelf = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:13378";
      proxyWebsockets = true;
    };
  };

  systemd.tmpfiles.rules = [ "z /srv/media/Audiobooks 2775 bas media - -" ];
}
