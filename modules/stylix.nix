{ lib, pkgs, ... }: {
  stylix = {
    enable = true;
    polarity = "dark";

    image = ../assets/patterns/grain.png;

    # Stylix GTK target generates a "Stylix" theme (incl gnome-shell assets) and can
    # trigger HM trying to install gnome-shell.css outside $HOME in the setup.
    # GTK is managed via Home Manager, so Stylix must not manage GTK/GNOME here.
    targets = {
      gtk.enable = lib.mkForce false;
      qt.enable = true;
      gnome.enable = lib.mkForce false;
    };

    fonts.sizes = {
      applications = 12;
      desktop = 12;
      popups = 10;
      terminal = 13;
    };
  };
}
