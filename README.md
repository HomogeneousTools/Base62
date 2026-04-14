# Base62.jl

[![CI](https://github.com/HomogeneousTools/Base62.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/HomogeneousTools/Base62.jl/actions/workflows/CI.yml)

A Julia package for Base62 encoding and decoding of binary data, closely
mirroring the API of Julia's standard library
[`Base64`](https://docs.julialang.org/en/v1/stdlib/Base64/).

## Alphabet

Base62 uses the **62 alphanumeric characters** in **lexicographic (ASCII) order**:

```
0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
```

**Important:** Value 0 maps to `'0'`, not `'A'`. This differs from some Base62
implementations that use Base64-compatible ordering (`A-Za-z0-9`). We use
`0-9A-Za-z` — the natural ASCII/lexicographic order.

Unlike Base64, there are **no padding characters** (`=`) and **no special
symbols** (`+`, `/`, `-`, `_`). This makes Base62 strings safe for URLs,
filenames, identifiers, and any context requiring only alphanumerics.

## Algorithm

The encoding uses **big-integer arithmetic with 32-byte chunking** (inspired by
[petersmagnusson/base62](https://github.com/petersmagnusson/base62)):

- Input is split into 32-byte chunks
- Each chunk is converted to a `BigInt` and encoded via repeated division by 62
- Output is zero-padded so that **encoded length is deterministic** — it depends
  only on input byte length, never on content
- 32 bytes → 43 base62 characters (same as Base64!)

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/HomogeneousTools/Base62.jl")
```

Or in the Pkg REPL (`]`):

```
add https://github.com/HomogeneousTools/Base62.jl
```

## Usage

```julia
using Base62

# Encode a string
encoded = base62encode("Hello!")    # "0MbPS3UBt"

# Decode back
decoded = String(base62decode(encoded))  # "Hello!"

# Encode raw bytes
base62encode(UInt8[0x01, 0x02, 0x03])  # "00HBL"

# Pipe-based encoding (mirrors Base64 API)
io = IOBuffer()
pipe = Base62EncodePipe(io)
write(pipe, "Hello World!")
close(pipe)
encoded = String(take!(io))  # "0T8dgcjRGkZ3aysdN"

# Pipe-based decoding
pipe = Base62DecodePipe(IOBuffer(encoded))
result = String(read(pipe))  # "Hello World!"
```

## API Reference

| Function / Type     | Description                                        |
|:-------------------|:---------------------------------------------------|
| `base62encode(x)`  | Encode data to a Base62 string                     |
| `base62decode(s)`  | Decode a Base62 string to `Vector{UInt8}`          |
| `Base62EncodePipe` | Write-only IO pipe that encodes to Base62          |
| `Base62DecodePipe` | Read-only IO pipe that decodes from Base62         |

## Acknowledgments

This implementation was created using **Claude Opus 4.6** by combining ideas from
several existing Base62/Base64 implementations:

- **[Julia Base64 stdlib](https://github.com/JuliaLang/julia/tree/master/stdlib/Base64)** —
  The API design (pipe-based IO with `Base62EncodePipe`/`Base62DecodePipe`,
  `base62encode`/`base62decode` convenience functions) closely mirrors Julia's
  standard library `Base64` module.
- **[petersmagnusson/base62](https://github.com/petersmagnusson/base62)** (TypeScript) —
  The 32-byte chunking strategy and deterministic output length design
  (zero-padded, content-independent) originate from this implementation.
- **[fbernier/base62](https://github.com/fbernier/base62)** (Rust) —
  The two-at-a-time encoding (pre-computed 62×62 pairs table) and
  two-at-a-time decoding optimizations that halve the number of BigInt
  operations per chunk were inspired by this high-performance Rust crate.

## License

MIT
