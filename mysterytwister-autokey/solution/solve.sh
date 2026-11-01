#!/bin/bash
# Oracle: brute-force short autokey keywords and select the candidate that
# contains the known word WORLD and segments cleanly into English words.
set -euo pipefail

APP_DIR="${APP_DIR:-/app}"

APP_DIR="$APP_DIR" python3 - <<'PY'
from itertools import product
from pathlib import Path
from string import ascii_uppercase
import os

APP = Path(os.environ["APP_DIR"])
CIPHERTEXT = "".join((APP / "ciphertext.txt").read_text().split()).upper()

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


def decrypt(keyword: str) -> str:
    plaintext: list[str] = []
    for i, cipher_char in enumerate(CIPHERTEXT):
        key_char = keyword[i] if i < len(keyword) else plaintext[i - len(keyword)]
        value = (ord(cipher_char) - ord(key_char)) % 26
        plaintext.append(chr(ord("A") + value))
    return "".join(plaintext)


def segment(text: str) -> list[str] | None:
    """Return the fewest-word full dictionary segmentation, if one exists."""
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
for length in range(1, 5):
    for letters in product(ascii_uppercase, repeat=length):
        keyword = "".join(letters)
        plaintext = decrypt(keyword)
        if "WORLD" not in plaintext:
            continue
        words = segment(plaintext)
        score = (len(words) if words else 10_000, -len(keyword))
        candidates.append((score, keyword, plaintext, words))

assert candidates, "no autokey candidate containing WORLD found"
_, keyword, plaintext, words = min(candidates, key=lambda item: item[0])
answer = plaintext
(APP / "answer.txt").write_text(answer + "\n", encoding="utf-8")

print(f"keyword: {keyword}")
print(f"plaintext: {plaintext}")
print(f"answer: {answer}")
PY
