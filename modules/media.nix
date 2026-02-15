{ pkgs, lib, config, ... }:
let
  sabSeedConfig = pkgs.writeText "sabnzbd.ini" ''
    __encoding__ = utf-8
    __version__ = 19
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

  moveCompleted = name: src: dst: {
    description = "Move SAB completed ${name} into media library";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      set -euo pipefail

      SRC="${src}"
      DST="${dst}"

      [ -d "$SRC" ] || exit 0
      mkdir -p "$DST"

      shopt -s nullglob

      for item in "$SRC"/*; do
        base="$(basename "$item")"

        # Skip if destination already exists (idempotent, safe)
        if [ -e "$DST/$base" ]; then
          echo "[media-move:${name}] skip existing: $base"
          continue
        fi

        echo "[media-move:${name}] move: $base"
        mv "$item" "$DST/"

        # Normalize ownership + perms to match your shared-media model
        chown -R bas:media "$DST/$base" || true

        # Ensure directories are setgid so group=media inherits
        if [ -d "$DST/$base" ]; then
          find "$DST/$base" -type d -exec chmod 2775 {} + || true
          find "$DST/$base" -type f -exec chmod 664 {} + || true
        fi
      done
    '';
  };
in {
  users.groups.media = { };

  users.users.bas.extraGroups = [ "media" ];
  users.users.sonarr.extraGroups = [ "media" ];
  users.users.radarr.extraGroups = [ "media" ];
  users.users.sabnzbd.extraGroups = [ "media" ];

  # Base directories
  systemd.tmpfiles.rules = [
    # media library
    "z /srv/media 2775 bas media -"
    "z /srv/media/Series 2775 bas media -"
    "z /srv/media/Movies 2775 bas media -"

    # sab state/logs
    "d /var/lib/sabnzbd 0750 sabnzbd media -"
    "d /var/lib/sabnzbd/logs 0750 sabnzbd media -"

    # seed config ONCE if missing
    "C /var/lib/sabnzbd/sabnzbd.ini 0640 sabnzbd media - ${sabSeedConfig}"

    # downloads
    "z /srv/downloads 2775 sabnzbd media -"
    "z /srv/downloads/incomplete 2775 sabnzbd media -"
    "z /srv/downloads/complete 2775 sabnzbd media -"
  ];

  services.sabnzbd = {
    enable = true;
    openFirewall = false;
    configFile = "/var/lib/sabnzbd/sabnzbd.ini";
    user = "sabnzbd";
    group = "media";
  };

  # Make systemd default umask sane (even if SAB tries something weird)
  systemd.services.sabnzbd.serviceConfig = {
    UMask = "0002";
    SupplementaryGroups = [ "media" ];
  };

  # One-shot permission repair service
  systemd.services.sabnzbd-fixperms = {
    description = "Repair SABnzbd download permissions for Sonarr/Radarr";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      set -euo pipefail

      # Ownership
      chown -R sabnzbd:media /srv/downloads

      # rwX for user+group, nothing for others
      chmod -R u+rwX,g+rwX,o-rwx /srv/downloads

      # Ensure setgid on directories so new files inherit group=media
      find /srv/downloads -type d -exec chmod 2775 {} +
    '';
  };

  systemd.services.media-acl = {
    description = "Set default ACLs on /srv/media and /srv/downloads";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      set -euo pipefail

      # Directories: allow traversal + read; files: allow read
      ${pkgs.acl}/bin/setfacl -R -m g:media:rwx /srv/media /srv/downloads
      ${pkgs.acl}/bin/setfacl -R -d -m g:media:rwx /srv/media /srv/downloads

      # make sure "other" stays locked down
      ${pkgs.acl}/bin/setfacl -R -m o::--- /srv/downloads || true
    '';
  };

  # --- Move completed Audiobooks into /srv/media/Audiobooks ---
  systemd.services.media-move-audiobooks =
    moveCompleted "audiobooks" "/srv/downloads/complete/audiobooks"
    "/srv/media/Audiobooks";

  systemd.paths.media-move-audiobooks = {
    description = "Watch SAB completed audiobooks folder";
    wantedBy = [ "multi-user.target" ];
    pathConfig = { PathChanged = "/srv/downloads/complete/audiobooks"; };
  };
  systemd.paths.media-move-audiobooks.unitConfig.Unit =
    "media-move-audiobooks.service";

  # --- Move completed Ebooks into /srv/media/Ebooks ---
  systemd.services.media-move-ebooks =
    moveCompleted "ebooks" "/srv/downloads/complete/ebooks" "/srv/media/Ebooks";

  systemd.paths.media-move-ebooks = {
    description = "Watch SAB completed ebooks folder";
    wantedBy = [ "multi-user.target" ];
    pathConfig = { PathChanged = "/srv/downloads/complete/ebooks"; };
  };
  systemd.paths.media-move-ebooks.unitConfig.Unit = "media-move-ebooks.service";

  # Trigger the fixer whenever SAB writes into these dirs
  systemd.paths.sabnzbd-fixperms = {
    description = "Watch SABnzbd folders and trigger permission repair";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = [ "/srv/downloads/incomplete" "/srv/downloads/complete" ];
    };
  };

  # Associate the path unit with the service it should start
  systemd.paths.sabnzbd-fixperms.unitConfig.Unit = "sabnzbd-fixperms.service";

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

  assertions = [
    {
      assertion = config.services.sabnzbd.user == "sabnzbd";
      message = "SAB must run as user sabnzbd (permission model assumes this).";
    }
    {
      assertion = config.services.sabnzbd.group == "media";
      message = "SAB must run with group=media (shared access).";
    }
  ];
}
