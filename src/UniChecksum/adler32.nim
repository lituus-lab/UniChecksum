# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Adler-32 (RFC 1950 section 9): two rolling sums modulo 65521, packed as
## `(b shl 16) or a`. Weaker than a CRC on short inputs, which is why zlib
## pairs it with a length field rather than using it alone.
import contracts

const
  Adler32Modulus* = 65521'u32
    ## Largest prime below 2^16, the modulus both halves are reduced by.
  Adler32Chunk = 5552
    ## Bytes summable before a reduction: the largest n with
    ## 255*n*(n+1)/2 + (n+1)*(Adler32Modulus-1) still below 2^32.

func adler32Init*(): uint32 {.inline.} =
  ## Starting state: a = 1, b = 0.
  1'u32

func adler32Update*(state: uint32, b: byte): uint32 {.contractual, inline.} =
  ## Fold one byte into the running state.
  require:
    (state and 0xFFFF'u32) < Adler32Modulus
    (state shr 16) < Adler32Modulus
  ensure:
    (result and 0xFFFF'u32) < Adler32Modulus
    (result shr 16) < Adler32Modulus
  body:
    let low = ((state and 0xFFFF'u32) + uint32(b)) mod Adler32Modulus
    let high = ((state shr 16) + low) mod Adler32Modulus
    (high shl 16) or low

func adler32Update*(state: uint32, data: openArray[
    byte]): uint32 {.contractual.} =
  ## Fold a span into the running state. Reduces once per `Adler32Chunk`
  ## bytes instead of once per byte; both halves stay below 2^32 in between.
  require:
    (state and 0xFFFF'u32) < Adler32Modulus
    (state shr 16) < Adler32Modulus
  ensure:
    (result and 0xFFFF'u32) < Adler32Modulus
    (result shr 16) < Adler32Modulus
  body:
    var
      low = state and 0xFFFF'u32
      high = state shr 16
      index = 0
    while index < data.len:
      # Bound the step, not the endpoint: `index + Adler32Chunk` would
      # overflow `int` on a span whose length sits within a chunk of `high(int)`.
      let stop = index + min(Adler32Chunk, data.len - index)
      while index < stop:
        low += uint32(data[index])
        high += low
        inc index
      low = low mod Adler32Modulus
      high = high mod Adler32Modulus
    (high shl 16) or low

func adler32Final*(state: uint32): uint32 {.inline.} =
  ## Identity: Adler-32 has no output transform. Present so the three
  ## checksum families share one Init/Update/Final shape.
  state

func adler32*(data: openArray[byte]): uint32 =
  ## Adler-32 of a whole span. Empty input is 1.
  adler32Final(adler32Update(adler32Init(), data))

func adler32*(s: string): uint32 =
  ## Adler-32 over a string's bytes, no encoding assumed.
  adler32(s.toOpenArrayByte(0, s.high))

