{ lib, pkgs, ... }:
{
  systemd.tmpfiles.rules = [
    "L+ /bin/bash - - - - ${pkgs.bash}/bin/bash"
  ];

  boot.initrd.systemd.enable = true;

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  systemd.oomd.enable = true;

  environment.variables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = lib.mkDefault 24;
  };

  programs.kdeconnect.enable = true;

  security.polkit.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  boot.extraModprobeConfig = ''
    # USB Bluetooth adapters on this desktop have produced stale HCI
    # controllers after sleep/resume when runtime autosuspend is enabled.
    options btusb enable_autosuspend=0
  '';

  services.blueman.enable = true;
}
