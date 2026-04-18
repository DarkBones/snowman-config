{
  lib,
  pkgsUnstable,
  config,
  inputs,
  hostRoles ? [ ],
  ...
}:
let
  hasDesktopHost = hostRoles == null || lib.elem "desktop" hostRoles;
  cfg = config.roles.desktop;
  isLinux = pkgsUnstable.stdenv.isLinux;
  isDarwin = pkgsUnstable.stdenv.isDarwin;

  commonPkgs = with pkgsUnstable; [ spotify ];
  linuxPkgs = with pkgsUnstable; [
    ghostty
    gnome-calculator
    inkscape
    playerctl
    vlc
  ];
  darwinPkgs = with pkgsUnstable; [ wezterm ];
in
{
  options.roles.desktop.enable = lib.mkEnableOption "Desktop role";

  imports = lib.optionals (hasDesktopHost && isLinux) [
    inputs.zen-browser.homeModules.twilight
    (
      { lib, config, ... }:
      {
        config = lib.mkIf (config.roles.desktop.enable or false) {
          programs.zen-browser.enable = true;
        };
      }
    )
  ];

  config = lib.mkIf (hasDesktopHost && cfg.enable) {
    home.packages = commonPkgs ++ lib.optionals isLinux linuxPkgs ++ lib.optionals isDarwin darwinPkgs;

    home.file = lib.mkIf isLinux {
      ".xinitrc".text = ''
        unset DISPLAY
        unset WAYLAND_DISPLAY
        unset SWAYSOCK
        unset HYPRLAND_INSTANCE_SIGNATURE

        export XDG_SESSION_TYPE=x11
        export XDG_CURRENT_DESKTOP=XFCE
        export DESKTOP_SESSION=xfce

        exec dbus-run-session startxfce4
      '';
    };
  };
}
