{ pkgs, currentHost, ... }:
let
  flakeDir = "/home/bas/snowman-config";
in
{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "snowman-dotfiles" ''
      set -euo pipefail

      MODE=prod
      if [ $# -ge 1 ]; then
        MODE="$1"
      fi

      case "$MODE" in
        dev)
          echo "➜ Enabling dotfiles DEV mode (SNOWMAN_DOTFILES_MODE=dev)"
          export SNOWMAN_DOTFILES_MODE=dev
          ;;
        prod|production)
          echo "➜ Enabling dotfiles PROD mode (unsetting SNOWMAN_DOTFILES_MODE)"
          unset SNOWMAN_DOTFILES_MODE
          ;;
        *)
          echo "Usage: snowman-dotfiles [dev|prod]" >&2
          exit 1
          ;;
      esac

      cd ${flakeDir}

      echo "➜ Rebuilding NixOS for host ${currentHost} in $MODE mode..."
      sudo -E nixos-rebuild switch --impure --flake "${flakeDir}#${currentHost}"
    '')
  ];
}
