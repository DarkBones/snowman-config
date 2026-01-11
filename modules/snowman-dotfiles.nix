{ pkgs, currentHost, ... }:
let
  # Single source of truth:
  # - PROD when env var is absent/anything else
  # - DEV only when SNOWMAN_DOTFILES_MODE=dev is present at eval time
  mode =
    if builtins.getEnv "SNOWMAN_DOTFILES_MODE" == "dev"
    then "dev"
    else "prod";
in
{
  # Make the mode file Nix-owned, so it always matches the currently active system.
  environment.etc."snowman/dotfiles-mode".text = mode + "\n";

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "snowman-dotfiles" ''
      set -euo pipefail

      MODE_FILE="/etc/snowman/dotfiles-mode"

      show_help() {
        echo "Usage: snowman-dotfiles [dev|prod|status]"
        echo ""
        echo "  dev     - Enable dev mode (mutable symlinks managed by HM)"
        echo "  prod    - Enable prod mode (immutable store links managed by HM)"
        echo "  status  - Show declared + effective mode"
        exit 0
      }

      # Best-effort: infer effective mode from a representative link.
      # (We use ~/tmux because it's in your dotfiles set.)
      effective_mode() {
        local target
        target="$(readlink -f "$HOME/tmux" 2>/dev/null || true)"

        case "$target" in
          "$HOME"/*)
            echo "DEV (~/tmux → $target)"
            ;;
          /nix/store/*)
            echo "PROD (~/tmux → $target)"
            ;;
          "")
            echo "UNKNOWN (~/tmux missing)"
            ;;
          *)
            echo "UNKNOWN (~/tmux → $target)"
            ;;
        esac
      }

      status() {
        local declared="UNKNOWN"

        if [ -r "$MODE_FILE" ]; then
          declared="$(cat "$MODE_FILE" 2>/dev/null || true)"
        else
          declared="UNKNOWN (missing $MODE_FILE)"
        fi

        case "$declared" in
          dev)  echo "dotfiles: DEV  (from $MODE_FILE)" ;;
          prod) echo "dotfiles: PROD (from $MODE_FILE)" ;;
          *)    echo "dotfiles: UNKNOWN ($declared)" ;;
        esac

        echo "effective: $(effective_mode)"
      }

      if [ "$#" -eq 0 ]; then show_help; fi

      MODE="$1"

      case "$MODE" in
        status)
          status
          exit 0
          ;;
        dev)
          echo "➜ Enabling dotfiles DEV mode (SNOWMAN_DOTFILES_MODE=dev)"
          export SNOWMAN_DOTFILES_MODE=dev
          echo "➜ Rebuilding NixOS for host ${currentHost}..."
          # Dev needs --impure to read the env var during eval
          sudo -H -E nixos-rebuild switch --impure --flake ".#${currentHost}"
          ;;
        prod|production)
          echo "➜ Enabling dotfiles PROD mode (unsetting SNOWMAN_DOTFILES_MODE)"
          unset SNOWMAN_DOTFILES_MODE
          echo "➜ Rebuilding NixOS for host ${currentHost}..."
          # Prod is pure
          sudo -H nixos-rebuild switch --flake ".#${currentHost}"
          ;;
        *)
          show_help
          ;;
      esac
    '')
  ];
}
