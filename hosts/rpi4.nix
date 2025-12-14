{ pkgs, lib, ... }: {
  imports = [ ./rpi4-hardware-configuration.nix ../modules/home-assistant.nix ];

  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
    kernelParams = [ "ipv6.disable=1" ];
  };

  time.timeZone = "Europe/Berlin";

  networking = {
    enableIPv6 = false;

    nameservers = [ "1.1.1.1" "8.8.8.8" ]; # TODO: Quad 9

    firewall = {
      enable = true;
      allowPing = true;

      # LAN access: SSH + Home Assistant
      allowedTCPPorts = [ 22 8123 ];

      # LAN discovery
      allowedUDPPorts = [ 5353 ];

      checkReversePath = "loose";

      # Trust LAN + Tailscale interfaces
      trustedInterfaces = [ "wlan0" "tailscale0" ];
    };
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
}
