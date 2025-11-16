{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ ./vm-snowman-test-2-hardware-configuration.nix ];

  boot.loader.grub = {
    enable = true;
    devices = [ "/dev/vda" ];
    useOSProber = false;
  };

  networking.hostName = "debug-minimal";
  networking.useDHCP = true;

  # fresh debug user
  users.users.debug = {
    isNormalUser = true;
    initialPassword = "debug";
    extraGroups = [ "wheel" ]; # so you can sudo
  };

  services.openssh.enable = true;

  system.stateVersion = "25.05";
}
