{ lib, ... }: {
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "plexmediaserver" ];

  services.plex = {
    enable = true;
    openFirewall = false;
    dataDir = "/var/lib/plex";
  };

  users.users.plex.extraGroups = [ "media" ];

  systemd.tmpfiles.rules = [
    "z /srv/media 2775 bas media - -"
    "z /srv/media/Movies 2775 bas media - -"
    "z /srv/media/Series 2775 bas media - -"
  ];
}
