{ pkgs, lib, ... }: {
  services.home-assistant = {
    enable = true;
    openFirewall = true;
    configDir = "/var/lib/home-assistant";

    extraPackages = python3Packages:
      with python3Packages; [
        aiohue
        pychromecast
      ];

    config = { default_config = { }; };
  };
}
