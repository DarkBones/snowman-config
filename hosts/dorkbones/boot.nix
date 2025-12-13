{ ... }: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  # fileSystems."/boot" = {
  #   device = "/dev/disk/by-partuuid/a1abf22f-30d2-44f6-ab70-142f6951e307";
  #   fsType = "vfat";
  # };
}
