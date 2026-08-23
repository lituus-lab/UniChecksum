# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## CRC-32 as used by zlib, PNG, gzip and ZIP (IEEE 802.3): reflected input and
## output, initial and final value all-ones. Table-driven, one byte per step.
const
  Crc32Polynomial* = 0xEDB88320'u32
    ## IEEE 802.3 polynomial in reflected form (0x04C11DB7 bit-reversed).

func buildTable(): array[256, uint32] =
  # Evaluated by the compiler: the table is a constant, not startup work.
  for index in 0 ..< 256:
    var value = uint32(index)
    for _ in 0 ..< 8:
      value =
        if (value and 1'u32) != 0'u32: Crc32Polynomial xor (value shr 1)
        else: value shr 1
    result[index] = value

const Crc32Table = buildTable()

func crc32Init*(): uint32 {.inline.} =
  ## Starting state, before any byte is folded in.
  0xFFFFFFFF'u32

func crc32Update*(state: uint32, b: byte): uint32 {.inline.} =
  ## Fold one byte into the running state.
  Crc32Table[(state xor uint32(b)) and 0xFF'u32] xor (state shr 8)

func crc32Update*(state: uint32, data: openArray[byte]): uint32 =
  ## Fold a span into the running state.
  result = state
  for b in data:
    result = crc32Update(result, b)

func crc32Final*(state: uint32): uint32 {.inline.} =
  ## Apply the output transform. A state is not a checksum until this runs.
  state xor 0xFFFFFFFF'u32

func crc32*(data: openArray[byte]): uint32 =
  ## CRC-32 of a whole span. Empty input is 0.
  crc32Final(crc32Update(crc32Init(), data))

func crc32*(s: string): uint32 =
  ## CRC-32 over a string's bytes, no encoding assumed.
  crc32(s.toOpenArrayByte(0, s.high))

