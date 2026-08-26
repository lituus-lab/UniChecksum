# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniChecksum — umbrella module. Re-exports every public submodule.
import UniChecksum/adler32
import UniChecksum/crc32
import UniChecksum/crc64
export adler32, crc32, crc64

const UniChecksumVersion* = "0.1.0"
  ## The package version, as the manifest states it. tests/test_version.nim
  ## checks that this, the C header, the C ABI and the Python packaging agree.
