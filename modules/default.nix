{ lib, pkgs, pkgsUnstable, dotfilesSources, inv, currentHost, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;

  here = ./.;
  entries = builtins.readDir here;

  nixFiles = builtins.filter (name:
    entries.${name} == "regular" && lib.hasSuffix ".nix" name && name
    != "default.nix") (builtins.attrNames entries);

  moduleFiles = map (name: here + "/${name}") nixFiles;

in {
  imports = [ ./hardware ./home/from-inventory.nix ./users ] ++ moduleFiles;

  config = lib.mkIf hasHost {
    home-manager.extraSpecialArgs = { inherit pkgsUnstable dotfilesSources; };

    environment.systemPackages = (with pkgs; [ git age home-manager ])
      ++ [ pkgsUnstable.ssh-to-age ];
  };
}
