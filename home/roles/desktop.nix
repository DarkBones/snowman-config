{ lib, pkgsUnstable, config, inputs, ... }:
let cfg = config.roles.desktop;
in {
  options.roles.desktop.enable = lib.mkEnableOption "Desktop role";

  imports = [ inputs.zen-browser.homeModules.twilight ];

  config = lib.mkIf cfg.enable {
    programs.zen-browser.enable = true;

    home = { packages = with pkgsUnstable; [ ghostty spotify playerctl ]; };
  };
}
