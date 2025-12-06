{ lib, ... }:
let
  here = ./.;
  entries = builtins.readDir here;

  nixFiles = lib.filterAttrs (name: type:
    type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix")
    entries;

  modules = map (name: here + "/${name}") (lib.attrNames nixFiles);
in { imports = modules; }
