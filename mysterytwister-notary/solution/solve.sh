#!/bin/bash
# Oracle: recover all three small RSA private exponents with Wiener's attack,
# then compute the challenge's chained value and SHA-256 digest.
set -euo pipefail

APP_DIR="${APP_DIR:-/app}"

APP_DIR="$APP_DIR" python3 - <<'PY'
from pathlib import Path
import hashlib
import os
import re

APP = Path(os.environ["APP_DIR"])
values: dict[tuple[str, int], int] = {}
for line in (APP / "RSA_pairs.txt").read_text().splitlines():
    match = re.match(r"([Ne])_(\d+)\s*=\s*(\d+)", line)
    if match:
        values[(match.group(1), int(match.group(2)))] = int(match.group(3))


def continued_fraction(numerator: int, denominator: int):
    while denominator:
        quotient = numerator // denominator
        yield quotient
        numerator, denominator = denominator, numerator - quotient * denominator


def convergents(terms):
    h_prev, h = 0, 1
    k_prev, k = 1, 0
    for term in terms:
        h_prev, h = h, term * h + h_prev
        k_prev, k = k, term * k + k_prev
        yield h, k


def wiener_attack(n: int, e: int) -> int:
    ciphertext_2 = pow(2, e, n)
    ciphertext_3 = pow(3, e, n)
    for k, d in convergents(continued_fraction(e, n)):
        if k == 0 or (e * d - 1) % k:
            continue
        # A valid private exponent decrypts independent RSA ciphertexts.
        if pow(ciphertext_2, d, n) == 2 and pow(ciphertext_3, d, n) == 3:
            return d
    raise RuntimeError("Wiener attack found no private exponent")


private_exponents = [
    wiener_attack(values[("N", index)], values[("e", index)])
    for index in (1, 2, 3)
]
for index, exponent in enumerate(private_exponents, start=1):
    print(f"d{index}: {exponent.bit_length()} bits")

z = private_exponents[0] * private_exponents[1] % values[("N", 2)]
r = pow(z, private_exponents[2], values[("N", 3)])
digits = str(r)
digest = hashlib.sha256(digits.encode("ascii")).hexdigest()
(APP / "answer.txt").write_text(digest + "\n", encoding="utf-8")
print(f"decimal digits: {len(digits)}")
print(f"answer: {digest}")
PY
