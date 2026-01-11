set -euo pipefail

show_help() {
        echo "Usage: snowman-dotfiles [dev|prod|status]"
        echo ""
        echo "  dev     - Enable dev mode (mutable symlinks managed by HM)"
        echo "  prod    - Enable prod mode (immutable store links managed by HM)"
        echo "  status  - Show declared + effective mode"
        exit 0
}
