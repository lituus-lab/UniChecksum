# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# UniChecksum — CRC-32, CRC-64/XZ and Adler-32 checksums.

version       = "0.2.0"
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
  done "canary"

task lint, "Fail if nimpretty would reformat a source":
  exec "nim c -r --hints:off -o:build/lint_tool tools/lint.nim"
  done "lint"

task checkVGraph, "Fail on an import that climbs the layers in vgraph.cfg":
  exec "nim c -r --hints:off -o:build/vgraph_tool tools/vgraph.nim"
  done "checkVGraph"

task docsDeps, "Install the docs toolchain (nimib)":
  exec "nimble install -y nimib"
  done "docsDeps"

task book, "Build the nimib book (needs nimib)":
  # nimib compiles and runs the book's code blocks: a drift fails the build.
  exec "nim c -r --path:src --hints:off -o:build/book book/index.nim"
  done "book"

task docs, "API reference + book into pages/ — what CI publishes":
  rmDir "pages"
  exec "nim doc --index:on --outdir:pages/api --project --hints:off src/UniChecksum.nim"
  exec gate("book")
  # The book is the landing page; the generated reference sits under api/.
  cpFile "book/index.html", "pages/index.html"
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