{ lib, pkgsUnstable, config, inputs, pkgs, hostRoles ? [ ], ... }:
let
  hasDesktopHost = hostRoles == null || lib.elem "desktop" hostRoles;
  cfg = config.roles.desktop;

  commonPkgs = with pkgsUnstable; [ ghostty spotify vlc ];

  linuxPkgs = with pkgsUnstable; [ gnome-calculator inkscape playerctl ];

  darwinPkgs = with pkgsUnstable; [ wezterm ];
in {
  options.roles.desktop.enable = lib.mkEnableOption "Desktop role";

  imports = lib.optionals (hasDesktopHost && pkgs.stdenv.isLinux) [
    inputs.zen-browser.homeModules.twilight
    ({ lib, config, ... }: {
      config = lib.mkIf (config.roles.desktop.enable or false) {
        programs.zen-browser.enable = true;
      };
    })
  ];

  config = lib.mkIf (hasDesktopHost && cfg.enable) {
    home.packages = commonPkgs ++ lib.optionals pkgs.stdenv.isLinux linuxPkgs
      ++ lib.optionals pkgs.stdenv.isDarwin darwinPkgs;
  };
}
