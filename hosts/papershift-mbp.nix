{ pkgs, lib, ... }:
let papershiftRoot = "/Users/bas/Developer/papershift";
in {
  home-manager.users.bas = {
    home.packages = [
      (pkgs.writeShellScriptBin "pulse-shell" ''
        cd "${papershiftRoot}/pulse"
        exec ${pkgs.bashInteractive}/bin/bash
      '')
      (pkgs.writeShellScriptBin "core-shell" ''
        cd "${papershiftRoot}/core"
        exec ${pkgs.bashInteractive}/bin/bash
      '')
    ];
  };
}
