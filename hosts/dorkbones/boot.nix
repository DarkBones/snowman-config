{ lib, pkgs, dotfilesSources, ... }:

let
  mode = builtins.getEnv "SNOWMAN_DOTFILES_MODE";
  isDev = mode == "dev";

  # DEV = your mutable checkout
  devDot = /home/bas/Developer/dotfiles;

  # PROD = pinned store input
  prodDot = dotfilesSources.bas;

  dot = if isDev then devDot else prodDot;

  themeSrc = "${dot}/grub/cyberre";

  cyberreTheme = pkgs.runCommand "grub-theme-cyberre" { } ''
    set -euo pipefail

    if [ ! -d "${themeSrc}" ]; then
      echo "ERROR: GRUB theme directory not found: ${themeSrc}" >&2
      echo "Dot source is: ${dot}" >&2
      ls -la "${dot}" >&2 || true
      exit 1
    fi

    mkdir -p "$out"
    cp -R --no-preserve=mode,ownership,timestamps \
      "${themeSrc}/." "$out/"

    # VFAT can't represent symlinks
    find "$out" -type l -delete

    test -f "$out/theme.txt"
  '';
in {
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    efiInstallAsRemovable = true;
    useOSProber = false;
    configurationLimit = 20;

    theme = lib.mkForce cyberreTheme;
  };

  boot.loader.efi = {
    canTouchEfiVariables = lib.mkForce false;
    efiSysMountPoint = "/boot";
  };
}
