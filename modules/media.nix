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

    # downloads
    "z /srv/downloads 2775 sabnzbd media -"
    "z /srv/downloads/incomplete 2775 sabnzbd media -"
    "z /srv/downloads/complete 2775 sabnzbd media -"
  ];

  system.activationScripts.fixDownloadPerms = lib.stringAfter [ "var" ] ''
    set -euo pipefail

    # Ensure base dirs are correct
    install -d -m 2775 -o sabnzbd -g media /srv/downloads
    install -d -m 2775 -o sabnzbd -g media /srv/downloads/incomplete
    install -d -m 2775 -o sabnzbd -g media /srv/downloads/complete

    # Repair whatever SAB created earlier with restrictive perms/ownership
    chown -R sabnzbd:media /srv/downloads
    chmod -R u+rwX,g+rwX,o-rwx /srv/downloads
    find /srv/downloads -type d -exec chmod 2775 {} +
  '';

  services.sabnzbd = {
    enable = true;
    openFirewall = false;
    configFile = "/var/lib/sabnzbd/sabnzbd.ini";
    user = "sabnzbd";
    group = "media";
  };

  systemd.services.sabnzbd = {
    serviceConfig = {
      UMask = "0002";
      SupplementaryGroups = [ "media" ];
    };

    preStart = ''
      set -euo pipefail

      # Ensure dirs exist with correct ownership/perms
      install -d -m 0750 -o sabnzbd -g media /var/lib/sabnzbd
      install -d -m 0750 -o sabnzbd -g media /var/lib/sabnzbd/logs

      install -d -m 2775 -o sabnzbd -g media /srv/downloads
      install -d -m 2775 -o sabnzbd -g media /srv/downloads/incomplete
      install -d -m 2775 -o sabnzbd -g media /srv/downloads/complete

      # Always enforce canonical config at startup
      install -m 0640 -o sabnzbd -g media ${sabConfig} /var/lib/sabnzbd/sabnzbd.ini
    '';
  };

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
