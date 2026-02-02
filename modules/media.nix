{ pkgs, lib, ... }:
let
  sabConfig = pkgs.writeText "sabnzbd.ini" ''
    [misc]
    host = 127.0.0.1
    port = 8091

    host_whitelist = nzb,localhost,127.0.0.1
    log_dir = /var/lib/sabnzbd/logs

    download_dir = /srv/downloads/incomplete
    complete_dir = /srv/downloads/complete

    umask = 002
    permissions = 664
    folder_permissions = 775
  '';
in {
  users.groups.media = { };

  users.users.bas.extraGroups = [ "media" ];
  users.users.sonarr.extraGroups = [ "media" ];
  users.users.radarr.extraGroups = [ "media" ];
  users.users.sabnzbd.extraGroups = [ "media" ];

  systemd.tmpfiles.rules = [
    # media library
    "z /srv/media 2775 bas media -"
    "z /srv/media/Series 2775 bas media -"
    "z /srv/media/Movies 2775 bas media -"

    # sabnzbd state/logs
    "d /var/lib/sabnzbd 0750 sabnzbd sabnzbd -"
    "d /var/lib/sabnzbd/logs 0750 sabnzbd sabnzbd -"

    # sab config (copied from store, replacing if different)
    "C /var/lib/sabnzbd/sabnzbd.ini 0640 sabnzbd sabnzbd - ${sabConfig}"

    # downloads (NOTE: use z so it also fixes perms on rebuild)
    "z /srv/downloads 2775 sabnzbd media -"
    "z /srv/downloads/incomplete 2775 sabnzbd media -"
    "z /srv/downloads/complete 2775 sabnzbd media -"
  ];

  services.sabnzbd = {
    enable = true;
    openFirewall = false;
    configFile = "/var/lib/sabnzbd/sabnzbd.ini";

    # Key bit: run with the shared group
    group = "media";
    user = "sabnzbd";
  };

  # Key bit: force a sane umask no matter what SAB thinks it wants
  systemd.services.sabnzbd.serviceConfig.UMask = "0002";

  services.sonarr = {
    enable = true;
    openFirewall = false;
    dataDir = "/var/lib/sonarr";
  };
  services.radarr = {
    enable = true;
    openFirewall = false;
    dataDir = "/var/lib/radarr";
  };
  services.prowlarr = {
    enable = true;
    openFirewall = false;
  };
}
