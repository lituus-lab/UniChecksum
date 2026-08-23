<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0001: No sibling dependency

- Status: Accepted
- Date: 2026-07-15
- Scope: UniChecksum

## Decision

UniChecksum depends on no other library of the family. Its only dependency,
`NimContracts`, is verification infra rather than domain code and compiles away
under `-d:release`, so a release build links nothing but the standard library.

That is what lets it sit at the bottom of the dependency graph: containers and
codecs need a checksum, and a checksum that pulled in a container or a codec
would close a cycle. `vgraph.cfg` declares an empty `[engines]` list, and
`nimble checkVGraph` fails the build if a `requires` line ever names a sibling.

## Consequences

Everything here works on byte spans and integers only. Anything needing a file
format, a stream abstraction, or an allocator policy belongs in the consumer,
not here.

Inside `src/`, the three families import nothing from each other; only the C
ABI sits above them. `vgraph.cfg` records that order and `nimble checkVGraph`
rejects any import that climbs it, so no family can reach for the C ABI. The
check is one-way by design: it would not object to `crc64` importing `crc32`,
which sits lower. Keeping the families independent of each other is a property
of the code, not something the layer check enforces.
