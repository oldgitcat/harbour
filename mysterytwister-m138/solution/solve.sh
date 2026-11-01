#!/bin/bash
# Oracle: try every strip offset and choose the candidate that segments into
# English dictionary words.
set -euo pipefail

APP_DIR="${APP_DIR:-/app}"

APP_DIR="$APP_DIR" python3 - <<'PY'
from pathlib import Path
import os

APP = Path(os.environ["APP_DIR"])
strips = {}
for line in (APP / "stripset.txt").read_text().splitlines():
    parts = line.split()
    if len(parts) >= 2:
        strips[parts[0]] = parts[1]

challenge = (APP / "challenge.txt").read_text()
strip_order = challenge.split("Strip order:")[1].split("Ciphertext:")[0].split()
ciphertext = "".join(challenge.split("Ciphertext:")[1].split()).upper()

WORDS = set()
for dictionary in ("/usr/share/dict/words", "/usr/share/dict/american-english"):
    try:
        WORDS.update(
            word.strip().lower()
            for word in Path(dictionary).read_text(errors="ignore").splitlines()
            if word.strip().isalpha()
        )
        break
    except FileNotFoundError:
        continue


def segment(text: str) -> list[str] | None:
    memo: list[list[str] | None] = [None] * (len(text) + 1)
    memo[0] = []
    for end in range(1, len(text) + 1):
        best = None
        for start in range(end):
            word = text[start:end].lower()
            if memo[start] is not None and word in WORDS:
                candidate = memo[start] + [text[start:end]]
                if best is None or len(candidate) < len(best):
                    best = candidate
        memo[end] = best
    return memo[-1]


candidates = []
for offset in range(26):
    plaintext = "".join(
        strips[strip][(strips[strip].index(cipher) - offset) % 26]
        for strip, cipher in zip(strip_order, ciphertext)
    )
    words = segment(plaintext)
    score = (0, len(words)) if words else (1, 10_000)
    candidates.append((score, offset, plaintext, words))

_, offset, plaintext, words = min(candidates, key=lambda item: item[0])
answer = plaintext
(APP / "answer.txt").write_text(answer + "\n", encoding="utf-8")

print(f"offset: {offset}")
print(f"plaintext: {plaintext}")
print(f"answer: {answer}")
PY
