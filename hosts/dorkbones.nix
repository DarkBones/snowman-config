{ pkgs, lib, ... }: {
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  boot.initrd.systemd.enable = true;
  hardware = {
    # bootDevice = "/dev/nvme0n1";
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
}
