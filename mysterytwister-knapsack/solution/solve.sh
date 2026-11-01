#!/bin/bash
# Oracle: solve the superincreasing subset sum, convert the bit string back to
# decimal, and split the concatenated ASCII codes into a printable plaintext.
set -euo pipefail

APP_DIR="${APP_DIR:-/app}"

APP_DIR="$APP_DIR" python3 - <<'PY'
from functools import lru_cache
from pathlib import Path
import ast
import os
import re

APP = Path(os.environ["APP_DIR"])
text = (APP / "knapsack_part1_add.txt").read_text()
knapsack = ast.literal_eval(re.search(r"K = (\[.*?\])", text, re.S).group(1))
ciphertext = int(re.search(r"C = (\d+)", text).group(1))

# A superincreasing knapsack is solved greedily from the largest element down.
remaining = ciphertext
selected: set[int] = set()
for index, value in sorted(enumerate(knapsack), key=lambda item: item[1], reverse=True):
    if value <= remaining:
        selected.add(index)
        remaining -= value
assert remaining == 0, "ciphertext is not a subset sum of the knapsack"

bits = "".join("1" if index in selected else "0" for index in range(len(knapsack)))
decimal = str(int(bits, 2))


@lru_cache(maxsize=None)
def decode(position: int) -> tuple[str, ...]:
    if position == len(decimal):
        return ("",)
    results: list[str] = []
    for width in (2, 3):
        if position + width <= len(decimal):
            value = int(decimal[position:position + width])
            if 32 <= value <= 126:
                for rest in decode(position + width):
                    results.append(chr(value) + rest)
    return tuple(results)


solutions = decode(0)
assert solutions, "no printable ASCII decoding found"


def score(candidate: str) -> tuple[int, int]:
    letters = sum(ch.isalpha() or ch == " " for ch in candidate)
    punctuation = sum(ch in ".,!?'-:;" for ch in candidate)
    return letters, punctuation


answer = max(solutions, key=score)
(APP / "answer.txt").write_text(answer + "\n", encoding="utf-8")

print(f"selected elements: {len(selected)}")
print(f"decimal: {decimal}")
print(f"answer: {answer}")
PY
