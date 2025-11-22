{ lib, pkgsUnstable, ... }:
let
  here = ./.;
  entries = builtins.readDir here;

  nixFiles = builtins.filter (name:
    entries.${name} == "regular" && lib.hasSuffix ".nix" name && name
    != "default.nix") (builtins.attrNames entries);

  modules = map (name: here + "/${name}") nixFiles;
in {
  imports = modules;
  config.home.packages = with pkgsUnstable; [ neofetch starship eza bat ];
}
