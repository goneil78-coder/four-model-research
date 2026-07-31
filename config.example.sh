# Copy to config.sh and edit, or set these in your shell / .env.

# Where reports are written.
export RESEARCH_DIR="$HOME/research"

# Model per lane. Change these when a newer model ships.
export GROK_MODEL="grok-4.5"                  # must support the Agent Tools API
export GEMINI_MODEL="gemini-3.1-pro-preview"  # never an *-image-preview model

# Per-lane timeout in seconds.
export GROK_TIMEOUT=300
export GEMINI_TIMEOUT=300
export OPENAI_TIMEOUT=420
