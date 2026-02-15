{ pkgs, pkgsUnstable }:
let
  codeiumTools = with pkgs;
    [ curl gzip coreutils ]
    ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ util-linux ];
in
pkgs.symlinkJoin {
  name = "neovim";
  paths = [ pkgsUnstable.neovim ];
  buildInputs = [ pkgs.makeWrapper ];

  postBuild = ''
    wrapProgram "$out/bin/nvim" \
      --prefix PATH : ${
        pkgs.lib.makeBinPath
        (codeiumTools ++ [ pkgs.python3 pkgsUnstable.nodejs_24 pkgs.unzip ])
      }
  '';
}
