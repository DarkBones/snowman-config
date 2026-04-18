{ lib, ... }:
let
  here = ./.;
  entries = builtins.readDir here;

  nixFiles = builtins.filter (
    name: entries.${name} == "regular" && lib.hasSuffix ".nix" name && name != "default.nix"
  ) (builtins.attrNames entries);

  modules = map (name: here + "/${name}") (lib.sort (a: b: a < b) nixFiles);
in
{
  imports = modules;
}
