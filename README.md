<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# UniChecksum

CRC-32, CRC-64/XZ and Adler-32 — the error-detecting codes container formats
carry — in Nim, with a hand-written C ABI and a Cython Python binding.

Layer-1 in the `lituus-lab` `Uni*` family DAG: it depends on no sibling, so the
formats that need a checksum can depend on it without closing a cycle. These
are not cryptographic hashes: they catch accidental corruption, and an attacker
who can rewrite the data can rewrite the checksum to match.

## Quick start

```nim
import std/strutils
import UniChecksum

echo crc32("123456789").toHex(8)     # CBF43926
echo adler32("123456789").toHex(8)   # 091E01DE

var state = crc32Init()              # or fold a stream one piece at a time
state = crc32Update(state, "12345".toOpenArrayByte(0, 4))
state = crc32Update(state, "6789".toOpenArrayByte(0, 3))
echo crc32Final(state).toHex(8)      # CBF43926, same as the one-shot call
```

```c
#include "UniChecksum.h"
unichecksum_crc32((const uint8_t *)"123456789", 9);   /* 0xCBF43926 */
```

```python
import unichecksum
unichecksum.crc32(b"123456789")     # 0xCBF43926
```

See `book/index.nim` (nimib, built into `book/index.html`) for the full
walkthrough with references, and `py/notebooks/quickstart.ipynb` for the Python
side.

## What's inside

- **CRC-32** (`crc32.nim`) — the IEEE 802.3 polynomial in reflected form, as
  used by zlib, PNG, gzip and ZIP. One-shot `crc32`, plus
  `crc32Init`/`crc32Update`/`crc32Final` for data arriving in pieces.
- **CRC-64/XZ** (`crc64.nim`) — the ECMA-182 polynomial, the 64-bit check the
  `.xz` container carries. Same one-shot and streaming shape.
- **Adler-32** (`adler32.nim`) — the RFC 1950 pair of sums modulo 65521 that
  closes a zlib stream. Weaker than a CRC on short inputs; the reduction is
  deferred by up to 5552 bytes, the largest count that cannot overflow along
  the way.

Every family folds byte spans and returns an unsigned integer. Nothing here
allocates, and nothing here raises outside a debug-build contract violation.

## The Uni* family

UniChecksum is layer 1 of `lituus-lab`'s `Uni*` family: a set of Nim libraries,
each with a C ABI and a Python binding, unified by a shared dependency DAG and
documentation/testing conventions. See
[lituus-lab/.github](https://github.com/lituus-lab/.github) for the family's
purpose and philosophy. UniChecksum depends on nothing else in the family; it
exists so that the libraries handling container formats — UniCompress for zlib
and DEFLATE, UniArchive for ZIP, UniImage for PNG — share one verified
implementation of the checks those formats mandate, instead of each carrying
its own copy.

## Provenance & development

The three algorithms are standard and fully specified elsewhere: the CRC
construction and its parameters come from the published catalogues, Adler-32
from RFC 1950 section 9. There is no original work in the numerics, and the
test suite checks against the check values those sources publish, with
CPython's `zlib` as an independent oracle for CRC-32 and Adler-32.

Development used LLM/agent assistance extensively, on the terms described
below. One visible consequence: this repo's git history is short and linear,
with commits landing close together in time — that reflects an LLM/agent
writing pass over an already-specified design, not the algorithms being
invented at that speed.

## Layout

```text
src/UniChecksum.nim          umbrella module
src/UniChecksum/crc32.nim    CRC-32 (IEEE 802.3)
src/UniChecksum/crc64.nim    CRC-64/XZ (ECMA-182)
src/UniChecksum/adler32.nim  Adler-32 (RFC 1950, NimContracts)
src/UniChecksum/c_api.nim    C ABI
include/UniChecksum.h        hand-written C header
tests/test_*.nim             Nim tests (crc32, crc64, adler32, umbrella API)
tests/c/                     C ABI test (links the header against the lib)
examples/                    Nim + C demos
py/                          Cython binding + pytest
ADRs/                        0001 no sibling deps, 0002 license, 0003 C ABI & Python, 0004 checksum families
.github/workflows/ci.yml     3-OS Nim matrix + C ABI + Python
```

## Build

```bash
nimble install -y
nimble test           # Nim, debug (contracts active)
nimble testRelease    # Nim, release (contracts compiled away)
nimble testAll        # debug + release + C ABI
nimble ctest          # C ABI: static lib + tests/c
nimble cexample       # C demo
nimble example        # Nim demo
nimble pyTest         # Cython + pytest
nimble lint           # nimpretty check
nimble checkVGraph    # import-direction check
nimble coverage       # gcov + lcov -> coverage/
nimble book           # nimib book -> book/index.html
nimble docs           # book + API reference -> pages/
```

## CI

`test`, `cabi` and `python` on ubuntu/macOS/Windows. `consume-cabi` and
`consume-wheel` rebuild against the published artifacts on a machine without Nim,
so what ships is what was tested. `coverage` and `docs` run on ubuntu.

`dco` blocks PRs missing a `Signed-off-by` trailer; `commitizen` blocks PRs whose
commits or title are not [Conventional Commits](https://www.conventionalcommits.org/)
(`CONTRIBUTING.md`).

The same gates run locally with pre-commit:
`pip install pre-commit && pre-commit install`
(`CONTRIBUTING.md`).

`docs` publishes to GitHub Pages — skipped on push to a fork or while the repo
is private, on by default once public on `main`.

## AI-assisted contributions

Assistance from AI/LLM tools is welcome on the same terms as any other
contribution.

- **Accountability.** The human contributor is the author and remains fully
  responsible for the change. The DCO sign-off (`Signed-off-by`) is the mechanism:
  by signing you certify the content is yours or properly licensed — this covers
  AI-assisted work, provided you can stand behind it.
- **No third-party contamination.** Ensure AI output introduces no code from a
  third party without a compatible license and attribution. If an LLM reproduced
  protected material, do not submit it.
- **Correctness is yours.** The gates (tests, `nimble lint`, conventional commits,
  pre-commit) catch a lot, but you own the result — review and verify what you
  commit.
- **Atomic commits.** Each commit is one logical change. A PR may stack
  several atomic commits (one per element, say) — one monolithic big-bang
  commit is not.
- **Disclosure.** State in the PR whether AI assistance was used (see the PR
  template). It is not a hard requirement — the DCO remains the gate.

## License

Apache-2.0 (`LICENSE`). DCO sign-off on every commit (`CONTRIBUTING.md`).
