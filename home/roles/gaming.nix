{ lib, pkgsUnstable, config, ... }:
let cfg = config.roles.gaming;
in {
  options.roles.gaming.enable = lib.mkEnableOption "Gaming (home)";

  config = lib.mkIf cfg.enable {
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
