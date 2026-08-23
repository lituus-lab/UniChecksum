# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## C ABI for UniChecksum. Built --app:staticlib/--app:lib --noMain --mm:arc -d:release.
## Keep in sync with include/UniChecksum.h; tests/c links the header against this lib.
import ../UniChecksum

const UniChecksumVersionC: cstring = "0.1.0"

template foldSpan(state, data, length, updater: untyped): untyped =
  ## Never raises: a null pointer, an empty span, or a length no `int` can
  ## address leaves the state untouched.
  if data.isNil or length == 0 or length > csize_t(high(int)):
    state
  else:
    let bytes = cast[ptr UncheckedArray[byte]](data)
    updater(state, bytes.toOpenArray(0, int(length) - 1))

# Unmangled C symbols, C calling convention, exported from the shared lib.
{.push exportc, cdecl, dynlib.}

proc unichecksum_crc32_init(): uint32 =
  ## Starting CRC-32 state.
  crc32Init()

proc unichecksum_crc32_update(state: uint32, data: ptr uint8,
    length: csize_t): uint32 =
  ## Fold `length` bytes into a running CRC-32 state.
  foldSpan(state, data, length, crc32Update)

proc unichecksum_crc32_final(state: uint32): uint32 =
  ## Output transform turning a CRC-32 state into a checksum.
  crc32Final(state)

proc unichecksum_crc32(data: ptr uint8, length: csize_t): uint32 =
  ## CRC-32 of a whole span. Null or empty input is 0.
  crc32Final(foldSpan(crc32Init(), data, length, crc32Update))

proc unichecksum_crc64_init(): uint64 =
  ## Starting CRC-64/XZ state.
  crc64Init()

proc unichecksum_crc64_update(state: uint64, data: ptr uint8,
    length: csize_t): uint64 =
  ## Fold `length` bytes into a running CRC-64/XZ state.
  foldSpan(state, data, length, crc64Update)

proc unichecksum_crc64_final(state: uint64): uint64 =
  ## Output transform turning a CRC-64/XZ state into a checksum.
  crc64Final(state)

proc unichecksum_crc64(data: ptr uint8, length: csize_t): uint64 =
  ## CRC-64/XZ of a whole span. Null or empty input is 0.
  crc64Final(foldSpan(crc64Init(), data, length, crc64Update))

proc unichecksum_adler32_init(): uint32 =
  ## Starting Adler-32 state.
  adler32Init()

proc unichecksum_adler32_update(state: uint32, data: ptr uint8,
    length: csize_t): uint32 =
  ## Fold `length` bytes into a running Adler-32 state. A state whose halves
  ## are not both below the modulus is rejected: it cannot come from this API.
  if (state and 0xFFFF'u32) >= Adler32Modulus or (state shr 16) >= Adler32Modulus:
    return state
  foldSpan(state, data, length, adler32Update)

proc unichecksum_adler32_final(state: uint32): uint32 =
  ## Identity, kept so all three families share one Init/Update/Final shape.
  adler32Final(state)

proc unichecksum_adler32(data: ptr uint8, length: csize_t): uint32 =
  ## Adler-32 of a whole span. Null or empty input is 1.
  adler32Final(foldSpan(adler32Init(), data, length, adler32Update))

proc unichecksum_version(): cstring =
  ## Static version string; do not free.
  UniChecksumVersionC

{.pop.}
