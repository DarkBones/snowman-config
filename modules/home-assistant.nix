{ pkgs, lib, ... }: {
  services.home-assistant = {
    enable = true;

    package = pkgs.home-assistant;
    configDir = "/var/lib/home-assistant";
    openFirewall = true;
  };

  # Later, we probably need:
  # services.udev.extraRules = '' ... '';
  #
  # And maybe persistent storage tweaks (separate disk, etc.)
}
