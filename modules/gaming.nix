{ lib, pkgs, config, ... }:
let cfg = config.roles.gaming;
in {
  options.roles.gaming.enable = lib.mkEnableOption "Gaming (system)";

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      gamescopeSession.enable = false;
    };

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    environment.systemPackages = with pkgs; [
      gamescope
      lutris
      wineWowPackages.stable
      winetricks
    ];
  };
}
