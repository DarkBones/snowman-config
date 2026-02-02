{ ... }: {
  users.groups.media = { };

  users.users.bas.extraGroups = [ "media" ];
  users.users.sonarr.extraGroups = [ "media" ];
  users.users.radarr.extraGroups = [ "media" ];

  systemd.tmpfiles.rules = [
    "d /srv/media 2775 bas media -"
    "d /srv/media/Series 2775 bas media -"
    "d /srv/media/Movies 2775 bas media -"

    "z /srv/media 2775 bas media -"
    "z /srv/media/Series 2775 bas media -"
    "z /srv/media/Movies 2775 bas media -"
  ];

  services = {
    radarr = {
      enable = true;
      openFirewall = false;
      dataDir = "/var/lib/radarr";
    };
    sonarr = {
      enable = true;
      openFirewall = false;
      dataDir = "/var/lib/sonarr";
    };
  };
}
