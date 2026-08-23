<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# AGENTS.md — UniChecksum

## Build & gates

```bash
nimble install -y
nimble testAll    # Nim debug + release + C ABI
nimble pyTest     # Cython + pytest (needs libUniChecksum.so)
nimble example
nimble lint       # nimpretty check
nimble checkVGraph
nimble coverage   # gcov + lcov -> coverage/ (needs lcov; linux/macOS)
nimble docs       # nimib book + API reference -> pages/ (needs nimib)
```

`nimble docs` needs a complete Nim distribution: `--project` builds `dochack`,
which Homebrew's `nim` omits (no `tools/`). choosenim and the CI action ship it.

CI: 3-OS Nim matrix + C ABI (linux/macOS) + Python.

## Conventions

- English comments, terse, describe what is done. No "deprecated".
- NimContracts `{.contractual.}` + `require:`/`ensure:`/`body:`, compiled away
  under `-d:release`. Used where a state carries a real invariant: Adler-32's
  two halves are each below the modulus. CRC states carry none — every bit
  pattern is reachable — so those functions state no contract rather than
  decorating one.
- A postcondition is cheaper than the body: never re-derives the result by
  calling the function itself.
- C ABI never raises — it clamps. A null pointer, an empty span, or an
  Adler-32 state no call sequence could produce leaves the state untouched.
- C ABI: hand-written `include/UniChecksum.h` kept in sync with
  `src/UniChecksum/c_api.nim`; `tests/c` links the header against the lib.
  Built `--app:staticlib`/`--app:lib --noMain --mm:arc -d:release`.
- C symbols `unichecksum_*` (prefix `unichecksum_`, not a short form); lib
  `libUniChecksum`; header `UniChecksum.h`.
- A checksum change is only trustworthy against an outside reference: the Nim
  and Python suites check the published check values, and the Python suite uses
  CPython's `zlib` as an independent oracle for CRC-32 and Adler-32.
- `book/index.nim` is nimib: its code blocks are compiled and run at docs build,
  so prose that outlives its API breaks the build. `py/notebooks/quickstart.ipynb`
  plays the same role for Python and renders natively on GitHub.
- End covered sources with a blank line. Nim maps a trailing statement one line
  past EOF; without that line lcov aborts on `range`/`unmapped`, and `nimble
  coverage` deliberately suppresses no error so the failure stays visible.

## Scope

CRC-32 (IEEE 802.3), CRC-64/XZ (ECMA-182) and Adler-32 (RFC 1950): the checks
container formats mandate. Error detection only, never collision resistance.
Layer 1 — no sibling dependency. Apache-2.0, DCO.
