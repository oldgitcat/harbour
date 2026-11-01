# MysteryTwister: M-138 — Part 1

This challenge uses a simplified M-138 strip cipher.

`/app/stripset.txt` contains 100 numbered strips, each with the 26 capital
letters in a scrambled order. `/app/challenge.txt` contains the 25 strips used
for this message and the ciphertext.

For position `i` of the plaintext:

```text
strip = selected_strip[i]
ciphertext_letter = strip[(index_of(plaintext_letter) + offset) mod 26]
```

All 25 strips in the given order are known. The only unknown part of the key is
the common offset.

Your job:

1. Determine the offset and recover the plaintext.
2. Write the plaintext in **uppercase without spaces** to `/app/answer.txt`.
