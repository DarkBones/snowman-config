{ ... }: {
  services.audiobookshelf = {
    enable = true;
    openFirewall = false;

    host = "127.0.0.1";
    port = 13378;

    dataDir = "var/lib/audiobookshelf";
  };

  users.users.audiobookshelf.extraGroups = [ "media" ];

  systemd.tmpfiles.rules = [ "z /srv/media/Audiobooks 2775 bas media - -" ];
}
