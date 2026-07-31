#!/usr/bin/env bash
# Gemini lane — gemini CLI with Google Search grounding.
# Usage: ask-gemini.sh "query" | ask-gemini.sh --check
# Exit: 0 ok | 3 not configured | 4 CLI error | 5 empty response
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

# NOT an *-image-preview model. Those are image-generation previews; pointing
# research at one is what produced fabricated URLs in the previous version.
MODEL="${GEMINI_MODEL:-gemini-3.1-pro-preview}"
TIMEOUT="${GEMINI_TIMEOUT:-300}"

if ! command -v gemini >/dev/null 2>&1; then
  echo "gemini: CLI not found on PATH (npm i -g @google/gemini-cli)" >&2; exit 3
fi
if [[ -z "${GEMINI_API_KEY:-}${GOOGLE_API_KEY:-}" ]]; then
  echo "gemini: neither GEMINI_API_KEY nor GOOGLE_API_KEY is set" >&2; exit 3
fi

if [[ "${1:-}" == "--check" ]]; then
  QUERY="Reply with exactly: OK"; TIMEOUT=60
else
  QUERY="${1:?usage: ask-gemini.sh \"query\"}"
fi

ERRF=$(mktemp); trap 'rm -f "$ERRF"' EXIT
OUT=$(timeout "$TIMEOUT" gemini -m "$MODEL" -p "$QUERY" 2>"$ERRF")
RC=$?

if [[ $RC -ne 0 ]]; then
  echo "gemini: CLI exited $RC: $(head -c 400 "$ERRF")" >&2; exit 4
fi

CLEAN=$(printf '%s\n' "$OUT" \
  | grep -vE '^(Both GOOGLE_API_KEY and GEMINI_API_KEY are set|Ripgrep is not available|Loaded cached credentials)' \
  | sed '/^[[:space:]]*$/d')

if [[ -z "$CLEAN" ]]; then
  echo "gemini: returned no usable output" >&2; exit 5
fi

printf '%s\n' "$CLEAN"
