{ pkgs, lib, ... }: {
  time.timeZone = "Europe/Berlin";
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
}
