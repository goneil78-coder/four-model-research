#!/usr/bin/env bash
# Enumerate domains/subdomains for a company. Reports which techniques ran.
# Usage: company-domains.sh <domain>   e.g. company-domains.sh example.com.hk
set -uo pipefail
export PATH="$PATH:$HOME/go/bin:/usr/local/go/bin"

DOMAIN="${1:-}"
[ -n "$DOMAIN" ] || { echo "usage: $(basename "$0") <domain>" >&2; exit 2; }
OUT=$(mktemp -d); trap 'rm -rf "$OUT"' EXIT
RAN=(); SKIPPED=()

echo "# Domain enumeration: $DOMAIN"
echo "# $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

# 1. certificate transparency — free, no key, slow
if timeout 90 curl -sL -H 'User-Agent: Mozilla/5.0' \
     "https://crt.sh/?q=%25.${DOMAIN}&output=json" -o "$OUT/crt.json" 2>/dev/null \
   && [ -s "$OUT/crt.json" ]; then
  jq -r '.[]?.name_value // empty' "$OUT/crt.json" 2>/dev/null \
    | tr '[:upper:]' '[:lower:]' | tr ' ' '\n' | sed 's/^\*\.//' \
    | grep -E '^[a-z0-9.-]+$' >> "$OUT/all" 2>/dev/null
  RAN+=("crt.sh")
else SKIPPED+=("crt.sh (unreachable or empty)"); fi

# 2. passive sources
if command -v subfinder >/dev/null 2>&1 || [ -x "$HOME/go/bin/subfinder" ]; then
  timeout 180 subfinder -silent -d "$DOMAIN" >> "$OUT/all" 2>/dev/null && RAN+=("subfinder") \
    || SKIPPED+=("subfinder (ran but errored)")
else SKIPPED+=("subfinder (not installed)"); fi

if command -v assetfinder >/dev/null 2>&1 || [ -x "$HOME/go/bin/assetfinder" ]; then
  timeout 120 assetfinder --subs-only "$DOMAIN" >> "$OUT/all" 2>/dev/null && RAN+=("assetfinder") \
    || SKIPPED+=("assetfinder (ran but errored)")
else SKIPPED+=("assetfinder (not installed)"); fi

sort -u "$OUT/all" 2>/dev/null | grep -E "${DOMAIN//./\\.}$" > "$OUT/uniq" 2>/dev/null || : > "$OUT/uniq"
COUNT=$(wc -l < "$OUT/uniq" | tr -d ' ')

echo "## Hosts found: $COUNT"
echo
if command -v httpx >/dev/null 2>&1 || [ -x "$HOME/go/bin/httpx" ]; then
  echo "## Live hosts (title, status, tech)"
  timeout 240 httpx -silent -title -status-code -tech-detect -l "$OUT/uniq" 2>/dev/null || echo "(httpx errored)"
  RAN+=("httpx")
else
  SKIPPED+=("httpx (not installed) — hosts unprobed, listed raw")
  cat "$OUT/uniq"
fi

echo
echo "## Techniques run:     ${RAN[*]:-none}"
echo "## Techniques skipped: ${SKIPPED[*]:-none}"
echo
echo "## Not covered by this script — do by hand:"
echo "   - alternative TLDs (.hk .com.hk .partners .capital .fund) — try each"
echo "   - reverse WHOIS on the registrant (whois $DOMAIN)"
echo "   - domains named in registry filings and social bios"
echo
echo "Coverage here is partial by construction. Say so in the report."
