#!/usr/bin/env bash

# This script finds files with given extensions in the current directory and its subdirectories,
# formats them with a comment containing their relative path, and concatenates
# them into a single file named export.txt.
#
# Usage:
#   ./export_files.sh zsh
#   ./export_files.sh zsh,nix,yml,txt

set -euo pipefail

# --- Arguments & validation ---------------------------------------------------

if [[ $# -lt 1 || -z "${1:-}" ]]; then
    echo "Error: No filetype(s) given." >&2
    echo "Usage: $0 ext1[,ext2,...]" >&2
    exit 1
fi

IFS=',' read -r -a exts <<<"$1"

# Filter out empty entries (e.g. accidental trailing comma)
filtered_exts=()
for ext in "${exts[@]}"; do
    [[ -n "$ext" ]] && filtered_exts+=("$ext")
done

if [[ ${#filtered_exts[@]} -eq 0 ]]; then
    echo "Error: No valid filetypes found in '$1'." >&2
    exit 1
fi

# --- Config -------------------------------------------------------------------

OUTPUT_FILE="export.txt"

# Step 0: Delete the old export file and create a new, empty one.
: >"$OUTPUT_FILE"
echo "Initialized empty '$OUTPUT_FILE'."

# --- Build find command -------------------------------------------------------

# We want:
#   find . -type d -name plugin -prune -o -type f \( -name "*.ext1" -o -name "*.ext2" ... \) -print
FIND_CMD=(
    find .
    -type d -name plugins -prune -o
    -type f ! -name ".p10k.zsh" \(
)

first=1
for ext in "${filtered_exts[@]}"; do
    if [[ $first -eq 1 ]]; then
        FIND_CMD+=(-name "*.${ext}")
        first=0
    else
        FIND_CMD+=(-o -name "*.${ext}")
    fi
done

FIND_CMD+=(\) -print)

echo "Running: ${FIND_CMD[*]}"

# --- Main loop ----------------------------------------------------------------

"${FIND_CMD[@]}" | while read -r filepath; do
    clean_path="${filepath#./}"

    # Determine language for code fence from extension
    ext="${clean_path##*.}"
    lang="$ext"
    case "$ext" in
    sh | bash | zsh)
        lang="sh"
        ;;
    yml)
        lang="yaml"
        ;;
    lua)
        lang="lua"
        ;;
    *)
        lang="$ext"
        ;;
    esac

    {
        echo "\`\`\`$lang"
        echo "# $clean_path"
        echo ""
        cat "$filepath"
        echo '```'
        echo ""
        echo ""
    } >>"$OUTPUT_FILE"

    echo "Appended '$clean_path' to '$OUTPUT_FILE'."
done

echo "✅ All matching files (${filtered_exts[*]}) have been successfully exported to '$OUTPUT_FILE'."
