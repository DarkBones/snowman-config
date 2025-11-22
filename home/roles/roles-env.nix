{ lib, config, ... }:
let
  allRoles = config.roles or { };

  # Keep roles where:
  # - enable = true, if `enable` exists
  # - otherwise assume disabled (for roles without an explicit toggle)
  enabledRoles = lib.attrNames (lib.filterAttrs
    (_: roleCfg: if roleCfg ? enable then roleCfg.enable else false) allRoles);
in {
  # Export as space-separated list for consumption
  home.sessionVariables.ROLES = lib.concatStringsSep " " enabledRoles;
}
