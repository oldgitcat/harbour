# MysteryTwister: Autokey Cipher

`/app/ciphertext.txt` contains a message encrypted with the historical autokey
cipher.

The cipher uses `A = 0, B = 1, ..., Z = 25`. For plaintext
`P = p0 p1 ... pn-1`, the key stream is the short secret keyword followed by the
plaintext itself. Encryption is:

```text
c_i = (p_i + z_i) mod 26
```

where `z_i` is the i-th character of `keyword || plaintext`.

Your job:

1. Break the ciphertext.
2. Write the complete plaintext in **uppercase with spaces between words** to
   `/app/answer.txt`.

Hint: the plaintext contains the word `WORLD`.
