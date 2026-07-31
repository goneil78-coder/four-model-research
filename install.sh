#!/usr/bin/env bash
# Installs the command and the four lane agents into a Claude Code config dir.
# Usage: ./install.sh [CLAUDE_DIR]   (default ~/.claude)
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR="${1:-$HOME/.claude}"

[[ -d "$DIR" ]] || { echo "no such directory: $DIR" >&2; exit 1; }
mkdir -p "$DIR/commands" "$DIR/agents"

for f in "$REPO"/commands/*.md; do
  sed "s|__REPO__|$REPO|g" "$f" > "$DIR/commands/$(basename "$f")"
  echo "  commands/$(basename "$f")"
done
for f in "$REPO"/agents/*.md; do
  sed "s|__REPO__|$REPO|g" "$f" > "$DIR/agents/$(basename "$f")"
  echo "  agents/$(basename "$f")"
done
chmod +x "$REPO"/bin/*.sh

echo
echo "Installed to $DIR. Checking lanes:"
echo
"$REPO/bin/preflight.sh" || true
echo
echo "Run it with:  /conduct-research <your question>"
