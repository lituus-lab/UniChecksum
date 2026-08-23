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
# A shared library runs NimMain from DllMain (Windows) or an ELF constructor;
# a static one has neither, so nothing initializes the Nim runtime. Anything
# that reads the environment then faults — proven on Windows, where the Python
# extension is the one consumer that links the static build. The static-library
# tasks pass -d:staticNoAutoInit; shared builds must not, or NimMain runs twice.
when defined(staticNoAutoInit):
  # A C static, not a Nim global: module initialization would reset a Nim one
  # back to false and NimMain would run again on the next call. NimMain is
  # declared here too — the generated prototype comes after this section.
  {.emit: """/*VARSECTION*/
void NimMain(void);
static int unichecksum_runtime_ready = 0;
""".}
  template ensureRuntime() =
    {.emit: """
  if (!unichecksum_runtime_ready) { unichecksum_runtime_ready = 1; NimMain(); }
""".}
else:
  template ensureRuntime() = discard

{.push exportc, cdecl, dynlib.}

proc unichecksum_crc32_init(): uint32 =
  ensureRuntime()
  ## Starting CRC-32 state.
  crc32Init()

proc unichecksum_crc32_update(state: uint32, data: ptr uint8,
    length: csize_t): uint32 =
  ensureRuntime()
  ## Fold `length` bytes into a running CRC-32 state.
  foldSpan(state, data, length, crc32Update)

proc unichecksum_crc32_final(state: uint32): uint32 =
  ensureRuntime()
  ## Output transform turning a CRC-32 state into a checksum.
  crc32Final(state)

proc unichecksum_crc32(data: ptr uint8, length: csize_t): uint32 =
  ensureRuntime()
  ## CRC-32 of a whole span. Null or empty input is 0.
  crc32Final(foldSpan(crc32Init(), data, length, crc32Update))

proc unichecksum_crc64_init(): uint64 =
  ensureRuntime()
  ## Starting CRC-64/XZ state.
  crc64Init()

proc unichecksum_crc64_update(state: uint64, data: ptr uint8,
    length: csize_t): uint64 =
  ensureRuntime()
  ## Fold `length` bytes into a running CRC-64/XZ state.
  foldSpan(state, data, length, crc64Update)

proc unichecksum_crc64_final(state: uint64): uint64 =
  ensureRuntime()
  ## Output transform turning a CRC-64/XZ state into a checksum.
  crc64Final(state)

proc unichecksum_crc64(data: ptr uint8, length: csize_t): uint64 =
  ensureRuntime()
  ## CRC-64/XZ of a whole span. Null or empty input is 0.
  crc64Final(foldSpan(crc64Init(), data, length, crc64Update))

proc unichecksum_adler32_init(): uint32 =
  ensureRuntime()
  ## Starting Adler-32 state.
  adler32Init()

proc unichecksum_adler32_update(state: uint32, data: ptr uint8,
    length: csize_t): uint32 =
  ensureRuntime()
  ## Fold `length` bytes into a running Adler-32 state. A state whose halves
  ## are not both below the modulus is rejected: it cannot come from this API.
  if (state and 0xFFFF'u32) >= Adler32Modulus or (state shr 16) >= Adler32Modulus:
    return state
  foldSpan(state, data, length, adler32Update)

proc unichecksum_adler32_final(state: uint32): uint32 =
  ensureRuntime()
  ## Identity, kept so all three families share one Init/Update/Final shape.
  adler32Final(state)

proc unichecksum_adler32(data: ptr uint8, length: csize_t): uint32 =
  ensureRuntime()
  ## Adler-32 of a whole span. Null or empty input is 1.
  adler32Final(foldSpan(adler32Init(), data, length, adler32Update))

proc unichecksum_version(): cstring =
  ensureRuntime()
  ## Static version string; do not free.
  UniChecksumVersionC

{.pop.}
