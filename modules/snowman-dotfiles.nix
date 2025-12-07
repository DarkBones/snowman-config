# template/modules/snowman-dotfiles.nix
{ pkgs, currentHost, ... }: {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "snowman-dotfiles" ''
      set -euo pipefail

      show_help() {
        echo "Usage: snowman-dotfiles [dev|prod]"
        echo ""
        echo "  dev   - Enable dev mode (mutable symlinks managed by HM)"
        echo "  prod  - Enable prod mode (immutable store links managed by HM)"
        exit 0
      }

      if [ "$#" -eq 0 ]; then show_help; fi

      MODE="$1"

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
          show_help
          ;;
      esac

      echo "➜ Rebuilding NixOS for host ${currentHost}..."

      if [ "$MODE" = "dev" ]; then
        # Dev needs --impure to read the env var
        sudo -E nixos-rebuild switch --impure --flake ".#${currentHost}"
      else
        # Prod is pure
        sudo nixos-rebuild switch --flake ".#${currentHost}"
      fi
    '')
  ];
}
