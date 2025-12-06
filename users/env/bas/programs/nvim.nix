{ pkgs, pkgsUnstable, ... }:
let
  neovimWithDeps = pkgs.symlinkJoin {
    name = "neovim-bas";
    paths = [ pkgsUnstable.neovim ];
    buildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      # Make sure our nvim sees Mason deps in PATH
      wrapProgram $out/bin/nvim \
        --prefix PATH : ${
          pkgs.lib.makeBinPath [
            pkgs.python3
            pkgs.nodejs_22
            pkgs.unzip
          ]
        }
    '';
  };
in {
  home.packages = [
    neovimWithDeps
  ];
}
