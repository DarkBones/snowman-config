{ lib, config, pkgs, ... }:
let cfg = config.roles.papershift;
in {
  options.roles.papershift.enable = lib.mkEnableOption "Papershift role";

  config = lib.mkIf cfg.enable { home.packages = with pkgs; [ ruby ]; };
}
