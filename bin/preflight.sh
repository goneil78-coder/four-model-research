#!/usr/bin/env bash
# Reports which research lanes are live. Run before trusting a report.
# Exit: 0 if all four live | 1 if any lane is down
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "four-model-research preflight"
echo "-----------------------------"
printf '%-10s %-6s %s\n' "LANE" "STATE" "DETAIL"
printf '%-10s %-6s %s\n' "claude" "LIVE" "native WebSearch inside Claude Code"

DOWN=0
for L in openai gemini grok; do
  OUT=$(./ask-$L.sh --check 2>&1); RC=$?
  if [[ $RC -eq 0 ]]; then
    printf '%-10s %-6s %s\n' "$L" "LIVE" "$(printf '%s' "$OUT" | tr '\n' ' ' | head -c 60)"
  else
    DOWN=1
    printf '%-10s %-6s %s\n' "$L" "DOWN" "rc=$RC $(printf '%s' "$OUT" | tr '\n' ' ' | head -c 90)"
  fi
done

echo "-----------------------------"
if [[ $DOWN -eq 0 ]]; then
  echo "All four lanes live. Cross-model convergence is meaningful."
else
  echo "One or more lanes DOWN. Any report must name the missing lanes"
  echo "and must NOT claim convergence across models that did not run."
fi
exit $DOWN
