# MysteryTwister: Merkle-Hellman Knapsack — Part 1

`/app/knapsack_part1_add.txt` contains a symmetric Merkle-Hellman knapsack `K`
and a ciphertext `C`.

The plaintext was converted to ASCII decimal codes, the decimal codes were
concatenated into one decimal number `M`, and `M` was represented as a binary
number `B` of length `lambda = 179`. Each bit of `B` selects the corresponding
element of `K`; the selected elements were summed to produce `C`.

The knapsack has a special structure that makes this subset-sum instance easy
to solve.

Your job:

1. Recover the binary representation and the original plaintext.
2. Write the plaintext with its **exact spaces and punctuation** to
   `/app/answer.txt`.
