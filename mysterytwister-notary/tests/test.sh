#!/bin/bash
set -uo pipefail

mkdir -p /logs/verifier
echo 0 > /logs/verifier/reward.txt

cd /app || true

if python3 /tests/check_answer.py; then
  echo 1 > /logs/verifier/reward.txt
fi

echo "reward: $(cat /logs/verifier/reward.txt)"
