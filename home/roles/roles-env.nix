{ lib, config, ... }:
let
  allRoles = config.roles or { };

  # A role is enabled if it's an attrset with enable=true, or if it's explicitly enabled in the config.
  isEnabled = name: value: if builtins.isAttrs value then (value.enable or false) == true else false;

  enabledRoles = lib.attrNames (lib.filterAttrs isEnabled allRoles);
in
{
  # Export as space-separated list for consumption later
  home.sessionVariables.ROLES = lib.concatStringsSep " " enabledRoles;
}
