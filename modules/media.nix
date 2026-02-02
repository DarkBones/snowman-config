{ pkgs, lib, ... }:
let
  sabConfig = pkgs.writeText "sabnzbd.ini" ''
    [misc]
    host = 127.0.0.1
    port = 8091
    log_dir = /var/lib/sabnzbd/logs

    # TOFIX: Dis don't work
    host_whitelist = nzb,localhost,127.0.0.1
  '';
in {
  users.groups.media = { };

  users.users.bas.extraGroups = [ "media" ];
  users.users.sonarr.extraGroups = [ "media" ];
  users.users.radarr.extraGroups = [ "media" ];

  users.users.sabnzbd.extraGroups = [ "media" ];

  systemd.tmpfiles.rules = [
    "z /srv/media 2775 bas media -"
    "z /srv/media/Series 2775 bas media -"
    "z /srv/media/Movies 2775 bas media -"

    "d /var/lib/sabnzbd 0750 sabnzbd sabnzbd -"
    "d /var/lib/sabnzbd/logs 0750 sabnzbd sabnzbd -"

    "C /var/lib/sabnzbd/sabnzbd.ini 0640 sabnzbd sabnzbd - ${sabConfig}"

    "d /srv/downloads 2775 sabnzbd media -"
    "d /srv/downloads/incomplete 2775 sabnzbd media -"
    "d /srv/downloads/complete 2775 sabnzbd media -"
  ];

  system.activationScripts.sabnzbdConfig = lib.stringAfter [ "var" ] ''
    install -m 0640 -o sabnzbd -g sabnzbd ${sabConfig} /var/lib/sabnzbd/sabnzbd.ini
  '';

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

    sabnzbd = {
      enable = true;
      openFirewall = false;
      configFile = "/var/lib/sabnzbd/sabnzbd.ini";
    };

    prowlarr = {
      enable = true;
      openFirewall = false;
    };
  };
}
