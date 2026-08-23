# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib
import std/strutils

nbInit
nb.title = "UniChecksum"

nbText: """
# UniChecksum

Three checksums that container formats rely on to notice corruption: **CRC-32**
(zlib, PNG, gzip, ZIP), **CRC-64/XZ** (the `.xz` container), and **Adler-32**
(the zlib stream trailer). None of them is a cryptographic hash: they detect
accidental damage — a flipped bit, a truncated transfer — and an attacker who
can rewrite the data can always rewrite the checksum to match.

This page is a nimib book: every Nim block below is compiled and run when the
book is built, and the output shown is what the code actually produced. A
change that breaks the API breaks the docs build, so the two cannot drift.

## One call for a whole buffer

The umbrella module re-exports all three families. Each takes a byte span, or a
string when that reads better.
"""

nbCode:
  import UniChecksum

  echo "version ", UniChecksumVersion
  echo "crc32   ", crc32("123456789").toHex(8)
  echo "crc64   ", crc64("123456789").toHex(16)
  echo "adler32 ", adler32("123456789").toHex(8)

nbText: """
`"123456789"` is the input every CRC catalogue publishes a check value for, which
is what makes it the first thing to try against a new implementation: CRC-32
must give `CBF43926` and CRC-64/XZ must give `995DC9BBDF1939FA`. Getting those
two right pins down the polynomial, the bit ordering, and both the initial and
final values at once.

## Empty input is not zero for Adler-32

The three families disagree on the empty span, and the disagreement is not an
accident of implementation — it falls out of each definition.
"""

nbCode:
  let nothing: seq[byte] = @[]
  echo "crc32   ", crc32(nothing).toHex(8)
  echo "crc64   ", crc64(nothing).toHex(16)
  echo "adler32 ", adler32(nothing).toHex(8)

nbText: """
A CRC starts at all-ones and ends by inverting, so with nothing folded in
between the two cancel and the result is zero. Adler-32 starts its low half at
one and never transforms its output, so the empty span keeps that one. Treating
"checksum is zero" as "no checksum computed" is therefore safe for the CRCs and
wrong for Adler-32.

## Streaming, when the data does not fit in one span

Every family has the same three-step shape: `Init` for the starting state,
`Update` to fold bytes in, `Final` to turn a state into a checksum. Splitting
the input changes nothing about the result.
"""

nbCode:
  var state = crc32Init()
  state = crc32Update(state, "12345".toOpenArrayByte(0, 4))
  state = crc32Update(state, "6789".toOpenArrayByte(0, 3))
  echo "streamed ", crc32Final(state).toHex(8)
  echo "one-shot ", crc32("123456789").toHex(8)

nbText: """
The distinction between a state and a checksum matters: a running state is not
a valid checksum until `Final` has run, and folding more bytes into an already
finalized value gives nonsense. `crc32Final` happens to be its own inverse — it
is a single XOR — so a finalized value can be turned back into a state when a
caller wants to resume, which is how the Python binding accepts a previous
result as a starting point.

## What Adler-32 gives up

Adler-32 is two running sums modulo 65521 rather than a polynomial division.
What it gives up is detection strength, and that shows up most on short inputs,
where the two sums have barely moved apart.
"""

nbCode:
  # Two short inputs one byte apart in one position.
  echo "adler32(\"ab\") ", adler32("ab").toHex(8)
  echo "adler32(\"ac\") ", adler32("ac").toHex(8)
  echo "crc32(\"ab\")   ", crc32("ab").toHex(8)
  echo "crc32(\"ac\")   ", crc32("ac").toHex(8)

nbText: """
Both change, but only one of them changes predictably. Raising an input byte by
one raises the low half by one, and the high half by one along with it, so the
packed Adler-32 value moves by exactly `0x00010001`. The two CRC-32 results
share nothing.
zlib accepts that trade: its Adler-32 covers the whole uncompressed stream at
once, so it only has to catch damage somewhere in a large body. PNG validates
each chunk on its own, often just a few bytes, and uses a CRC-32 for it.

The reduction modulo 65521 is deferred rather than done per byte: up to 5552
bytes are summed before either half is reduced, which is the largest number
that cannot overflow 32 bits along the way. Both halves stay below the modulus
at every point a caller can observe.
"""

nbCode:
  var data = newSeq[byte](20000)
  for i in 0 ..< data.len:
    data[i] = byte((i * 7 + 3) mod 251)
  let packed = adler32(data)
  echo "low  half ", packed and 0xFFFF'u32, " < ", Adler32Modulus
  echo "high half ", packed shr 16, " < ", Adler32Modulus

nbText: """
## The C ABI

The same three families, reachable from anything that speaks C. The header is
hand-written and kept in sync with `src/UniChecksum/c_api.nim`; `tests/c` links
one against the other on every CI run, so a drift is caught rather than shipped.

```c
uint32_t unichecksum_crc32(const uint8_t *data, size_t length);
uint32_t unichecksum_crc32_init(void);
uint32_t unichecksum_crc32_update(uint32_t state, const uint8_t *data, size_t length);
uint32_t unichecksum_crc32_final(uint32_t state);
```

The C ABI **never raises**. Where the Nim side has a precondition, the C entry
point clamps: a null pointer or an empty span leaves the running state
untouched rather than unwinding across the ABI boundary, which would be
undefined behaviour.

```c
unichecksum_crc32(NULL, 8);                     /* 0     — nothing was read */
unichecksum_crc32_update(state, NULL, 8);       /* state — unchanged */
```

## The Python surface

A Cython extension over the C ABI, shipped as a self-contained wheel: the
library travels inside the package, so installing it needs neither Nim nor a
compiler.

```python
import unichecksum

unichecksum.crc32(b"123456789")    # 0xCBF43926
unichecksum.adler32(b"123456789")  # 0x091E01DE
```

The second argument continues an earlier result, matching `zlib.crc32`, so
`crc32(b, crc32(a))` equals `crc32(a + b)`. Any bytes-like object is accepted
and a contiguous one is read without being copied; a strided memoryview, which
cannot be read in place, is copied once instead.

`py/notebooks/quickstart.ipynb` runs these calls against an installed wheel and
renders on GitHub directly.

## References

- [Cyclic redundancy check](https://en.wikipedia.org/wiki/Cyclic_redundancy_check)
  — the polynomial-division construction and the reflected/initial/final
  parameters that distinguish one CRC from another.
- [Adler-32](https://en.wikipedia.org/wiki/Adler-32) — the two-sum construction
  and its weakness on short messages.
- [RFC 1950](https://www.rfc-editor.org/rfc/rfc1950), section 9 — the normative
  Adler-32 definition, including the reference implementation zlib ships.
- [ECMA-182](https://ecma-international.org/publications-and-standards/standards/ecma-182/),
  annex B — the 64-bit polynomial CRC-64/XZ uses.
- [PNG specification](https://www.w3.org/TR/png/#5CRC-algorithm), section 5 —
  CRC-32 as a chunk integrity check, with the same parameters used here.
- Philip Koopman, [CRC catalogue](https://users.ece.cmu.edu/~koopman/crc/) —
  published check values and detection properties per polynomial.
"""

nbSave
