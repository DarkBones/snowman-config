{ lib, pkgs, pkgsUnstable, config, ... }:
let cfg = config.roles.gaming-mods;
in {
  options.roles.gaming-mods.enable =
    lib.mkEnableOption "Gaming mods role";

  config = lib.mkIf (cfg.enable && pkgs.stdenv.isLinux) {
    home.packages = with pkgsUnstable; [ heroic ];
  };
}
