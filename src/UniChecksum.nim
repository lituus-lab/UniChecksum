# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniChecksum — umbrella module. Re-exports every public submodule.
import UniChecksum/crc32
import UniChecksum/crc64
export crc32, crc64

const UniChecksumVersion* = "0.1.0"
