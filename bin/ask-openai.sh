#!/usr/bin/env bash
# OpenAI lane — codex CLI with web search, on the ChatGPT subscription.
# Uses whatever auth codex already holds (auth_mode "chatgpt" = no API key).
# Usage: ask-openai.sh "query" | ask-openai.sh --check
# Exit: 0 ok | 3 not configured | 4 CLI error | 5 empty response
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

TIMEOUT="${OPENAI_TIMEOUT:-600}"

if ! command -v codex >/dev/null 2>&1; then
  echo "openai: codex CLI not found on PATH (npm i -g @openai/codex)" >&2; exit 3
fi

AUTH="$(jq -r '.auth_mode // "none"' "${CODEX_HOME:-$HOME/.codex}/auth.json" 2>/dev/null)"
if [[ "$AUTH" == "none" && -z "${OPENAI_API_KEY:-}" ]]; then
  echo "openai: codex is not authenticated (run: codex login)" >&2; exit 3
fi

if [[ "${1:-}" == "--check" ]]; then
  QUERY="Reply with exactly: OK"; TIMEOUT=120
else
  QUERY="${1:?usage: ask-openai.sh \"query\"}"
fi

OUTF=$(mktemp); ERRF=$(mktemp); trap 'rm -f "$OUTF" "$ERRF"' EXIT

timeout "$TIMEOUT" codex exec \
  --skip-git-repo-check --ephemeral --color never \
  -c tools.web_search=true \
  -o "$OUTF" "$QUERY" </dev/null >/dev/null 2>"$ERRF"
RC=$?

if [[ $RC -ne 0 ]]; then
  echo "openai: codex exited $RC: $(grep -viE 'bubblewrap|sandbox' "$ERRF" | head -c 400)" >&2; exit 4
fi

if [[ ! -s "$OUTF" ]]; then
  echo "openai: codex returned no final message" >&2; exit 5
fi

cat "$OUTF"
