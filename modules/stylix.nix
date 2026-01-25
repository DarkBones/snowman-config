{ lib, ... }: {
  stylix = {
    enable = true;
    autoEnable = false;

    polarity = "dark";
    image = ../assets/patterns/grain.png;

    targets = {
      gtk.enable = lib.mkForce false;
      qt.enable = lib.mkForce false;
      gnome.enable = lib.mkForce false;
      grub.enable = false;
    };
  };
}
