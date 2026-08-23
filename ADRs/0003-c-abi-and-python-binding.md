<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0003: C ABI and Python binding

- Status: Accepted
- Date: 2026-07-15
- Scope: UniChecksum

## Decision

The Nim library is the source of truth. A hand-written C ABI
(`src/UniChecksum/c_api.nim`) and a hand-written header
(`include/UniChecksum.h`) expose it to non-Nim callers, built
`--app:staticlib`/`--app:lib --noMain --mm:arc -d:release`. C symbols are
prefixed `unichecksum_`; the library is `libUniChecksum`.

`tests/c` compiles the header against the built library on every CI run, so the
two cannot drift apart silently.

The C ABI never raises. Nim-side preconditions become clamps: a null pointer,
an empty span, or a length no `int` can address leaves the running state
untouched, and an Adler-32 state whose halves are not both below the modulus —
which no sequence of calls to this API can produce — is returned unchanged.
Unwinding a Nim exception across the ABI boundary would be undefined behaviour.

The Python binding is a Cython extension over that same C ABI, shipped as a
self-contained wheel with the native library inside the package.

## Completeness

Every exported Nim routine has a C entry point, with two deliberate exclusions:

- The single-byte `crc32Update`/`crc64Update`/`adler32Update` overloads. A C
  caller reaches the identical operation by passing a span of length one; the
  overload exists for Nim call sites folding a loop by hand.
- The `string` overloads of `crc32`/`crc64`/`adler32`. These are Nim ergonomic
  wrappers over the byte-span form, which is already exposed; C has no
  corresponding type to bind.

The exported constants (`Crc32Polynomial`, `Crc64Polynomial`,
`Adler32Modulus`) are `#define`s in the header rather than functions.

The Python layer exposes the one-shot form of each family with a continuation
argument, which covers streaming without a separate state object: the CRC
output transform is its own inverse, so a previous result is turned back into a
state internally. That is why it carries no `init`/`update`/`final` triple —
the same operations are reachable, in the form a Python caller expects.

The three exported constants are read from the header through Cython rather
than restated in Python, so a change to one cannot leave the other behind.
