#!/bin/bash
# Verifier entrypoint. Runs in the agent container after the agent finished.
# Harbor uploads tests/ to /tests and expects a reward in /logs/verifier/.
set -uo pipefail

mkdir -p /logs/verifier
echo 0 > /logs/verifier/reward.txt

cd /app || true

if python3 /tests/check_plaintext.py; then
  echo 1 > /logs/verifier/reward.txt
fi

echo "reward: $(cat /logs/verifier/reward.txt)"
