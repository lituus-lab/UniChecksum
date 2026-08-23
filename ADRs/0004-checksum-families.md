<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0004: Which checksums, and with which parameters

- Status: Accepted
- Date: 2026-07-15
- Scope: UniChecksum

## Decision

Three families, each pinned to the parameters its consuming format mandates:

| Family | Polynomial (reflected) | Init | Final | Used by |
|---|---|---|---|---|
| CRC-32 | `0xEDB88320` (IEEE 802.3) | all ones | invert | zlib, PNG, gzip, ZIP |
| CRC-64/XZ | `0xC96C5795D7870F42` (ECMA-182) | all ones | invert | the `.xz` container |
| Adler-32 | — (two sums mod 65521) | `a=1, b=0` | identity | the zlib stream trailer |

A CRC is defined by more than its polynomial: bit ordering, initial value and
output transform all change the result. The published check value for
`"123456789"` pins all of them at once, and both CRC families assert theirs in
the test suite for exactly that reason.

These are error-detecting codes, not hashes. They catch accidental corruption;
an attacker who can rewrite the data can rewrite the checksum to match.
Anything needing collision resistance belongs behind a cryptographic primitive,
not here.

## Implementation

Both CRCs are byte-at-a-time table lookups, with the 256-entry table built by a
`const` initializer so it is computed by the compiler rather than at startup.

Adler-32 defers its modulo: up to 5552 bytes are summed before either half is
reduced, 5552 being the largest count for which neither half can overflow 32
bits in between. The two paths are cross-checked against each other in the test
suite, since a wrong bound would only show on inputs longer than one chunk.

## Alternatives considered

A slicing-by-8 CRC was rejected for now: it multiplies the table size by eight
and complicates the endianness story, and no consumer has reported the
byte-at-a-time loop as a bottleneck. Revisit with a benchmark, not by analogy.

Adler-32 could have been left out, since it is weaker than a CRC of the same
width. It stays because the zlib stream format mandates it — a consumer
verifying a zlib trailer has no choice in the matter.
