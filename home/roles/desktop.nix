{ lib, pkgsUnstable, config, inputs, hostRoles ? [ ], ... }:
let hasDesktopHost = hostRoles == null || lib.elem "desktop" hostRoles;
in {
  options.roles.desktop.enable = lib.mkEnableOption "Desktop role";

  imports = lib.optionals hasDesktopHost [
    inputs.zen-browser.homeModules.twilight
    ({ lib, config, ... }: {
      config = lib.mkIf (config.roles.desktop.enable or false) {
        programs.zen-browser.enable = true;
      };
    })
  ];

  config = lib.mkIf (hasDesktopHost && (config.roles.desktop.enable or false)) {
    home.packages = with pkgsUnstable; [ ghostty playerctl spotify ];

    # If you manage Hyprland config via Home Manager, add an exec-once:
    wayland.windowManager.hyprland.settings.exec-once = [
      "${pkgsUnstable.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
    ];
  };
}
