# MysteryTwister: The Impatient Notary

`/app/RSA_pairs.txt` contains three RSA public keys `(N_i, e_i)` from three
generations of a signing device. The developer deliberately chose **small
private exponents** to make signing fast.

Recover the private exponents `d1`, `d2`, `d3`. Wiener's continued-fraction
attack applies when `d < (1/3) * N^(1/4)`: the fraction `k/d` appears among
the convergents of `e/N`.

Do not submit the exponents themselves. Compute:

```text
z = (d1 * d2) mod N2
r = z^d3 mod N3
```

Write `r` in decimal without leading zeros. Interpret that decimal string as
ASCII text and compute its **SHA-256 hash**.

Write the resulting 64 lowercase hex digits, without `0x` or separators, to
`/app/answer.txt`.

Example: for `r = 12345`, hash the five characters `12345`, giving
`5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5`.
