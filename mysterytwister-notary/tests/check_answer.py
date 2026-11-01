"""Validate the SHA-256 digest required by The Impatient Notary."""

from pathlib import Path
import sys

EXPECTED = "37ba03f6cf673cd9af2cbb91371b2cbe9d37a57c2d6c26a76542a0f582f2fff7"
ANSWER_PATH = Path("/app/answer.txt")


def main() -> int:
    if not ANSWER_PATH.exists():
        print(f"FAIL: {ANSWER_PATH} does not exist")
        return 1

    actual = ANSWER_PATH.read_text(encoding="utf-8", errors="replace").strip().lower()
    if actual == EXPECTED:
        print("PASS: private exponents yield the expected SHA-256 digest")
        return 0

    print("FAIL: SHA-256 digest does not match")
    print(f"expected: {EXPECTED}")
    print(f"actual:   {actual}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
