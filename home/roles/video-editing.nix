{
  lib,
  pkgsUnstable,
  config,
  hostRoles ? [ ],
  ...
}:
let
  hasVideoEditingHost = hostRoles == null || lib.elem "video-editing" hostRoles;
  cfg = config.roles."video-editing";
  localZipPath = cfg.davinciResolve.localZipPath;
  hasDavinciSource = builtins.pathExists localZipPath;
  davinciResolve =
    if hasDavinciSource then
      pkgsUnstable.callPackage ../../pkgs/davinci-resolve-local.nix {
        inherit (cfg.davinciResolve) version;
        inherit localZipPath;
      }
    else
      null;
in
{
  options.roles."video-editing" = {
    enable = lib.mkEnableOption "Video editing role";

    davinciResolve = {
      version = lib.mkOption {
        type = lib.types.str;
        default = "20.3.2";
        description = "DaVinci Resolve version encoded into the Linux installer filename.";
      };

      localZipPath = lib.mkOption {
        type = lib.types.str;
        default = "/home/bas/.local/share/installers/DaVinci_Resolve_20.3.2_Linux.zip";
        example = "/home/bas/.local/share/installers/DaVinci_Resolve_20.3.2_Linux.zip";
        description = "Absolute path to the official DaVinci Resolve Linux zip on the local machine.";
      };
    };
  };

  config = lib.mkIf (hasVideoEditingHost && cfg.enable) {
    warnings = lib.optional (!hasDavinciSource) ''
      bas profile: video-editing role enabled, but DaVinci Resolve installer zip was not found at:
        ${localZipPath}

      To enable DaVinci Resolve on this machine, download:
        DaVinci_Resolve_${cfg.davinciResolve.version}_Linux.zip

      And place it at:
        ${localZipPath}

      The rest of the role remains enabled; DaVinci Resolve is being skipped for this rebuild.
    '';

    home.packages = lib.optional hasDavinciSource davinciResolve;
  };
}
