#!/bin/bash
# Oracle solution: brute-force the modified Caesar cipher.
#
# The challenge uses a 62-character alphabet, but does not say in which order
# the character classes appear. So we try both plausible letter orders, all 62
# shifts, and score every candidate against a small English word list.
set -euo pipefail

python3 - <<'PY'
from pathlib import Path

CIPHERTEXT_PATH = Path("/app/ciphertext.txt")
OUTPUT_PATH = Path("/app/plaintext.txt")

COMMON_WORDS = {
    "the", "and", "to", "of", "is", "in", "that", "it", "was", "for", "not",
    "be", "as", "you", "this", "with", "they", "a", "an", "are", "if", "or",
    "able", "about", "after", "all", "been", "but", "by", "can", "each",
    "even", "from", "get", "had", "has", "have", "how", "its", "more", "no",
    "one", "only", "so", "than", "their", "them", "then", "there", "these",
    "today", "way", "were", "what", "when", "which", "who", "would", "year",
}

LETTER_ORDERS = [
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz",
]

ALPHABETS = [letters + "0123456789" for letters in LETTER_ORDERS]
ALPHABETS += ["0123456789" + letters for letters in LETTER_ORDERS]


def rotate(text: str, alphabet: str, shift: int) -> str:
    """Shift every known character within `alphabet` (mod 62)."""
    return "".join(
        alphabet[(alphabet.index(ch) + shift) % len(alphabet)]
        if ch in alphabet
        else ch
        for ch in text
    )


def score(text: str) -> int:
    words = [w.strip(".,!?;:\"'()").lower() for w in text.split()]
    # Longer dictionary hits are much stronger evidence than short ones.
    return sum(len(w) for w in words if w in COMMON_WORDS)


ciphertext = CIPHERTEXT_PATH.read_text(encoding="utf-8").strip()

best_candidate = None
best_score = -1
best_description = ""

for alphabet in ALPHABETS:
    for shift in range(len(alphabet)):
        candidate = rotate(ciphertext, alphabet, shift)
        current = score(candidate)
        if current > best_score:
            best_candidate = candidate
            best_score = current
            best_description = f"alphabet={alphabet[:8]}..., shift={shift}"

assert best_candidate is not None
OUTPUT_PATH.write_text(best_candidate + "\n", encoding="utf-8")

print(f"best candidate ({best_description}, score={best_score}):")
print(best_candidate)
PY
