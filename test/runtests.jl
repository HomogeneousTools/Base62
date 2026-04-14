# This file is a part of Julia. License is MIT: https://julialang.org/license

using Test, Random
using Base62:
    Base62,
    Base62EncodePipe,
    base62encode,
    Base62DecodePipe,
    base62decode

const inputText = "Man is distinguished, not only by his reason, but by this singular passion from other animals, which is a lust of the mind, that by a perseverance of delight in the continued and indefatigable generation of knowledge, exceeds the short vehemence of any carnal pleasure."

@testset "Alphabet" begin
    alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    @test length(alphabet) == 62
    # Verify lexicographic (ASCII) order: 0-9 < A-Z < a-z
    for i in 1:61
        @test alphabet[i] < alphabet[i+1]
    end
    # Value 0 maps to '0', not 'A'
    @test base62encode(UInt8[0x00]) == "00"
    # Value 61 maps to 'z'
    @test Base62.BASE62_ALPHABET[62] == UInt8('z')
    @test Base62.BASE62_ALPHABET[1] == UInt8('0')
end

@testset "Examples" begin
    # Encode and decode via pipes through a file
    fname = tempname()
    open(fname, "w") do f
        opipe = Base62EncodePipe(f)
        write(opipe, inputText)
        @test close(opipe) === nothing
    end

    open(fname, "r") do f
        ipipe = Base62DecodePipe(f)
        @test read(ipipe, String) == inputText
        @test close(ipipe) === nothing
    end
    rm(fname)

    # Byte-by-byte encode and decode.
    buf = IOBuffer()
    pipe = Base62EncodePipe(buf)
    @test !isreadable(pipe) && iswritable(pipe)
    for char in inputText
        write(pipe, UInt8(char))
    end
    close(pipe)
    pipe = Base62DecodePipe(IOBuffer(take!(buf)))
    decoded = UInt8[]
    while !eof(pipe)
        push!(decoded, read(pipe, UInt8))
    end
    @test String(decoded) == inputText

    # Non-writable pipe
    buf = IOBuffer(write=false)
    pipe = Base62EncodePipe(buf)
    @test !isreadable(pipe)

    # Encode to string and decode
    @test String(base62decode(base62encode(inputText))) == inputText
end

@testset "Known values" begin
    # Empty
    @test base62encode(UInt8[]) == ""
    @test base62decode("") == UInt8[]

    # Single bytes
    @test base62encode(UInt8[0x00]) == "00"
    @test base62encode(UInt8[0x01]) == "01"
    @test base62encode(UInt8[0xff]) == "47"

    # Multi-byte
    @test base62encode(UInt8[0x00, 0x00]) == "000"
    @test base62encode(UInt8[0x01, 0x02]) == "04A"
    @test base62encode(UInt8[0x01, 0x02, 0x03]) == "00HBL"
    @test base62encode(UInt8[0x00, 0x00, 0x00, 0x00]) == "000000"

    # Strings
    @test base62encode("Hello!") == "0MbPS3UBt"
    @test base62encode("Hello World!") == "0T8dgcjRGkZ3aysdN"
    @test base62encode("Man") == "0LHFm"

    # Round-trip known values
    @test String(base62decode("0MbPS3UBt")) == "Hello!"
    @test String(base62decode("0T8dgcjRGkZ3aysdN")) == "Hello World!"
    @test base62decode("00") == UInt8[0x00]
    @test base62decode("01") == UInt8[0x01]
    @test base62decode("47") == UInt8[0xff]
end

@testset "Round-trip" begin
    # Various input types
    @test base62decode(base62encode(UInt8[])) == UInt8[]
    @test base62decode(base62encode(UInt8[0x00])) == UInt8[0x00]
    @test base62decode(base62encode(UInt8[0xff])) == UInt8[0xff]
    @test base62decode(base62encode(UInt8[0x00, 0x00, 0x01])) == UInt8[0x00, 0x00, 0x01]
    @test String(base62decode(base62encode(inputText))) == inputText

    # All zeros of various lengths
    for n in [1, 2, 4, 8, 16, 32, 33, 64]
        data = zeros(UInt8, n)
        @test base62decode(base62encode(data)) == data
    end

    # Single values
    for v in 0x00:0xff
        data = UInt8[v]
        @test base62decode(base62encode(data)) == data
    end
end

@testset "Deterministic length" begin
    # The length of base62-encoded output depends only on the input byte length,
    # not on the content (each chunk is zero-padded to its deterministic size).
    mt = MersenneTwister(42)
    for n in [1, 2, 3, 4, 8, 16, 31, 32, 33, 64, 100, 256]
        expected_len = length(base62encode(zeros(UInt8, n)))
        for _ in 1:20
            data = rand(mt, UInt8, n)
            @test length(base62encode(data)) == expected_len
        end
    end

    # Specific known lengths
    @test length(base62encode(zeros(UInt8, 32))) == 43  # same as base64
    @test length(base62encode(zeros(UInt8, 16))) == 22  # same as base64
end

@testset "Chunking" begin
    # Verify multi-chunk data round-trips correctly.
    mt = MersenneTwister(123)
    # 33 bytes = 1 full chunk (32 bytes) + 1 byte
    data = rand(mt, UInt8, 33)
    encoded = base62encode(data)
    @test length(encoded) == 43 + 2  # 43 chars for first chunk + 2 for 1 byte
    @test base62decode(encoded) == data

    # 64 bytes = 2 full chunks
    data = rand(mt, UInt8, 64)
    encoded = base62encode(data)
    @test length(encoded) == 43 * 2
    @test base62decode(encoded) == data

    # 65 bytes = 2 full chunks + 1 byte
    data = rand(mt, UInt8, 65)
    encoded = base62encode(data)
    @test length(encoded) == 43 * 2 + 2
    @test base62decode(encoded) == data

    # Large multi-chunk
    data = rand(mt, UInt8, 100)
    @test base62decode(base62encode(data)) == data
end

@testset "Random data" begin
    mt = MersenneTwister(1234)
    for _ in 1:1000
        data = rand(mt, UInt8, rand(0:300))
        @test hash(base62decode(base62encode(data))) == hash(data)
    end
end

@testset "Large data" begin
    mt = MersenneTwister(5678)
    for n in [1024, 4096]
        data = rand(mt, UInt8, n)
        @test base62decode(base62encode(data)) == data
    end
end

@testset "Whitespace handling" begin
    # Whitespace in encoded strings should be ignored (mirrors Base64 behavior).
    encoded = base62encode("Hello!")
    @test encoded == "0MbPS3UBt"
    # Insert various whitespace
    @test String(base62decode("0MbP S3UBt")) == "Hello!"
    @test String(base62decode("0MbP\nS3UBt")) == "Hello!"
    @test String(base62decode("0MbP\r\nS3UBt")) == "Hello!"
    @test String(base62decode("0MbP\tS3UBt")) == "Hello!"
    @test String(base62decode(" 0MbPS3UBt ")) == "Hello!"

    # Whitespace in multi-chunk data
    mt = MersenneTwister(999)
    data = rand(mt, UInt8, 64)
    enc = base62encode(data)
    # Insert newlines every 20 chars
    spaced = join([enc[i:min(i+19, end)] for i in 1:20:length(enc)], "\n")
    @test base62decode(spaced) == data
end

@testset "Invalid input" begin
    # Non-alphabet characters
    @test_throws ArgumentError base62decode("!@#\$")
    @test_throws ArgumentError base62decode("Hello+World")
    @test_throws ArgumentError base62decode("abc/def")
    @test_throws ArgumentError base62decode("abc=")

    # Verify error message includes context
    try
        base62decode("ab!cd")
    catch e
        @test isa(e, ArgumentError)
        @test occursin("'!'", e.msg)
    end

    # Invalid chunk length: 4 and 8 are not valid base62 encoded chunk sizes
    # (no byte-length maps to 4 or 8 base62 chars)
    @test_throws ArgumentError base62decode("ABCD")
    @test_throws ArgumentError base62decode("ABCDEFGH")

    # Overflow: value too large for the expected byte count.
    # For 1 byte (2 chars), max valid is "47" (0xff = 4*62 + 7 = 255).
    # "48" would decode to 256 which exceeds 1 byte.
    @test_throws ArgumentError base62decode("48")
end

@testset "Docstrings" begin
    @test isempty(Docs.undocumented_names(Base62))
end
