{ pkgs, lib, config, ... }:
let
  homeDir =
    config.home-manager.users.bas.home.homeDirectory or (if pkgs.stdenv.isDarwin then
      "/Users/bas"
    else
      "/home/bas");

  papershiftRoot = "${homeDir}/Developer/papershift";
in {
  home-manager.users.bas.home.packages = [
    (pkgs.writeShellScriptBin "pulse-shell" ''
      cd "${papershiftRoot}/pulse"
      exec ${pkgs.bashInteractive}/bin/bash
    '')
    (pkgs.writeShellScriptBin "core-shell" ''
      cd "${papershiftRoot}/core"
      exec ${pkgs.bashInteractive}/bin/bash
    '')
  ];
}
