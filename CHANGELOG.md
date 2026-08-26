<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# Changelog

Notable changes, newest first. Format after
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The C ABI has its own compatibility: a symbol removed or retyped is a major
change, whatever the Nim API did.

## [0.1.0]

First release. Nothing here has ever been published: no tag, no GitHub
release, no wheel. The version marks the first time the whole chain is
exercised end to end, not a second iteration on a first one.

CRC-32 (IEEE 802.3), CRC-64/XZ (ECMA-182) and Adler-32 (RFC 1950), one-shot
and streaming, in Nim, C and Python. Checked against the check values those
specifications publish, with CPython's `zlib` as an independent oracle.

### Added

- `tools/gate.nim`, and a success marker on every task. Nimble 0.22 exits 0
  when an `exec` inside a task failed, so its exit code proves nothing; the
  gate reads the marker instead. Every green result before this one proved
  only that nimble ran.
- A `canary` task that must fail, and a CI job that checks it does.
- `tests/test_version.nim`, which reads the version out of the manifest, the
  Nim constant, the C header, the C ABI and the Python packaging, and fails
  when one drifts.
- `CODE_OF_CONDUCT.md`, `CITATION.cff`, `.editorconfig`, this file.

### Changed

- The C ABI runtime guard becomes a once primitive. The plain flag it replaces
  could let two threads both call `NimMain`, the second entering Nim code the
  first had not finished initializing.
- `{.raises: [].}` on the C boundary: the promise that no Nim exception crosses
  it is now checked by the compiler rather than remembered.
- The PyPI distribution becomes `lituus-unichecksum`; the import name stays
  `unichecksum`.
- Nim minimum 2.0 to 2.2.
- CI calls the shared `lituus-lab/.github` workflow instead of carrying its own
  copy, pinned by commit.
- Coverage below 90% fails, instead of being reported and ignored.

### Fixed

- The Nim and Python suites asserted the version as a literal, so a bump broke
  them. They check that one exists; agreement is `test_version.nim`'s job.

