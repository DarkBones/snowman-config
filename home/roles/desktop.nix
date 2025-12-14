{ lib, pkgs, pkgsUnstable, config, ... }:
let cfg = config.roles.desktop;
in {
  options.roles.desktop.enable = lib.mkEnableOption "Desktop role";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgsUnstable; [ ghostty spotify zen ];
  };
}
