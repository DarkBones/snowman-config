{ pkgs, lib, ... }: {
  time.timeZone = "Europe/Berlin";
  hardware = {
    # boot.firmware = "efi";
    # bootDevice = "/dev/nvme0n1";
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
}
