{ ... }: {
  imports = [ ./vm-snowman-hardware-test-configuration.nix ];

  boot.loader.grub = {
    enable = true;
    devices = [ "/dev/vda" ];
    useOSProber = false;
  };
}
