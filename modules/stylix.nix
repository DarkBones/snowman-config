{ lib, ... }: {
  stylix = {
    enable = true;
    polarity = "dark";
    image = ../assets/patterns/grain.png;

    targets = {
      gtk.enable = lib.mkForce false;
      qt.enable = true;
      gnome.enable = lib.mkForce false;
      grub.enable = false;
    };
  };
}
