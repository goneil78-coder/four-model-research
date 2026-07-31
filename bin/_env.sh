# Sourced by each lane script. Loads API keys from the first env file found.
# Override with FOUR_MODEL_ENV=/path/to/file
#
# Parses KEY=VALUE lines rather than sourcing: a .env is data, not a script.
# Sourcing executes whatever is in the file — an unquoted value containing
# |, &, ; or $( ) runs as a command. Malformed lines are skipped, not fatal.
# Values already present in the environment win.
for _f in "${FOUR_MODEL_ENV:-}" \
          "$(dirname "${BASH_SOURCE[0]}")/../.env" \
          "$HOME/.four-model-research.env" \
          "$HOME/.claude/.env"; do
  [[ -n "$_f" && -f "$_f" ]] || continue
  while IFS= read -r _line; do
    _k="${_line%%=*}"; _v="${_line#*=}"
    [[ "$_k" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    _v="${_v%\"}"; _v="${_v#\"}"; _v="${_v%\'}"; _v="${_v#\'}"
    [[ -n "${!_k:-}" ]] || export "$_k=$_v"
  done < <(grep -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' "$_f" | sed 's/^[[:space:]]*//')
  break
done
unset _f _line _k _v
