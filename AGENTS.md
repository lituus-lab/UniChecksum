<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# AGENTS.md — UniChecksum

## Build & gates

```bash
nimble install -y
nim c --hints:off -o:build/unigate tools/gate.nim   # the failure gate, once

build/unigate testAll    # Nim debug + release + C ABI
build/unigate pyTest     # Cython + pytest (needs libUniChecksum.so)
build/unigate example
build/unigate lint       # nimpretty check
build/unigate checkVGraph
build/unigate coverage   # gcov + lcov -> coverage/ (needs lcov; linux/macOS)
build/unigate docs       # nimib book + API reference -> pages/ (needs nimib)
build/unigate canary     # must fail
```

Never `nimble <task>` bare where the answer matters: nimble 0.22 exits 0 even
when an `exec` inside the task failed. The gate reads the task's own success
marker instead, which is the only evidence it ran to its last line.

`nimble docs` needs a complete Nim distribution: `--project` builds `dochack`,
which Homebrew's `nim` omits (no `tools/`). choosenim and the CI action ship it.

CI: the family's shared workflow in `lituus-lab/.github`, called from
`ci.yml`. Nim, C ABI and Python each on ubuntu/macOS/Windows; lint, docs and
coverage on ubuntu; a canary job that must fail; `all-green` over all of them.

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
  `{.raises: [].}` on the boundary is what proves it rather than a convention
  that has to be remembered.
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
  past EOF; without that line lcov aborts on `range`/`unmapped`, and `coverage`
  keeps those fatal so the failure stays visible. It ignores exactly one error,
  `mismatch`, which lcov 2.0 raises on a NimContracts-generated destructor and
  lcov 2.5 does not — a compiler-generated symbol, not a line of the library.

## Scope

CRC-32 (IEEE 802.3), CRC-64/XZ (ECMA-182) and Adler-32 (RFC 1950): the checks
container formats mandate. Error detection only, never collision resistance.
No sibling dependency, enforced by `checkVGraph` against an empty `[engines]`.
Apache-2.0, DCO.
