{ pkgs, lib, ... }: {
  services.home-assistant = {
    enable = true;
    configDir = "/var/lib/home-assistant";
    openFirewall = true;

    config = {
      default_config = { };

      homeassistant = {
        name = "Home";
        unit_system = "metric";
        time_zone = "Europe/Berlin";
        # latitude/longitude/elevation can be left null; fill later
      };
    };
  };

  # Later: udev rules, extraPackages, etc.
}
