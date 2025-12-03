{ pkgs, lib, ... }: {
  services.home-assistant = {
    enable = true;
    openFirewall = true;
    configDir = "/var/lib/home-assistant";

    extraPackages = python3Packages: [
      python3Packages.aiohue
      python3Packages.pychromecast
      python3Packages.python-roborock
      python3Packages.vacuum-map-parser-roborock

      # for thread / otbr
      python3Packages.python-otbr-api

      # for google_translate TTS
      python3Packages.gtts

      # for Fritz!/UPnP/etc
      python3Packages.fritzconnection
      python3Packages.pyfritzhome
      python3Packages.getmac
      python3Packages.pyipp

      # for BLE integrations
      python3Packages."govee-ble"
      python3Packages."ibeacon-ble"
      python3Packages."kegtron-ble"
    ];

    config = {
      default_config = { };
      automation = "!include automations.yaml";
    };
  };
}
