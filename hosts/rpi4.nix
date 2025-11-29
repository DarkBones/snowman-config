{ pkgs, lib, ... }:

{
  networking.hostName = "rpi4";
  networking.wireless.enable = true;

  networking.wireless.country = "DE"; # TODO: How do I verify this?

  # Define your Wi-Fi network(s)
  networking.wireless.networks = {
    "YOUR_SSID" = {
      psk = "YOUR_WIFI_PASSWORD"; # TODO: Add secret
    };
  };

  # Make sure DHCP is enabled for Wi-Fi
  networking.interfaces.wlan0.useDHCP = true;

  # Keep Ethernet DHCP too (already default)
  # networking.interfaces.end0.useDHCP = true;  # Pi uses "end0" for eth
}
