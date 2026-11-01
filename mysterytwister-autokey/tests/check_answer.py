"""Validate the recovered autokey plaintext (spaces and case normalized)."""

from pathlib import Path
import sys

EXPECTED = "WELCOMETOTHEWORLDOFCRYPTOGRAPHY"
ANSWER_PATH = Path("/app/answer.txt")


def normalize(text: str) -> str:
    return "".join(ch for ch in text.upper() if "A" <= ch <= "Z")


def main() -> int:
    if not ANSWER_PATH.exists():
        print(f"FAIL: {ANSWER_PATH} does not exist")
        return 1

    actual = normalize(ANSWER_PATH.read_text(encoding="utf-8", errors="replace"))
    if actual == EXPECTED:
        print("PASS: autokey plaintext matches the reference solution")
        return 0

    print("FAIL: autokey plaintext does not match the reference solution")
    print(f"expected compact ({len(EXPECTED)}): {EXPECTED}")
    print(f"actual   compact ({len(actual)}): {actual}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
