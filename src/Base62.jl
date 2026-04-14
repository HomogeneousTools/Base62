# This file is a part of Julia. License is MIT: https://julialang.org/license

"""
    Base62

Functionality for base62 encoding and decoding of binary data using the
alphanumeric characters `0-9`, `A-Z`, and `a-z`.

Unlike Base64, Base62 uses only the 62 alphanumeric characters in lexicographic
(ASCII) order: `0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz`.
Note that value 0 maps to the character `'0'`, not `'A'` as in Base64.

Base62 encoding uses big-integer arithmetic with 32-byte chunking to produce
deterministic-length output: the encoded length depends only on the input byte
length, not its contents. There is no padding character.
"""
module Base62

export
    Base62EncodePipe,
    base62encode,
    Base62DecodePipe,
    base62decode

# Base62EncodePipe is a pipe-like IO object, which converts into base62 data
# sent to a stream. (You must close the pipe to complete the encode, separate
# from closing the target stream).  We also have a function base62encode(f,
# args...) which works like sprint except that it produces base62-encoded data,
# along with base62encode(args...) which is equivalent to base62encode(write,
# args...), to return base62 strings.  A Base62DecodePipe object can be used to
# decode base62-encoded data read from a stream, while function base62decode is
# useful for decoding strings.

include("encode.jl")
include("decode.jl")

end
