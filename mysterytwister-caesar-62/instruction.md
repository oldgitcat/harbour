# MysteryTwister: Caesar Encryption (MTC3, modified alphabet)

You are given a ciphertext in `/app/ciphertext.txt`. It was produced with a
Caesar cipher, but the classic method was slightly modified: the cipher does
**not** use the usual 26-letter alphabet, it shifts through an alphabet of
**62 characters** (`a-z`, `A-Z`, `0-9`).

Your job:

1. Decrypt the ciphertext.
2. Write the recovered English plaintext to `/app/plaintext.txt`.

Rules:

- The plaintext is one English paragraph.
- Upper and lower case letters must be **exactly** right. Digits must be
  preserved as well.
- Punctuation stays as it is in the plaintext.

Hints:

- The encoder may have made a mistake with two letters, so a single wrong
  character does not mean your shift is wrong.
- If you are unsure about the alphabet order, brute-force the shift for every
  plausible ordering of `a-z`, `A-Z`, `0-9` and score the candidates against
  common English words.
