#!/usr/bin/env bash
# Build the containerized Harbor controller and run a job through the host's
# rootless Podman socket. With no arguments, run the OpenCode 2 Caesar job.
set -euo pipefail

cd "$(dirname "$0")"

export HOST_PROJECT_DIR="$PWD"
export PODMAN_SOCKET="${PODMAN_SOCKET:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock}"
export PODMAN_COMPOSE_WARNING_LOGS=false
export OPENCODE_HOST_CONFIG_DIR="${OPENCODE_HOST_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode}"

if [[ ! -S "$PODMAN_SOCKET" ]]; then
  echo "Podman-Socket fehlt: $PODMAN_SOCKET" >&2
  echo "Starte ihn mit: systemctl --user enable --now podman.socket" >&2
  exit 1
fi

compose=(podman compose -f compose.yaml)
args=("$@")
if (($# == 0)); then
  args=(-c configs/caesar-opencode2.yaml)
fi

# YAML configs set environment.type themselves; keep the standalone CLI default
# on Podman as well.
if [[ " ${args[*]} " != *" -e "* && " ${args[*]} " != *" --env "* ]]; then
  args+=(-e podman)
fi

if [[ -z "${OPENROUTER_API_KEY:-}" && " ${args[*]} " == *"openrouter"* ]]; then
  export OPENROUTER_HOST_SECRET_FILE="${OPENROUTER_HOST_SECRET_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/harbour/openrouter.key}"
  if [[ -f "$OPENROUTER_HOST_SECRET_FILE" ]]; then
    compose+=(-f compose.openrouter.yaml)
  else
    echo "OPENROUTER_API_KEY ist nicht gesetzt und die lokale Key-Datei fehlt." >&2
    echo "Einmalig speichern:" >&2
    echo "  install -d -m 700 \"${OPENROUTER_HOST_SECRET_FILE%/*}\"" >&2
    echo "  umask 077; printf '%s' '<key>' > \"$OPENROUTER_HOST_SECRET_FILE\"" >&2
    exit 1
  fi
fi

# Only an explicit opencode-go/* model activates the paid Go credential. Export
# the active credential with the host CLI and remove the temporary file on exit.
if [[ -z "${OPENCODE_API_KEY:-}" && " ${args[*]} " == *"opencode-go"* ]]; then
  if ! command -v opencode >/dev/null 2>&1; then
    echo "OpenCode-CLI fehlt. Setze OPENCODE_API_KEY oder installiere OpenCode auf dem Host." >&2
    exit 1
  fi
  export OPENCODE_AUTH_EXPORT="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/harbor-opencode-auth-$(id -u).json"
  (umask 077; opencode auth export > "$OPENCODE_AUTH_EXPORT")
  trap 'rm -f "$OPENCODE_AUTH_EXPORT"' EXIT
  compose+=(-f compose.opencode-go.yaml)
fi

# Reuse an existing OpenCode Console login without baking credentials into an
# image or placing them in Harbor's collected agent-log directory.
if [[ -f "$OPENCODE_HOST_CONFIG_DIR/service.json" ]]; then
  if [[ " ${args[*]} " != *" local/opencode-auth.override.yaml "* ]]; then
    args+=(--extra-docker-compose local/opencode-auth.override.yaml)
  fi
fi

# Host-specific workaround: a /0 interface prefix prevents netavark from
# allocating any bridge subnet. It is deliberately not part of the base config.
if ip -4 addr show wlp4s0 2>/dev/null | grep -q "inet .*/0 "; then
  compose+=(-f compose.host-network.yaml)
  if [[ " ${args[*]} " != *" local/host-network.override.yaml "* ]]; then
    args+=(--extra-docker-compose local/host-network.override.yaml)
  fi
fi

"${compose[@]}" build harbor

started_epoch="$(date +%s)"
set +e
"${compose[@]}" run --rm -T harbor run "${args[@]}"
status=$?
set -e

if [[ " ${args[*]} " != *" --dry-run "* && " ${args[*]} " != *" --print-config "* ]]; then
  latest="$(ls -t jobs 2>/dev/null | head -1 || true)"
  if [[ -n "$latest" && -d "jobs/$latest" && "$(stat -c %Y "jobs/$latest")" -ge "$started_epoch" ]] \
    && find "jobs/$latest" -path '*/agent/opencode.txt' -print -quit | grep -q .; then
    "${compose[@]}" run --rm -T --entrypoint python harbor \
      /opt/harbor/agent/analyze_job.py "jobs/$latest" || true
  fi
fi

exit "$status"
