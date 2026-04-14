# This file is a part of Julia. License is MIT: https://julialang.org/license

# Sentinel values for the decode table.
const BASE62_CODE_IGN = 0xfe   # whitespace / ignored characters
const BASE62_CODE_INV = 0xff   # invalid characters

# Generate decode table: maps byte value → base62 digit (0–61), or sentinel.
const BASE62_DECODE = fill(BASE62_CODE_INV, 256)
for (i, c) in enumerate(BASE62_ALPHABET)
    BASE62_DECODE[Int(c) + 1] = UInt8(i - 1)
end
# Mark whitespace as ignored (matches Base64 behavior: RFC 4648 §3.3).
for c in (UInt8('\n'), UInt8('\r'), UInt8('\t'), UInt8(' '))
    BASE62_DECODE[Int(c) + 1] = BASE62_CODE_IGN
end

# Reverse map: base62-string-length → byte-length.
# Built from CHUNK_ENCODED_SIZES; only valid chunk string lengths are keys.
const CHUNK_DECODED_SIZES = Dict{Int,Int}()
for (byte_len, str_len) in enumerate(CHUNK_ENCODED_SIZES)
    CHUNK_DECODED_SIZES[str_len] = byte_len
end
# The maximum encoded chunk length (for CHUNK_SIZE = 32 bytes → 43 chars).
const MAX_ENCODED_CHUNK = CHUNK_ENCODED_SIZES[CHUNK_SIZE]

"""
    _decode_chunk(data::AbstractVector{UInt8}, expected_bytes::Int) -> Vector{UInt8}

Decode a base62-encoded chunk (as raw bytes) into `expected_bytes` bytes.
Throws `ArgumentError` if the data represents a value exceeding `expected_bytes` bytes.
"""
function _decode_chunk(data::AbstractVector{UInt8}, expected_bytes::Int)
    # Convert base62 characters to a big integer, two at a time
    n = BigInt(0)
    i = firstindex(data)
    last = lastindex(data)
    # Collect valid digits, skipping whitespace, validating characters
    # Process pairs for fewer BigInt multiplications
    pending = -1  # -1 = no pending digit
    for idx in i:last
        c = @inbounds data[idx]
        d = @inbounds BASE62_DECODE[c + 1]
        if d == BASE62_CODE_INV
            throw(ArgumentError("invalid base62 character: '$(Char(c))' at byte index $idx"))
        elseif d == BASE62_CODE_IGN
            continue
        end
        if pending >= 0
            # Combine with pending digit: n = n * 62² + pending * 62 + d
            n = n * BASE62_SQUARED + pending * 62 + d
            pending = -1
        else
            pending = Int(d)
        end
    end
    # Handle the leftover odd digit
    if pending >= 0
        n = n * 62 + pending
    end
    # Validate: value must fit in expected_bytes bytes
    if n >= (BigInt(1) << (expected_bytes * 8))
        throw(ArgumentError("invalid base62 data: value exceeds $expected_bytes bytes"))
    end
    # Extract bytes in big-endian order
    result = Vector{UInt8}(undef, expected_bytes)
    for i in expected_bytes:-1:1
        result[i] = UInt8(n & 0xff)
        n >>= 8
    end
    return result
end

"""
    _strip_whitespace(data::AbstractVector{UInt8}) -> Vector{UInt8}

Return a copy of `data` with whitespace bytes removed.
"""
function _strip_whitespace(data::AbstractVector{UInt8})
    return filter(b -> @inbounds(BASE62_DECODE[b + 1]) != BASE62_CODE_IGN, data)
end

"""
    _decode_bytes(data::AbstractVector{UInt8}) -> Vector{UInt8}

Decode a base62-encoded byte vector (with whitespace already stripped) into
the original binary data. The input is split into chunks using the pre-computed
length map `CHUNK_DECODED_SIZES`.
"""
function _decode_bytes(data::AbstractVector{UInt8})
    isempty(data) && return UInt8[]
    io = IOBuffer()
    i = 1
    len = length(data)
    while i <= len
        remaining = len - i + 1
        # Try to consume a full chunk (MAX_ENCODED_CHUNK chars).
        if remaining >= MAX_ENCODED_CHUNK
            chunk_str_len = MAX_ENCODED_CHUNK
        else
            chunk_str_len = remaining
        end
        if !haskey(CHUNK_DECODED_SIZES, chunk_str_len)
            throw(ArgumentError("malformed base62 sequence: invalid encoded length $chunk_str_len"))
        end
        expected_bytes = CHUNK_DECODED_SIZES[chunk_str_len]
        write(io, _decode_chunk(view(data, i:i + chunk_str_len - 1), expected_bytes))
        i += chunk_str_len
    end
    return take!(io)
end

"""
    Base62DecodePipe(istream)

Return a new read-only I/O stream, which decodes base62-encoded data read from
`istream`.

Base62 uses the lexicographic alphabet `0-9A-Za-z` (62 alphanumeric characters).
Note that value 0 maps to `'0'`, not `'A'` as in Base64.

# Examples
```jldoctest
julia> io = IOBuffer("0MbPS3UBt");

julia> iob62_decode = Base62DecodePipe(io);

julia> String(read(iob62_decode))
"Hello!"
```
"""
mutable struct Base62DecodePipe{T<:IO} <: IO
    io::T
    decoded::Vector{UInt8}
    pos::Int
    done::Bool

    function Base62DecodePipe{T}(io::T) where {T<:IO}
        return new{T}(io, UInt8[], 1, false)
    end
end

Base62DecodePipe(io::IO) = Base62DecodePipe{typeof(io)}(io)

Base.isreadable(pipe::Base62DecodePipe) = !pipe.done || pipe.pos <= length(pipe.decoded)
Base.iswritable(::Base62DecodePipe) = false

# Lazily decode all data from the source stream on first access.
function _ensure_decoded!(pipe::Base62DecodePipe)
    if !pipe.done
        raw = read(pipe.io)
        stripped = _strip_whitespace(raw)
        pipe.decoded = _decode_bytes(stripped)
        pipe.pos = 1
        pipe.done = true
    end
    return nothing
end

function Base.eof(pipe::Base62DecodePipe)
    _ensure_decoded!(pipe)
    return pipe.pos > length(pipe.decoded)
end

function Base.read(pipe::Base62DecodePipe, ::Type{UInt8})
    _ensure_decoded!(pipe)
    if pipe.pos > length(pipe.decoded)
        throw(EOFError())
    end
    b = pipe.decoded[pipe.pos]
    pipe.pos += 1
    return b
end

function Base.unsafe_read(pipe::Base62DecodePipe, ptr::Ptr{UInt8}, n::UInt)
    _ensure_decoded!(pipe)
    avail = length(pipe.decoded) - pipe.pos + 1
    if n > avail
        # Copy what we have, then throw
        if avail > 0
            unsafe_copyto!(ptr, pointer(pipe.decoded, pipe.pos), avail)
            pipe.pos += avail
        end
        throw(EOFError())
    end
    unsafe_copyto!(ptr, pointer(pipe.decoded, pipe.pos), n)
    pipe.pos += n
    return nothing
end

function Base.readbytes!(pipe::Base62DecodePipe, data::AbstractVector{UInt8}, nb::Integer=length(data))
    _ensure_decoded!(pipe)
    avail = length(pipe.decoded) - pipe.pos + 1
    n = min(nb, avail)
    if n > length(data)
        resize!(data, n)
    end
    copyto!(data, 1, pipe.decoded, pipe.pos, n)
    pipe.pos += n
    return n
end

Base.close(::Base62DecodePipe) = nothing

"""
    base62decode(string)

Decode the base62-encoded `string` and return a `Vector{UInt8}` of the decoded
bytes.

Base62 uses the lexicographic alphabet `0-9A-Za-z` (62 alphanumeric characters).
Note that value 0 maps to `'0'`, not `'A'` as in Base64.

See also [`base62encode`](@ref).

# Examples
```jldoctest
julia> b = base62decode("0MbPS3UBt")
6-element Vector{UInt8}:
 0x48
 0x65
 0x6c
 0x6c
 0x6f
 0x21

julia> String(b)
"Hello!"
```
"""
function base62decode(s)
    b = IOBuffer(s)
    try
        return read(Base62DecodePipe(b))
    finally
        close(b)
    end
end
