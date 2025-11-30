{ pkgs, lib, ... }: {
  services.home-assistant = {
    enable = true;
    openFirewall = true;
    configDir = "/var/lib/home-assistant";

    defaultIntegrations = [
      "application_credentials"
      "frontend"
      "hardware"
      "logger"
      "network"
      "system_health"
      "automation"
      "person"
      "scene"
      "script"
      "tag"
      "zone"
      "counter"
      "input_boolean"
      "input_button"
      "input_datetime"
      "input_number"
      "input_select"
      "input_text"
      "schedule"
      "timer"
      "backup"
    ];

    extraPackages = python3Packages:
      with python3Packages; [
        aiohue
        pychromecast
        python-roborock
        vacuum-map-parser-roborock

        # for thread / otbr
        python-otbr-api

        # for google_translate TTS
        gtts

        # for Fritz!Box / Fritz integrations
        fritzconnection
        pyfritzhome

        # for UPnP, various discovery things
        getmac
        pyipp

        # for BLE integrations
        govee-ble
        ibeacon-ble
      ];

    config = { default_config = { }; };
  };
}
