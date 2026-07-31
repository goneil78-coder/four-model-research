#!/usr/bin/env bash
# Check that cited URLs actually resolve. Reads URLs on stdin or from a file.
# Usage:  verify-urls.sh < urls.txt   |   grep -oE 'https?://[^ )]+' report.md | verify-urls.sh
# Exit 0 always; dead URLs are data, not an error.
set -uo pipefail

SRC="${1:-/dev/stdin}"
mapfile -t URLS < <(grep -oE 'https?://[^ )"'"'"'<>]+' "$SRC" | sed 's/[].,;:)]*$//' | sort -u)
[ "${#URLS[@]}" -gt 0 ] || { echo "no URLs found"; exit 0; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
for u in "${URLS[@]}"; do
  ( code=$(timeout 20 curl -sIL -o /dev/null -w '%{http_code}' \
             -H 'User-Agent: Mozilla/5.0' "$u" 2>/dev/null || echo 000)
    [ "$code" = "405" ] || [ "$code" = "000" ] && \
      code=$(timeout 20 curl -sL -o /dev/null -w '%{http_code}' -r 0-0 \
             -H 'User-Agent: Mozilla/5.0' "$u" 2>/dev/null || echo 000)
    printf '%s\t%s\n' "$code" "$u" >> "$TMP/out" ) &
  while [ "$(jobs -r | wc -l)" -ge 12 ]; do wait -n; done
done
wait

ok=0; dead=0; blocked=0
echo "URL CHECK"
echo "----------------------------------------"
while IFS=$'\t' read -r code url; do
  case "$code" in
    2*|3*)   ok=$((ok+1)) ;;
    401|403|429) blocked=$((blocked+1)); printf "  BLOCKED %s  %s\n" "$code" "$url" ;;
    *)       dead=$((dead+1));   printf "  DEAD    %s  %s\n" "$code" "$url" ;;
  esac
done < <(sort -k2 "$TMP/out")
echo "----------------------------------------"
echo "$ok live, $blocked blocked (paywall/bot-check — source may still be real), $dead dead."
[ "$dead" -gt 0 ] && echo "Remove dead URLs from Findings. If a finding rested on one, downgrade its confidence."
exit 0
