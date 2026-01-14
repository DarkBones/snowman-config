{ pkgs, ... }: {
  stylix = {
    enable = true;
    polarity = "dark";

    # Stylix still requires an image to initialize its internal engine, 
    # even if you override every color manually.
    image = ../assets/patterns/grain.png;

    base16Scheme = {
      # Background Colors
      base00 = "0d0d16"; # Default Background (Deep Navy Noir)
      base01 = "11111b"; # Lighter Background (Used for status bars/sidebars)
      base02 = "1e1e2e"; # Selection Background (Subtle highlight)
      base03 = "45475a"; # Comments, Invisibles, Line Highlighting

      # Text Colors
      base04 = "585b70"; # Dark Foreground (Used for secondary text)
      base05 = "f5e0dc"; # Default Foreground (Off-white/Rosewater text)
      base06 = "cdd6f4"; # Light Foreground (Used for accents)
      base07 = "ffffff"; # Light Positive (Pure white)

      # Accent Colors
      base08 = "f38ba8"; # Variables, XML Tags, Red
      base09 = "fab387"; # Integers, Boolean, Constants, Orange
      base0A = "b38b4d"; # Classes, Search Results, THE DARKING GOLD
      base0B = "a6e3a1"; # Strings, Inherited Class, Green
      base0C = "89b4fa"; # Support, Regular Expressions, Cyan
      base0D = "cba6f7"; # Functions, Methods, Attribute IDs, Lavender/Purple
      base0E = "f9e2af"; # Keywords, Storage, Selector, Yellow
      base0F = "94e2d5"; # Deprecated, Opening/Closing Embedded Tag, Teal
    };

    targets = {
      gtk.enable = true;
      qt.enable = true;
      gnome.enable = false;
    };

    # Scaling back the font size from the 80pt test
    fonts.sizes = {
      applications = 12;
      desktop = 12;
      popups = 10;
      terminal = 13;
    };
  };
}
