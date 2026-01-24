{ lib, pkgs, ... }: {
  # Kill SDDM
  services.displayManager.sddm.enable = lib.mkForce false;

  # Make sure we aren't autologging in via getty anymore
  services.getty.autologinUser = lib.mkForce null;

  # Wayland login manager
  services.greetd = {
    enable = true;

    # greetd defaults to vt1, but being explicit makes debugging easier
    vt = 1;

    settings = {
      initial_session = {
        command = "${pkgs.hyprland}/bin/Hyprland";
        user = "bas";
      };

      default_session = {
        command = "${pkgs.greetd.regreet}/bin/regreet";
        user = "greeter";
      };
    };
  };

  environment.systemPackages = [ pkgs.greetd.regreet ];
  programs.hyprland.enable = true;

  boot.kernelParams = [ "quiet" "loglevel=3" ];
}
