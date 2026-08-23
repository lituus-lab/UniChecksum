# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## CRC-64/XZ (ECMA-182 polynomial, reflected, all-ones initial and final
## value): the 64-bit check the .xz container carries. Same table-driven shape
## as CRC-32, one byte per step.
const
  Crc64Polynomial* = 0xC96C5795D7870F42'u64
    ## ECMA-182 polynomial in reflected form (0x42F0E1EBA9EA3693 bit-reversed).

func buildTable(): array[256, uint64] =
  # Evaluated by the compiler: the table is a constant, not startup work.
  for index in 0 ..< 256:
    var value = uint64(index)
    for _ in 0 ..< 8:
      value =
        if (value and 1'u64) != 0'u64: Crc64Polynomial xor (value shr 1)
        else: value shr 1
    result[index] = value

const Crc64Table = buildTable()

func crc64Init*(): uint64 {.inline.} =
  ## Starting state, before any byte is folded in.
  0xFFFFFFFFFFFFFFFF'u64

func crc64Update*(state: uint64, b: byte): uint64 {.inline.} =
  ## Fold one byte into the running state.
  Crc64Table[(state xor uint64(b)) and 0xFF'u64] xor (state shr 8)

func crc64Update*(state: uint64, data: openArray[byte]): uint64 =
  ## Fold a span into the running state.
  result = state
  for b in data:
    result = crc64Update(result, b)

func crc64Final*(state: uint64): uint64 {.inline.} =
  ## Apply the output transform. A state is not a checksum until this runs.
  state xor 0xFFFFFFFFFFFFFFFF'u64

func crc64*(data: openArray[byte]): uint64 =
  ## CRC-64/XZ of a whole span. Empty input is 0.
  crc64Final(crc64Update(crc64Init(), data))

func crc64*(s: string): uint64 =
  ## CRC-64/XZ over a string's bytes, no encoding assumed.
  crc64(s.toOpenArrayByte(0, s.high))

