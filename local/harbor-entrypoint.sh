#!/usr/bin/env bash
set -euo pipefail

# Optional: load an existing OpenCode Go API key without requiring Python or
# jq on the host. run.sh only mounts this file for an explicit opencode-go model.
if [[ -z "${OPENCODE_API_KEY:-}" && -f /run/secrets/opencode-auth.json ]]; then
  OPENCODE_API_KEY="$(python -c 'import json; credentials=json.load(open("/run/secrets/opencode-auth.json")); print(next(c["value"]["key"] for c in credentials if c.get("integrationID") == "opencode-go" and c.get("active")))')"
  export OPENCODE_API_KEY
fi

if [[ -z "${OPENROUTER_API_KEY:-}" && -f /run/secrets/openrouter_api_key ]]; then
  OPENROUTER_API_KEY="$(< /run/secrets/openrouter_api_key)"
  export OPENROUTER_API_KEY
fi

exec harbor "$@"
