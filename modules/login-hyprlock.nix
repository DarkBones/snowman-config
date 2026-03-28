{ lib, pkgs, ... }: {
  # Kill SDDM
  services.displayManager.sddm.enable = lib.mkForce false;

  # Make sure we aren't autologging in via getty anymore
  services.getty.autologinUser = lib.mkForce null;

  # Wayland login manager
  services.greetd = {
    enable = true;

    settings = {
      initial_session = {
        # Let UWSM own the compositor lifecycle so logging out releases VT1 cleanly.
        command = "${pkgs.uwsm}/bin/uwsm start -F -- /run/current-system/sw/bin/Hyprland";
        user = "bas";
      };

      default_session = {
        # Keep the post-logout path on a plain TTY so exiting Hyprland
        # returns to a shell where startx can be launched manually.
        command =
          "${pkgs.greetd}/bin/agreety --cmd /run/current-system/sw/bin/zsh -l";
        user = "greeter";
      };
    };
  };

  programs.hyprland.enable = true;

  boot.kernelParams = [ "quiet" "loglevel=3" ];
}
