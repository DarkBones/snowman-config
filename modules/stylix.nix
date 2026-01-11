{ pkgs, lib, ... }: {
  stylix = {
    enable = true;
    polarity = "dark";

    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";

    fonts = {
      serif = {
        name = "Crimson Pro";
        package = pkgs.crimson-pro;
      };
      sansSerif = {
        name = "Inter";
        package = pkgs.inter;
      };
      monospace = {
        name = "JetBrainsMono Nerd Font";
        package = pkgs.nerd-fonts.jetbrains-mono;
      };
    };

    cursor = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = lib.mkForce 24;
    };

    targets = {
      gtk.enable = true;
      qt.enable = true;
    };

    icons = {
      enable = true;
      package = pkgs.papirus-icon-theme;
      dark = "Papirus-Dark";
      # light = "Papirus-Light"; # optional
    };
  };
}
