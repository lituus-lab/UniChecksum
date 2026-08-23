<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# Security Policy

Report vulnerabilities privately (email the maintainer — see git history),
not via a public issue. Include: description + impact, minimal reproducer,
affected version (`unichecksum_version()`).

Only the latest released line is supported. The `0.1.x` C ABI is not yet frozen.

## Surface

- C ABI never raises. It clamps what it can see: a null pointer, an empty span,
  a length no `int` can address, and an Adler-32 state no call sequence could
  have produced. It cannot check that a pointer and length describe readable
  memory — callers must supply at least `length` readable bytes.
- Python binding adds the domain check and raises `ValueError`/`TypeError`.
- Single-threaded, reentrant; no global mutable state.
