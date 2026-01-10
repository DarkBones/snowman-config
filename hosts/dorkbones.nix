{ pkgs, lib, ... }:
let
  polkitAgent =
    "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
in {
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  boot.initrd.systemd.enable = true;

  environment = {
    variables = {
      XCURSOR_THEME = "Bibata-Modern-Classic";
      XCURSOR_SIZE = "24";
    };
    systemPackages = with pkgs; [ gparted bibata-cursors ];
  };

  security.polkit.enable = true;

  systemd.user.services.polkit-gnome-agent = {
    description = "Polkit GNOME Authentication Agent";
    wantedBy = [ "default.target" ];
    after = [ "graphical-session-pre.target" "dbus.service" ];
    serviceConfig = {
      ExecStart = polkitAgent;
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  home-manager.users.bas.imports = [ ../home/roles ../home/overrides ];

  networking = {
    enableIPv6 = false;

    nameservers = [ "1.1.1.1" "8.8.8.8" ]; # TODO: Quad 9

    firewall = {
      enable = true;
      allowPing = true;

      # LAN access: SSH
      allowedTCPPorts = [ 22 ];

      # LAN discovery
      allowedUDPPorts = [ 5353 ];

      checkReversePath = "loose";

      # Trust LAN + Tailscale interfaces
      trustedInterfaces = [ "wlan0" "tailscale0" ];
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services = {
    tailscale = {
      enable = true;
      openFirewall = true;
    };

    pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
      wireplumber.enable = true;
    };

    blueman.enable = true;

    displayManager.sddm = {
      enable = true;
      theme = "breeze";
    };
  };
}
