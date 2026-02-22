{ lib, pkgsUnstable, config, inputs, hostRoles ? [ ], ... }:
let
  hasDesktopHost = hostRoles == null || lib.elem "desktop" hostRoles;
  cfg = config.roles.desktop;

  system = builtins.currentSystem or "";
  isLinux = lib.hasInfix "linux" system;
  isDarwin = lib.hasInfix "darwin" system;

  commonPkgs = with pkgsUnstable; [ spotify ];
  linuxPkgs = with pkgsUnstable; [ ghostty gnome-calculator inkscape playerctl vlc ];
  darwinPkgs = with pkgsUnstable; [ wezterm ];
in {
  options.roles.desktop.enable = lib.mkEnableOption "Desktop role";

  imports = lib.optionals (hasDesktopHost && isLinux) [
    inputs.zen-browser.homeModules.twilight
    ({ lib, config, ... }: {
      config = lib.mkIf (config.roles.desktop.enable or false) {
        programs.zen-browser.enable = true;
      };
    })
  ];

  config = lib.mkIf (hasDesktopHost && cfg.enable) {
    home.packages = commonPkgs ++ lib.optionals isLinux linuxPkgs
      ++ lib.optionals isDarwin darwinPkgs;
  };
}
