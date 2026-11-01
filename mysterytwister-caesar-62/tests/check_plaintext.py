"""Check the recovered MysteryTwister plaintext.

Case sensitive (the challenge explicitly requires correct upper/lower case).
Whitespace is normalized so that line wrapping does not matter.
"""

from pathlib import Path
import sys

EXPECTED = (
    "This encrypted message shall clarify how NOT to encrypt a message today! "
    "Even if it was sufficient about 2000 years ago, or to be more precise in "
    "the year 44 BC, nowadays it is not. Today each so-called Script Kiddie "
    "would be able to get sensitive information, if they were encrypted this way."
)

SOLUTION_PATH = Path("/app/plaintext.txt")
MAX_DIFF_CHARS = 400


def normalize(text: str) -> str:
    return " ".join(text.split())


def main() -> int:
    if not SOLUTION_PATH.exists():
        print(f"FAIL: {SOLUTION_PATH} does not exist")
        return 1

    actual = normalize(SOLUTION_PATH.read_text(encoding="utf-8", errors="replace"))
    expected = normalize(EXPECTED)

    if actual == expected:
        print("PASS: plaintext matches the reference solution")
        return 0

    print("FAIL: plaintext does not match the reference solution")
    for i, (a, b) in enumerate(zip(actual, expected)):
        if a != b:
            start = max(0, i - 60)
            print(f"first difference at character {i}:")
            print(f"  expected: ...{expected[start:i + 60]!r}")
            print(f"  actual:   ...{actual[start:i + 60]!r}")
            break
    else:
        print(f"length differs: expected {len(expected)}, got {len(actual)}")

    print(f"expected ({len(expected)} chars): {expected[:MAX_DIFF_CHARS]}")
    print(f"actual   ({len(actual)} chars): {actual[:MAX_DIFF_CHARS]}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
