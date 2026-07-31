#!/usr/bin/env bash
# Grok lane — xAI Agent Tools API with live web + X search.
# Usage: ask-grok.sh "query"   → findings on stdout, exit 0
#        ask-grok.sh --check   → liveness probe only
# Exit: 0 ok | 3 not configured | 4 API error | 5 empty response
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

MODEL="${GROK_MODEL:-grok-4.5}"
API="${XAI_API_BASE:-https://api.x.ai/v1}/responses"
TIMEOUT="${GROK_TIMEOUT:-300}"

if [[ -z "${XAI_API_KEY:-}" ]]; then
  echo "grok: XAI_API_KEY is not set" >&2; exit 3
fi

if [[ "${1:-}" == "--check" ]]; then
  QUERY="Reply with exactly: OK"; TOOLS='[]'; TIMEOUT=60
else
  QUERY="${1:?usage: ask-grok.sh \"query\"}"
  # x_search is this lane's reason to exist — no other model can see X.
  TOOLS='[{"type":"web_search"},{"type":"x_search"}]'
fi

BODY=$(jq -n --arg m "$MODEL" --arg q "$QUERY" --argjson t "$TOOLS" \
  '{model:$m, input:[{role:"user",content:$q}], tools:$t}')

RESP=$(curl -sS --max-time "$TIMEOUT" -X POST "$API" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $XAI_API_KEY" \
  -d "$BODY" 2>&1)

if [[ -z "$RESP" ]]; then
  echo "grok: no response from $API (timeout after ${TIMEOUT}s?)" >&2; exit 4
fi

# xAI reports failure two ways: a bare {"error":...} or status != completed.
ERR=$(printf '%s' "$RESP" | jq -r 'if type=="object" then (.error // empty) else empty end' 2>/dev/null)
if [[ -n "$ERR" && "$ERR" != "null" ]]; then
  echo "grok: API error: $ERR" >&2; exit 4
fi

STATUS=$(printf '%s' "$RESP" | jq -r '.status // "unknown"' 2>/dev/null)
if [[ "$STATUS" != "completed" ]]; then
  echo "grok: response status=$STATUS" >&2; exit 4
fi

TEXT=$(printf '%s' "$RESP" | jq -r '[.output[]? | select(.type=="message") | .content[]? | .text // empty] | join("\n")' 2>/dev/null)
if [[ -z "$TEXT" ]]; then
  echo "grok: completed but returned no message text" >&2; exit 5
fi

printf '%s\n' "$TEXT"
