#!/usr/bin/env bash
# Harbor 0.25.0 emits OpenCode 1 argument ordering and permission flags. Move
# `run` in front of all run flags, translate permissions, and use OpenCode 2's
# private server instead of the background service. Version/help calls must not
# start a server.
for arg in "$@"; do
  case "$arg" in
    --) break ;;
    --version | -v | --help) exec opencode2 "$@" ;;
  esac
done

args=()
run_mode=false
for arg in "$@"; do
  if [[ "$arg" == "run" && "$run_mode" == false ]]; then
    run_mode=true
    continue
  fi
  if [[ "$arg" == "--dangerously-skip-permissions" ]]; then
    args+=(--auto)
  else
    args+=("$arg")
  fi
done

if [[ "$run_mode" == true ]]; then
  exec opencode2 run --standalone "${args[@]}"
fi
exec opencode2 "${args[@]}"
