# This file is a part of Julia. License is MIT: https://julialang.org/license

# Base62 alphabet in lexicographic (ASCII) order: 0-9 A-Z a-z
# Note: value 0 maps to '0', not 'A' as in Base64.
const BASE62_ALPHABET = UInt8[
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
    'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
    'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd',
    'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
    'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x',
    'y', 'z',
]

# Default chunk size in bytes (design point from petersmagnusson/base62).
# 32 bytes (256 bits) → 43 base62 characters, same length as base64.
const CHUNK_SIZE = 32

# Pre-computed map: byte-length (1..CHUNK_SIZE) → base62-string-length.
# CHUNK_ENCODED_SIZES[n] = ceil(n * 8 / log2(62))
const CHUNK_ENCODED_SIZES = Int[
     2,  3,  5,  6,  7,  9, 10, 11, 13, 14,
    15, 17, 18, 19, 21, 22, 23, 25, 26, 27,
    29, 30, 31, 33, 34, 35, 37, 38, 39, 41,
    42, 43,
]

# Pre-computed pairs table for two-at-a-time encoding.
# ENCODE_PAIRS[i*62 + j + 1] gives the two-byte encoding of digits (i, j).
# This halves the number of BigInt divisions per chunk.
const BASE62_SQUARED = 62 * 62  # 3844
const ENCODE_PAIRS = let
    pairs = Matrix{UInt8}(undef, 2, BASE62_SQUARED)
    for i in 0:61, j in 0:61
        idx = i * 62 + j + 1
        pairs[1, idx] = BASE62_ALPHABET[i + 1]
        pairs[2, idx] = BASE62_ALPHABET[j + 1]
    end
    pairs
end

"""
    _encode_chunk(data::AbstractVector{UInt8}) -> String

Encode a chunk of up to $CHUNK_SIZE bytes into a base62 string. The output
is zero-padded (with `'0'`) to the deterministic length for the given input
byte count.
"""
function _encode_chunk(data::AbstractVector{UInt8})
    isempty(data) && return ""
    # Convert bytes to a big integer (big-endian)
    n = BigInt(0)
    for b in data
        n = (n << 8) | b
    end
    # Pre-allocate output buffer filled with '0' (zero-pad)
    expected_len = CHUNK_ENCODED_SIZES[length(data)]
    result = fill(UInt8('0'), expected_len)
    # Extract base62 digits right-to-left, two at a time
    pos = expected_len
    while n > 0 && pos >= 2
        n, r = divrem(n, BASE62_SQUARED)
        r_int = Int(r)
        @inbounds result[pos]     = ENCODE_PAIRS[2, r_int + 1]
        @inbounds result[pos - 1] = ENCODE_PAIRS[1, r_int + 1]
        pos -= 2
    end
    # Handle a possible remaining odd digit
    if n > 0
        n, r = divrem(n, 62)
        @inbounds result[pos] = BASE62_ALPHABET[Int(r) + 1]
    end
    return String(result)
end

"""
    _encode_bytes(data::AbstractVector{UInt8}) -> String

Encode an arbitrary byte vector into a base62 string by splitting into
$CHUNK_SIZE-byte chunks.
"""
function _encode_bytes(data::AbstractVector{UInt8})
    isempty(data) && return ""
    io = IOBuffer()
    i = 1
    len = length(data)
    while i <= len
        chunk_end = min(i + CHUNK_SIZE - 1, len)
        write(io, _encode_chunk(view(data, i:chunk_end)))
        i = chunk_end + 1
    end
    return String(take!(io))
end

"""
    Base62EncodePipe(ostream)

Return a new write-only I/O stream, which converts any bytes written to it into
base62-encoded ASCII bytes written to `ostream`. Calling [`close`](@ref) on the
`Base62EncodePipe` stream is necessary to complete the encoding (but does not
close `ostream`).

Base62 uses the lexicographic alphabet `0-9A-Za-z` (62 alphanumeric characters).
Note that value 0 maps to `'0'`, not `'A'` as in Base64.

# Examples
```jldoctest
julia> io = IOBuffer();

julia> iob62_encode = Base62EncodePipe(io);

julia> write(iob62_encode, "Hello!")
6

julia> close(iob62_encode);

julia> str = String(take!(io))
"0MbPS3UBt"

julia> String(base62decode(str))
"Hello!"
```
"""
struct Base62EncodePipe{T<:IO} <: IO
    io::T
    buffer::IOBuffer

    function Base62EncodePipe{T}(io::T) where {T<:IO}
        return new{T}(io, IOBuffer())
    end
end

Base62EncodePipe(io::IO) = Base62EncodePipe{typeof(io)}(io)

Base.isreadable(::Base62EncodePipe) = false
Base.iswritable(pipe::Base62EncodePipe) = isopen(pipe.buffer)

function Base.unsafe_write(pipe::Base62EncodePipe, ptr::Ptr{UInt8}, n::UInt)::Int
    return unsafe_write(pipe.buffer, ptr, n)
end

function Base.write(pipe::Base62EncodePipe, x::UInt8)
    return write(pipe.buffer, x)
end

function Base.close(pipe::Base62EncodePipe)
    data = take!(pipe.buffer)
    if !isempty(data)
        write(pipe.io, _encode_bytes(data))
    end
    return nothing
end

"""
    base62encode(writefunc, args...; context=nothing)
    base62encode(args...; context=nothing)

Given a [`write`](@ref)-like function `writefunc`, which takes an I/O stream as
its first argument, `base62encode(writefunc, args...)` calls `writefunc` to
write `args...` to a base62-encoded string, and returns the string.
`base62encode(args...)` is equivalent to `base62encode(write, args...)`: it
converts its arguments into bytes using the standard [`write`](@ref) functions
and returns the base62-encoded string.

The optional keyword argument `context` can be set to a `:key=>value` pair
or an `IO` or [`IOContext`](@ref) object whose attributes are used for the I/O
stream passed to `writefunc` or `write`.

Base62 uses the lexicographic alphabet `0-9A-Za-z` (62 alphanumeric characters).
Note that value 0 maps to `'0'`, not `'A'` as in Base64.

See also [`base62decode`](@ref).

# Examples
```jldoctest
julia> base62encode("Hello!")
"0MbPS3UBt"

julia> base62encode(UInt8[0x01, 0x02, 0x03])
"00HBL"

julia> base62encode(io -> print(io, "Hello!"))
"0MbPS3UBt"
```
"""
function base62encode(f::Function, args...; context=nothing)
    s = IOBuffer()
    b = Base62EncodePipe(s)
    if context === nothing
        f(b, args...)
    else
        f(IOContext(b, context), args...)
    end
    close(b)
    return String(take!(s))
end
base62encode(args...; context=nothing) = base62encode(write, args...; context=context)
