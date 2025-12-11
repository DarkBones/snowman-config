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

      # Open HA Dashboard (8123) and SSH (22)
      allowedTCPPorts = [ 22 8123 ];

      # Open mDNS/Cast discovery
      allowedUDPPorts = [ 5353 ];

      checkReversePath = "loose";
      trustedInterfaces = [ "wlan0" ];
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
}
