{ lib, pkgs, ... }: {
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

  services.blueman.enable = true;
}
