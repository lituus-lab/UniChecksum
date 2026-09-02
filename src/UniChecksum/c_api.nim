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
# --noMain suppresses the generated entry point and with it every auto-init
# hook: neither the static nor the shared build emits a DllMain or an ELF
# constructor, so nothing initializes the Nim runtime. The first entry point
# then enters Nim code whose globals were never set up. The shared build was
# assumed to be covered by a loader hook it does not have -- its registries
# stayed empty and the contrast entry answered nan. Every --noMain task passes
# -d:noAutoInit; an ordinary executable linking this module must not, since its
# own main already ran NimMain.
when defined(noAutoInit):
  # A once primitive, not a plain flag: two threads reaching an entry point
  # together would both see the flag unset, both call NimMain, and the second
  # would enter Nim code the first had not finished initializing. The platform
  # primitives block the losers until the winner returns, which a flag cannot.
  #
  # C statics, not Nim globals: module initialization would reset a Nim one and
  # NimMain would run again. NimMain is declared here too — the generated
  # prototype comes after this section.
  {.emit: """/*VARSECTION*/
void NimMain(void);
#ifdef _WIN32
#  include <windows.h>
static INIT_ONCE unichecksum_runtime_once = INIT_ONCE_STATIC_INIT;
static BOOL CALLBACK unichecksum_runtime_init(PINIT_ONCE o, PVOID p, PVOID *c) {
  (void)o; (void)p; (void)c; NimMain(); return TRUE;
}
static void unichecksum_runtime_ensure(void) {
  InitOnceExecuteOnce(&unichecksum_runtime_once, unichecksum_runtime_init, NULL, NULL);
}
#else
#  include <pthread.h>
static pthread_once_t unichecksum_runtime_once = PTHREAD_ONCE_INIT;
static void unichecksum_runtime_init(void) { NimMain(); }
static void unichecksum_runtime_ensure(void) {
  pthread_once(&unichecksum_runtime_once, unichecksum_runtime_init);
}
#endif
""".}
  template ensureRuntime() =
    {.emit: "  unichecksum_runtime_ensure();".}
else:
  template ensureRuntime() = discard

{.push exportc, cdecl, dynlib, raises: [].}

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
