{ pkgs, lib, ... }: {
  imports = [ ./rpi4-hardware-configuration.nix ];

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedTCPPorts = [ 22 ];
    checkReversePath = "loose";
    trustedInterfaces = [ "wlan0" ];
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
}
