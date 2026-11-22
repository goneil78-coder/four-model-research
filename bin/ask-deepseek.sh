#!/usr/bin/env bash
# DeepSeek lane — DeepSeek chat API with its server-side web search tool
# (deepseek_web_search + deepseek_read_url, launched Oct 2026). Its own search
# index reaches Chinese-language sources the other lanes rarely touch.
# Usage: ask-deepseek.sh "query"   → findings on stdout, exit 0
#        ask-deepseek.sh --check   → liveness probe only (chat, not search;
#                                    every real run enforces search itself)
# Env:   DEEPSEEK_RAW_OUT=/path.json  also save the full API response. It holds
#        the search records, so links can be traced (deepseek-provenance.ts).
#        Use a distinct path per call; an existing file is refused.
# Exit: 0 ok | 2 usage | 3 not configured | 4 API/transport/local error | 5 empty or unsearched
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

MODEL="${DEEPSEEK_MODEL:-deepseek-flash}"
API="${DEEPSEEK_API_BASE:-https://api.deepseek.com}/chat/completions"
TIMEOUT="${DEEPSEEK_TIMEOUT:-900}"

for bin in curl jq; do
  command -v "$bin" >/dev/null 2>&1 || { echo "deepseek: $bin not found on PATH" >&2; exit 3; }
done
if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
  echo "deepseek: DEEPSEEK_API_KEY is not set" >&2; exit 3
fi

CHECK=0
if [[ "${1:-}" == "--check" ]]; then
  CHECK=1; TIMEOUT=60
  BODY=$(jq -n --arg m "$MODEL" \
    '{model:$m, stream:false, messages:[{role:"user",content:"Reply with exactly: OK"}]}') \
    || { echo "deepseek: could not build request" >&2; exit 4; }
else
  QUERY="${1:-}"
  [[ -n "$QUERY" ]] || { echo 'usage: ask-deepseek.sh "query" | --check' >&2; exit 2; }
  if [[ -n "${DEEPSEEK_RAW_OUT:-}" && -e "$DEEPSEEK_RAW_OUT" ]]; then
    echo "deepseek: DEEPSEEK_RAW_OUT already exists ($DEEPSEEK_RAW_OUT); use a distinct path per call" >&2; exit 4
  fi
  # Two lessons from the 22 Nov 2026 run, both load-bearing:
  # - Without an explicit instruction to search, the model may answer in one
  #   line without calling the tool at all.
  # - Without "inline URL or discarded", it writes a polished report with zero
  #   URLs in the text (sources stay inside the tool-call records).
  PROMPT="Search the web thoroughly before answering (at least 15 searches). Where Chinese-language sources would help, search in Chinese too. Then write a full research report answering every part of the question below.

Every factual claim MUST have the full URL of the specific page it came from written inline right after it (https://..., never just a site name), plus its date. A claim with no inline page URL will be discarded. Tag each claim EVIDENCE (research, data, documented practice) or OPINION (commentary, advocacy). Where coverage is thin, say so plainly instead of padding. Write in English.

${QUERY}"
  BODY=$(jq -n --arg m "$MODEL" --arg q "$PROMPT" \
    '{model:$m, stream:false, max_tokens:16000, tool_choice:"auto",
      tools:[{type:"deepseek_web_search"},{type:"deepseek_read_url"}],
      messages:[{role:"user",content:$q}]}') \
    || { echo "deepseek: could not build request" >&2; exit 4; }
fi

RESPF=$(mktemp); ERRF=$(mktemp); trap 'rm -f "$RESPF" "$ERRF"' EXIT

# DeepSeek's 401 message echoes back the key it was given. Strip it from any
# diagnostic so a mistyped or real key never lands in a log or a lane report.
# Redact the WHOLE value first, then truncate: truncating first can cut the key
# in half so the full-key match misses it.
redact() { local s="$1" n="${2:-300}"; [[ -n "${DEEPSEEK_API_KEY:-}" ]] && s="${s//"$DEEPSEEK_API_KEY"/[REDACTED]}"; printf '%s' "$s" | sed -E 's/((api[ _-]?key|credential|token|bearer)[^A-Za-z0-9]{1,3})[A-Za-z0-9._-]{8,}/\1[REDACTED]/Ig' | head -c "$n"; }

# Key goes in via a header file descriptor, not argv, so it never shows in ps.
HTTP=$(curl -sS --max-time "$TIMEOUT" -X POST "$API" \
  -H "Content-Type: application/json" \
  -H @<(printf 'Authorization: Bearer %s\n' "$DEEPSEEK_API_KEY") \
  --data-binary @<(printf '%s' "$BODY") \
  -o "$RESPF" -w '%{http_code}' 2>"$ERRF")
RC=$?

if [[ $RC -ne 0 ]]; then
  echo "deepseek: curl failed (rc=$RC, timeout ${TIMEOUT}s?): $(redact "$(cat "$ERRF")")" >&2; exit 4
fi

if ! jq -e 'type=="object"' "$RESPF" >/dev/null 2>&1; then
  echo "deepseek: HTTP $HTTP, non-JSON response: $(redact "$(cat "$RESPF")")" >&2; exit 4
fi

if [[ "$HTTP" != 2* ]]; then
  echo "deepseek: HTTP $HTTP: $(redact "$(jq -r '.error.message // .error // . | tostring' "$RESPF")")" >&2; exit 4
fi

ERR=$(jq -r '.error.message // .error // empty | tostring' "$RESPF" 2>/dev/null)
if [[ -n "$ERR" ]]; then
  echo "deepseek: API error: $(redact "$ERR")" >&2; exit 4
fi

TEXT=$(jq -r '.choices[0].message.content | if type=="string" then . else empty end' "$RESPF" 2>/dev/null)
if [[ -z "${TEXT//[[:space:]]/}" ]]; then
  echo "deepseek: response had no text content (finish_reason=$(redact "$(jq -r '.choices[0].finish_reason // "?"' "$RESPF")" 40))" >&2; exit 5
fi

if [[ $CHECK -eq 1 ]]; then
  [[ "$TEXT" == *OK* ]] || { echo "deepseek: check got unexpected reply: $(redact "$TEXT" 80)" >&2; exit 4; }
  printf '%s\n' "$TEXT"; exit 0
fi

# An answer with no searches is the model's memory, not this lane's research.
# Counting it would let one model's recall pass as a searched lane. Anything but
# a positive integer — missing, null, malformed — is treated as no search.
SEARCHES=$(jq -er '.usage.server_tool_use.tool_search | if type=="number" and . == floor and . > 0 then tostring else "0" end' "$RESPF" 2>/dev/null)
JQRC=$?
if [[ $JQRC -ne 0 || ! "$SEARCHES" =~ ^[1-9][0-9]*$ ]]; then
  echo "deepseek: model answered without running any web search; refusing to report memory as research" >&2; exit 5
fi

if [[ -n "${DEEPSEEK_RAW_OUT:-}" ]]; then
  TMP=$(umask 077 && mktemp "$(dirname -- "$DEEPSEEK_RAW_OUT")/.deepseek-raw.XXXXXX") \
    || { echo "deepseek: cannot create a temp file beside $DEEPSEEK_RAW_OUT" >&2; exit 4; }
  trap 'rm -f "$RESPF" "$ERRF" "$TMP"' EXIT
  if ! cat "$RESPF" > "$TMP" || ! mv -nT -- "$TMP" "$DEEPSEEK_RAW_OUT" || [[ -e "$TMP" ]]; then
    echo "deepseek: could not save raw response to $DEEPSEEK_RAW_OUT; the provenance check needs it" >&2; exit 4
  fi
fi

FINISH=$(redact "$(jq -r '.choices[0].finish_reason // "?"' "$RESPF")" 40)
[[ "$FINISH" == "length" ]] && echo "deepseek: WARNING output hit max_tokens; report may be truncated" >&2
echo "deepseek: ${SEARCHES} web searches, finish_reason=${FINISH}" >&2

printf '%s\n' "$TEXT"
