{
  lib,
  pkgs,
  pkgsUnstable,
  config,
  ...
}:
let
  cfg = config.roles.alvr;
  alvrPkg = pkgs.callPackage ../pkgs/alvr-20.13.0.nix { };
in
{
  options.roles.alvr.enable = lib.mkEnableOption "ALVR VR streaming";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ alvrPkg ];

    # ADB for Quest connection (includes udev rules)
    programs.adb.enable = true;

    # ALVR firewall ports (TCP/UDP 9943 for control, 9944 for streaming)
    networking.firewall = {
      allowedTCPPorts = [
        9943
        9944
      ];
      allowedUDPPorts = [
        9943
        9944
      ];
    };

    # udev rules for Quest USB access
    services.udev.extraRules = ''
      # Meta Quest 3 / Quest 2
      SUBSYSTEM=="usb", ATTR{idVendor}=="2833", MODE="0666", GROUP="users"
    '';

  };
}
