{ pkgs, lib, ... }: {
  services.home-assistant = {
    enable = true;
    openFirewall = true;
    configDir = "/var/lib/home-assistant";

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

        # for BLE integrations (if these attrs exist; if Nix complains,
        # you can comment them out and HA will just skip those integrations)
        govee_ble
        ibeacon_ble
      ];

    config = { default_config = { }; };
  };
}
