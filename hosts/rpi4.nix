{ pkgs, lib, ... }: {
  networking.hostName = "rpi4";

  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedTCPPorts = [ 22 ];

    checkReversePath = "loose";

    trustedInterfaces = [ "wlan0" ];
  };
}
