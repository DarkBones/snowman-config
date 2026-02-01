{ lib, config, pkgsUnstable, ... }:
let enabled = (config.roles.hyprland.enable or false);
in {
  config = lib.mkIf enabled { home.packages = [ pkgsUnstable.wayscriber ]; };
}
