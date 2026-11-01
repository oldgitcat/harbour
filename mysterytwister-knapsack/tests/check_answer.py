"""Validate the recovered knapsack plaintext exactly (whitespace normalized)."""

from pathlib import Path
import sys

EXPECTED = "IT'S SUPERINCREASING, BABY!"
ANSWER_PATH = Path("/app/answer.txt")


def normalize(text: str) -> str:
    return " ".join(text.split())


def main() -> int:
    if not ANSWER_PATH.exists():
        print(f"FAIL: {ANSWER_PATH} does not exist")
        return 1

    actual = normalize(ANSWER_PATH.read_text(encoding="utf-8", errors="replace"))
    expected = normalize(EXPECTED)
    if actual == expected:
        print("PASS: knapsack plaintext matches the reference solution")
        return 0

    print("FAIL: knapsack plaintext does not match the reference solution")
    print(f"expected: {expected!r}")
    print(f"actual:   {actual!r}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
