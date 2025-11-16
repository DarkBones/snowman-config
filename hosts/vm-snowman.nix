{ ... }: {
  imports = [ ./vm-snowman-hardware-configuration.nix ];

  # boot.loader.grub = {
  #   enable = true;
  #   devices = [ "/dev/vda" ];
  #   useOSProber = false;
  # };
}
