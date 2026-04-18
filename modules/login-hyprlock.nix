{ lib, ... }:
{
  # Kill SDDM
  services.displayManager.sddm.enable = lib.mkForce false;

  # Make sure we aren't autologging in via getty anymore
  services.getty.autologinUser = lib.mkForce null;

  # Keep greetd in greeter-first mode so logout returns to a real login
  # manager and X11 sessions can be launched from a seat-owned greeter.
  services.greetd.enable = true;
  programs.regreet.enable = true;

  # Make Hyprland the default pick while still exposing XFCE as a fallback
  # session in ReGreet when a non-Wayland session is needed.
  services.displayManager.defaultSession = "hyprland-uwsm";

  programs.hyprland.enable = true;

  boot.kernelParams = [
    "quiet"
    "loglevel=3"
  ];
}
