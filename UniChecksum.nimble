# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# UniChecksum — CRC-32, CRC-64/XZ and Adler-32 checksums.

version       = "0.1.0"
author        = "lituus-lab"
description   = "CRC-32, CRC-64/XZ and Adler-32 checksums (Nim + C ABI + Python)"
license       = "Apache-2.0"
srcDir        = "src"

requires "nim >= 2.2.0"
requires "https://github.com/lbartoletti/NimContracts#main"

import std/strutils

# --- Failure gate -----------------------------------------------------------
# Nimble 0.22 exits 0 even when an `exec` inside a task failed: the exception
# is printed, the task stops, and the process still reports success. Neither
# `try`/`except` nor `quit(1)` inside a task changes it -- measured, not
# assumed -- so nothing written here can make nimble's exit code trustworthy.
#
# Each task therefore ends with `done "<its own name>"`, which drops a marker
# file, and `tools/gate.nim` is what turns a missing marker into a non-zero
# exit. Run a task through the gate, never bare, wherever the answer matters:
# in CI, and in any task that composes another.

const CoverageMin = 90.0
  ## Line coverage below this fails `coverage`.

const gateExe =
  when defined(windows): "build/unigate.exe" else: "build/unigate"

template done(task: string) =
  mkDir "build/.gate"
  writeFile("build/.gate/" & task & ".ok", "")

proc gate(task: string): string =
  ## `exec gate("test")` -- builds the tool on first use.
  if not fileExists(gateExe):
    exec "nim c --hints:off -o:" & gateExe & " tools/gate.nim"
  gateExe & " " & task

task canary, "Must fail: proves the gate still catches a broken build":
  # No `done` here on purpose. If this task ever passes the gate, the gate has
  # stopped working and every other green result is worthless.
  exec "nim c -r --hints:off --path:src -o:build/canary tests/canary_broken.nim"

task lint, "Fail if nimpretty would reformat a source":
  exec "nim c -r --hints:off -o:build/lint_tool tools/lint.nim"
  done "lint"

task checkVGraph, "Fail on an import that climbs the layers in vgraph.cfg":
  exec "nim c -r --hints:off -o:build/vgraph_tool tools/vgraph.nim"
  done "checkVGraph"

# From the URL with a tag, not from the registry: the nimble registry lags
# upstream, and `nimble install nimibook` resolves 0.3.1, whose themes.nim does
# not compile against nimib 0.4.x. The theme is pinned for a different reason --
# several installs of one version is a resolution nimble cannot make, and it
# picks between them in silence.
const bookDeps = [
  "https://github.com/pietroppeter/nimib#v0.4.1",
  "https://github.com/pietroppeter/nimibook#v0.4.0",
  "https://github.com/lituus-lab/lituus-theme#v0.2.0",
]
taskRequires "docsDeps", bookDeps[0], bookDeps[1], bookDeps[2]

task docsDeps, "Install the docs toolchain (nimib + nimibook + theme)":
  # This task's own `taskRequires` above is what fetches them: nimble resolves
  # and installs a task's requirements before running its body.
  echo "nimib, nimibook and lituus-theme installed."
  done "docsDeps"

task bookInit, "Scaffold a chapter added to the table of contents":
  # Only when an entry is added: it creates the missing source and, if there is
  # none, a nimib.toml. Not part of `book`, which must not rewrite scaffolding
  # on every run.
  withDir "book":
    exec "nim c -r --hints:off -o:../build/nbook nbook.nim init"
  done "bookInit"

task book, "Build the multi-chapter book (needs nimib + nimibook)":
  # The surfaces chapter compiles the C header against the static library and
  # imports the Python extension. Neither exists in a fresh clone, and a
  # chapter whose command fails now stops the book rather than publishing the
  # failure as its output -- so the book builds what it is going to run.
  exec gate("clibStatic")
  exec gate("buildCython")
  # Run from book/, because nimibook reads the nimib.toml of the directory it
  # starts in -- run from the root, `init` writes a second one there that masks
  # the book's own. Each chapter is compiled and run as its own program, so a
  # drift in any of them fails the build; book/config.nims is what gives those
  # processes their paths.
  withDir "book":
    exec "nim c -r --hints:off -o:../build/nbook nbook.nim clean"
    # `init` before `build`, on every run: it is what creates `__site/assets`,
    # which is not tracked, so a fresh clone has none and every page ships
    # referencing a stylesheet and a script that are not there. It only ever
    # creates what is missing -- an existing chapter is left alone -- so this
    # is not the scaffolding rewrite `bookInit` exists to keep out of `book`.
    exec "nim c -r --hints:off -o:../build/nbook nbook.nim init"
    exec "nim c -r --hints:off -o:../build/nbook nbook.nim build"
  done "book"

task docs, "API reference + book into pages/ — what CI publishes":
  rmDir "pages"
  exec gate("book")
  # The book *is* the site: its pages link to `assets/` and to each other as
  # siblings, so it is copied whole to the root rather than nested and then
  # copied again. Lifting one page out of it breaks every relative link on it.
  cpDir "book/__site", "pages"
  # book.json is nimibook's build state -- no page fetches it -- and it carries
  # the absolute path of the machine that built it. It does not get published.
  rmFile "pages/book.json"
  # The generated reference sits beside the book, not inside it.
  exec "nim doc --index:on --outdir:pages/api --project --hints:off src/UniChecksum.nim"
  # ...and wears the same theme. `nim doc` has no stylesheet option, so the
  # palette is appended to the one it just wrote. Left alone, that reference
  # ships six tokens below their contrast bar.
  exec "nim c -r --hints:off --outdir:build tools/theme_api.nim " &
       "pages/api/nimdoc.out.css"
  done "docs"

const testFiles = @["test_crc32", "test_crc64", "test_adler32", "test_api",
                    "test_version"]

proc runTests(release: bool) =
  let flags = if release: " -d:release" else: ""
  let suffix = if release: "_rel" else: ""
  for name in testFiles:
    exec "nim c -r" & flags & " --path:src -o:build/" & name & suffix &
         " tests/" & name & ".nim"

task test, "Nim tests (debug, contracts active)":
  runTests(release = false)
  done "test"

task testRelease, "Nim tests (release, contracts compiled away)":
  runTests(release = true)
  done "testRelease"

task testCi, "Nim tests (CI subset, debug)":
  runTests(release = false)
  done "testCi"

task testCiRelease, "Nim tests (CI subset, release)":
  runTests(release = true)
  done "testCiRelease"

task testAll, "debug + release + C ABI":
  exec gate("test")
  exec gate("testRelease")
  exec gate("ctest")
  done "testAll"

task example, "Nim demo":
  exec "nim c -r --path:src -o:build/demo examples/demo.nim"
  done "example"

# Nim takes `-o:` literally and appends no platform extension.
const
  sharedLib =
    when defined(windows): "libUniChecksum.dll"
    elif defined(macosx): "libUniChecksum.dylib"
    else: "libUniChecksum.so"
  staticLib = "libUniChecksum.a"  # MinGW `ar` on Windows, so `.a` everywhere.

  # @rpath install_name, so the copy bundled in the wheel is found at import.
  macArgs =
    when defined(macosx): " --passL:\"-Wl,-install_name,@rpath/" & sharedLib & "\""
    else: ""

task clib, "C shared library":
  exec "nim c --app:lib --noMain --mm:arc -d:release -o:" & sharedLib & macArgs &
       " src/UniChecksum/c_api.nim"
  done "clib"

task clibStatic, "C static library":
  exec "nim c --app:staticlib --noMain --mm:arc -d:release -d:staticNoAutoInit -o:" & staticLib &
       " src/UniChecksum/c_api.nim"
  done "clibStatic"

task clibMsvc, "C static library, MSVC ABI (Windows Python extension)":
  # CPython on Windows is MSVC-built and cannot link MinGW output.
  exec "nim c --cc:vcc --app:staticlib --noMain --mm:arc -d:release -d:staticNoAutoInit" &
       " -o:UniChecksum.lib src/UniChecksum/c_api.nim"
  done "clibMsvc"

# Nim's MinGW toolchain names it mingw32-make.
let makeExe = if findExe("mingw32-make").len > 0: "mingw32-make" else: "make"

# `make -C`, not `cd dir && make`: nimble's exec runs no shell on Windows.
task ctest, "C ABI tests":
  exec gate("clibStatic")
  exec makeExe & " -C tests/c"
  done "ctest"

task cexample, "C demo":
  exec gate("clibStatic")
  exec makeExe & " -C examples/c"
  done "cexample"

# `python3` is not on PATH on Windows: actions/setup-python puts `python.exe`
# there, and the Store shim answers `python3` with an installer prompt.
const pythonExe = when defined(windows): "python" else: "python3"

task pyDeps, "Install Python build deps (setuptools, Cython, pytest) if missing":
  exec pythonExe & " -m pip install --break-system-packages --quiet setuptools wheel \"Cython>=3.0.0\" pytest"
  done "pyDeps"

# The extension links the vcc static lib on Windows, the shared lib elsewhere.
task pyLib, "Build the library the Python extension links against":
  when defined(windows):
    exec gate("clibMsvc")
  else:
    exec gate("clib")
  done "pyLib"

task buildCython, "Cython extension in-place":
  exec gate("pyLib")
  exec gate("pyDeps")
  withDir "py":
    exec pythonExe & " setup.py build_ext --inplace"
  done "buildCython"

task pyTest, "Cython extension + pytest":
  exec gate("buildCython")
  withDir "py":
    exec pythonExe & " -m pytest -q"
  done "pyTest"

task pyWheel, "wheel":
  exec gate("pyLib")
  exec gate("pyDeps")
  withDir "py":
    exec pythonExe & " setup.py bdist_wheel"
  done "pyWheel"

task coverage, "LCOV + HTML coverage report for the Nim sources (needs lcov)":
  # gcov and lcov driven directly, no coco. Linux and macOS only.
  # --debugger:native attributes lines to the .nim sources, not the generated C.
  # --include keeps stdlib out of the capture, where lcov 2.x aborts on Nim's
  # codegen.
  #
  # One error is ignored, by name: `mismatch`, which lcov 2.0 raises on the
  # end line of NimContracts' generated `eqdestroy_` for its Defect types
  # (lcov 2.5 does not, so the runners disagree with a developer machine).
  # It concerns a compiler-generated symbol, not a line of this library.
  # `range` and `unmapped` stay fatal: those would mean the capture no longer
  # matches the sources, which is the failure this task exists to surface.
  let cache = "build/covcache"
  rmDir cache
  rmDir "coverage"
  for name in testFiles:
    exec "nim c --path:src --nimcache:" & cache &
         " --debugger:native --passC:--coverage --passL:--coverage" &
         " -o:build/cov_" & name & " tests/" & name & ".nim"
    exec "./build/cov_" & name
  exec "lcov --capture --directory " & cache & " --base-directory ." &
       " --include \"*/src/UniChecksum/*\" --ignore-errors mismatch" &
       " --output-file lcov.info --quiet"
  exec "genhtml lcov.info --output-directory coverage --legend --quiet"

  # A threshold, not a report: coverage that is measured and printed but never
  # opposable is a number nobody has to answer for. The summary is read rather
  # than `--fail-under-lines` passed, that option being lcov 2.x only while the
  # runners are not pinned to a version.
  let summary = gorgeEx("lcov --summary lcov.info 2>&1")
  echo summary.output
  if summary.exitCode != 0:
    quit("coverage: lcov --summary failed", 1)
  var rate = -1.0
  for line in summary.output.splitLines:
    let at = line.find("lines")
    if at < 0 or not line.contains('%'): continue
    let colon = line.find(':', at)
    if colon < 0: continue
    let percent = line.find('%', colon)
    if percent < 0: continue
    rate = parseFloat(line[colon + 1 ..< percent].strip)
    break
  if rate < 0:
    quit("coverage: no line rate in lcov's summary", 1)
  if rate < CoverageMin:
    quit("coverage: " & $rate & "% of lines, below the " & $CoverageMin &
         "% this repo requires", 1)
  echo "coverage: " & $rate & "% of lines, at or above " & $CoverageMin & "%"

  done "coverage"