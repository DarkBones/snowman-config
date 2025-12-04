{ pkgs, lib, ... }: {
  imports = [ 
    ./rpi4-hardware-configuration.nix 
    ../modules/home-assistant.nix 
  ];

  boot = {
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
    # Fixes IPv6 socket crashes
    kernelParams = [ "ipv6.disable=1" ];
  };

  # Fixes Google/SSL Token Expiry issues
  time.timeZone = "Europe/Berlin";

  networking = {
    enableIPv6 = false;

    # Fixes "Could not contact DNS servers"
    nameservers = [ "1.1.1.1" "8.8.8.8" ];

    firewall = {
      enable = true;
      allowPing = true;
      
      # Open HA Dashboard (8123) and SSH (22)
      allowedTCPPorts = [ 22 8123 ];
      
      # Open mDNS/Cast discovery
      allowedUDPPorts = [ 5353 ];
      
      checkReversePath = "loose";
      trustedInterfaces = [ "wlan0" ];
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
}
