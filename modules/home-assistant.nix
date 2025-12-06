{ pkgs, lib, ... }: {
  services.home-assistant = {
    enable = true;
    configDir = "/var/lib/home-assistant";

    # Python packages
    extraPackages = python3Packages: [
      python3Packages.aiohue
      python3Packages.pychromecast
      python3Packages.python-roborock
      python3Packages.vacuum-map-parser-roborock
      python3Packages.python-otbr-api
      python3Packages.gtts
      python3Packages.fritzconnection
      python3Packages.pyfritzhome
      python3Packages.getmac
      python3Packages.pyipp
      python3Packages."govee-ble"
      python3Packages."ibeacon-ble"
      python3Packages."kegtron-ble"
      python3Packages.google-cloud-pubsub
      python3Packages.google-cloud-speech
      python3Packages.grpcio
      python3Packages.grpcio-tools
      python3Packages."xiaomi-ble"
    ];

    config = {
      default_config = { };

      automation = "!include automations.yaml";
      script = "!include scripts.yaml";
      scene = "!include scenes.yaml";

      http = {
        server_host = [ "0.0.0.0" ];
        server_port = 8123;
      };
    };
  };

  # Systemd override to fix startup race conditions
  systemd.services.home-assistant = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };
}
