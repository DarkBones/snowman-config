{ lib, pkgsUnstable, pkgs, config, ... }:
let cfg = config.roles.gaming;
in {
  options.roles.gaming.enable = lib.mkEnableOption "Gaming (home)";

  config = lib.mkIf (cfg.enable && pkgs.stdenv.isLinux) {
    home.packages = with pkgsUnstable; [
      mangohud
      lutris
      protontricks
      vulkan-tools
      mesa-demos
      dualsensectl
      piper
      openrgb
    ];
  };
}
