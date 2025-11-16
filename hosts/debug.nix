{ config, lib, pkgs, modulesPath, ... }:

{
  # Use the same hardware as vm-snowman-test-2
  imports = [ ./vm-snowman-test-2-hardware-configuration.nix ];

  # Simple, explicit GRUB setup on /dev/vda
  boot.loader.grub = {
    enable = true;
    devices = [ "/dev/vda" ];
    useOSProber = false;
  };

  # Minimal networking so you can reach it
  networking.hostName = "debug-minimal";
  networking.useDHCP = true;

  # Root login just to keep it simple for the test
  users.users.root.initialPassword = "root";

  services.openssh.enable = true;

  # Whatever your release is
  system.stateVersion = "25.05";
}
