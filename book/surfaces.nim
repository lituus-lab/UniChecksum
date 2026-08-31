# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[os, osproc, strutils]
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "Surfaces"

const Root = currentSourcePath().parentDir.parentDir

proc run(command: string): string =
  ## Run a command from the repository root and return its output. Used so the
  ## C and Python results on this page are produced rather than transcribed.
  ##
  ## A non-zero exit stops the book. Returning the failure as text instead
  ## would publish a page whose "output" is a traceback, from a build that
  ## reported success -- which is exactly what happened before this raised.
  let (output, code) = execCmdEx("cd " & Root.quoteShell & " && " & command)
  result = output.strip
  if code != 0:
    raise newException(OSError,
      "book: `" & command & "` exited " & $code & "\n" & result)

nbText: """
# Surfaces

The same twelve functions reach three audiences, and out of their domain they
do three different things. That is not an inconsistency to be tidied away —
each surface does what its callers can act on — but it is the thing a reader
most needs stated.

| Surface | Bad input | Why |
|---|---|---|
| Nim, debug | raises `PreConditionDefect` | the caller made a mistake and can be told |
| Nim, release | no check | the contract compiled away |
| C | **clamps** | a Nim exception unwinding into C is undefined behaviour |
| Python | raises `TypeError` / `ValueError` | Python callers expect an exception |

## The C ABI clamps

The header is hand-written and kept in sync with `src/UniChecksum/c_api.nim`;
`tests/c` links one against the other on every CI run, so a drift is caught
rather than shipped. Nothing below is transcribed — the block compiles that
header against the static library and runs it.
"""

nbCode:
  echo run("cc -Iinclude -o build/book_c_demo book/surfaces_demo.c " &
          "libUniChecksum.a 2>&1 && ./build/book_c_demo")

nbText: """
A null pointer leaves the running state untouched rather than unwinding across
the ABI boundary. That is a choice with a cost: a C caller cannot discover a
bad pointer by calling this, so it must validate before the boundary rather
than after it.

## The Python binding raises

A Cython extension over the same C ABI, shipped as a self-contained wheel: the
library travels inside the package, so installing it needs neither Nim nor a
compiler. The domain check lives in the package, in Python, before anything
reaches C — so the clamp above is never observed from here.
"""

nbCode:
  echo run("PYTHONPATH=py python3 book/surfaces_demo.py 2>&1")

nbText: """
The second argument continues an earlier result, matching `zlib.crc32`, so
`crc32(b, crc32(a))` equals `crc32(a + b)`. Any bytes-like object is accepted
and a contiguous one is read without being copied; a strided memoryview, which
cannot be read in place, is copied once instead.

A `str` is refused rather than encoded. Guessing an encoding would make the
checksum depend on that guess, and both plausible guesses are wrong often
enough to matter.

## Where they differ in meaning, not syntax

- **The C surface answers where Python refuses.** Passing a null pointer gets a
  checksum back, not an error.
- **The release build agrees with neither.** It has no check and no clamp.
- **`_core` is importable and unchecked.** `unichecksum._core.crc32` is the raw
  C call; the domain check lives in the package, not in the extension.

`py/notebooks/quickstart.ipynb` runs the Python calls against an installed
wheel and renders on GitHub directly.
"""

nbSave
