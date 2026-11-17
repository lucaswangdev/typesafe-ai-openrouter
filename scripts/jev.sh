#!/usr/bin/env bash
# POST a decisions request to Jev on OpenRouter, resolving the API key without
# relying on any shell rc file (non-interactive agents never source ~/.zshrc).
#
# Key resolution order:
#   1. $OPENROUTER_API_KEY
#   2. $XDG_CONFIG_HOME/openrouter/key   (default ~/.config/openrouter/key, mode 600)
#
# Usage:
#   scripts/jev.sh request.json      # body from file
#   cat body.json | scripts/jev.sh   # body from stdin
#
# Env overrides: JEV_ENDPOINT. Exits non-zero on HTTP >= 400 (with the body printed),
# so a failed call is never mistaken for an answer.
set -euo pipefail

resolve_key() {
  if [ -n "${OPENROUTER_API_KEY:-}" ]; then
    printf '%s' "$OPENROUTER_API_KEY"
    return 0
  fi
  local candidate
  for candidate in "${XDG_CONFIG_HOME:-$HOME/.config}/openrouter/key" \
                   "$HOME/.config/openrouter/key"; do
    if [ -r "$candidate" ]; then
      tr -d '[:space:]' < "$candidate"
      return 0
    fi
  done
  return 1
}

KEY="$(resolve_key)" || {
  printf 'error: no API key. Either export OPENROUTER_API_KEY="sk-or-v1-..." or write it to ~/.config/openrouter/key with chmod 600.\n' >&2
  exit 2
}

ENDPOINT="${JEV_ENDPOINT:-https://openrouter.ai/api/alpha/decisions}"
BODY_SOURCE="${1:--}"

if [ "$BODY_SOURCE" = "-" ]; then
  exec curl -sS --fail-with-body --max-time 60 "$ENDPOINT" \
    -H "Authorization: Bearer $KEY" \
    -H "Content-Type: application/json" \
    -H "X-Title: typesafe-ai-openrouter-skill" \
    --data-binary @-
fi

[ -r "$BODY_SOURCE" ] || { printf 'error: cannot read request body file: %s\n' "$BODY_SOURCE" >&2; exit 2; }
exec curl -sS --fail-with-body --max-time 60 "$ENDPOINT" \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -H "X-Title: typesafe-ai-openrouter-skill" \
  --data-binary "@$BODY_SOURCE"
