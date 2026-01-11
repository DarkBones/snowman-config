{ pkgs, lib, ... }: {
  stylix = {
    enable = true;
    polarity = "dark";

    base16Scheme = {
      scheme = "Darkling";
      author = "DarkBones";
      base00 = "0d0d16";
      base01 = "11111b";
      base02 = "1e1e2e";
      base03 = "45475a";
      base04 = "585b70";
      base05 = "f5e0dc";
      base06 = "cdd6f4";
      base07 = "ffffff";
      base08 = "f38ba8";
      base09 = "fab387";
      base0A = "b38b4d";
      base0B = "a6e3a1";
      base0C = "89b4fa";
      base0D = "cba6f7";
      base0E = "f9e2af";
      base0F = "94e2d5";
    };

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
      size = 24;
    };

    targets = {
      gtk.enable = false;
      qt.enable = true;
    };

    icons = {
      enable = true;
      package = pkgs.papirus-icon-theme;
      dark = "Papirus-Dark";
    };
  };
}
