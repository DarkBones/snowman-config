{ pkgs, pkgsUnstable, ... }: {
  programs.neovim = {
    enable = true;

    package = pkgsUnstable.neovim;

    withPython3 = true;
    withNodeJs = true;

    extraPackages = with pkgs; [ unzip ];
  };
}
