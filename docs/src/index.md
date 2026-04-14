```@meta
EditURL = "https://github.com/JuliaLang/julia/blob/master/stdlib/Base62/docs/src/index.md"
```

# Base62

The Base62 module implements encoding and decoding of binary data using only the
62 alphanumeric characters `0-9`, `A-Z`, and `a-z`.

**Important:** This implementation uses the **lexicographic (ASCII) order** alphabet
`0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz`, where **value 0
maps to the character `'0'`**, not `'A'` as in Base64. This is sometimes called
the "ASCII-ordered" or "lex-ordered" variant. Other Base62 implementations may use
different orderings (e.g., `A-Za-z0-9` to align with Base64, or `0-9a-zA-Z`).

Unlike Base64, Base62 does not use any padding characters (no `=`), and does not
use non-alphanumeric symbols (no `+`, `/`, `-`, or `_`). This makes Base62 encoded
strings safe for use in URLs, filenames, identifiers, and any context where only
alphanumeric characters are permitted — without any escaping.

The encoding uses big-integer arithmetic with 32-byte chunking. Each chunk of up
to 32 bytes is converted to a big integer and then encoded via repeated division
by 62. Chunks are zero-padded (with `'0'`) so that the output length is
**deterministic**: it depends only on the input byte length, never on the content.
This ensures that `length(base62encode(data))` is constant for all `data` of a
given length.

Whitespace characters (spaces, tabs, newlines) are ignored when decoding, matching
the behavior of Base64 decoders per RFC 4648 §3.3.

The following alphabet is used:

| Value | Char | Value | Char | Value | Char | Value | Char |
| -----:|:---- | -----:|:---- | -----:|:---- | -----:|:---- |
|     0 | `0`  |    16 | `G`  |    32 | `W`  |    48 | `m`  |
|     1 | `1`  |    17 | `H`  |    33 | `X`  |    49 | `n`  |
|     2 | `2`  |    18 | `I`  |    34 | `Y`  |    50 | `o`  |
|     3 | `3`  |    19 | `J`  |    35 | `Z`  |    51 | `p`  |
|     4 | `4`  |    20 | `K`  |    36 | `a`  |    52 | `q`  |
|     5 | `5`  |    21 | `L`  |    37 | `b`  |    53 | `r`  |
|     6 | `6`  |    22 | `M`  |    38 | `c`  |    54 | `s`  |
|     7 | `7`  |    23 | `N`  |    55 | `t`  |    39 | `d`  |
|     8 | `8`  |    24 | `O`  |    40 | `e`  |    56 | `u`  |
|     9 | `9`  |    25 | `P`  |    41 | `f`  |    57 | `v`  |
|    10 | `A`  |    26 | `Q`  |    42 | `g`  |    58 | `w`  |
|    11 | `B`  |    27 | `R`  |    43 | `h`  |    59 | `x`  |
|    12 | `C`  |    28 | `S`  |    44 | `i`  |    60 | `y`  |
|    13 | `D`  |    29 | `T`  |    45 | `j`  |    61 | `z`  |
|    14 | `E`  |    30 | `U`  |    46 | `k`  |       |      |
|    15 | `F`  |    31 | `V`  |    47 | `l`  |       |      |

## Encoding

```@docs
Base62.Base62EncodePipe
Base62.base62encode
```

## Decoding

```@docs
Base62.Base62DecodePipe
Base62.base62decode
```
