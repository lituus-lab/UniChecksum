<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# unichecksum — Python binding

```bash
nimble clib                                    # build libUniChecksum.so
cd py
python3 setup.py build_ext --inplace           # build extension
python3 -m pytest -q                           # test
```

```python
import unichecksum

unichecksum.crc32(b"123456789")    # 0xCBF43926
unichecksum.crc64(b"123456789")    # 0x995DC9BBDF1939FA
unichecksum.adler32(b"123456789")  # 0x091E01DE
unichecksum.version()              # "0.1.0"
```

`value` continues an earlier result, so `crc32(b, crc32(a)) == crc32(a + b)` —
the same convention as `zlib.crc32`. Any bytes-like object works; a contiguous
buffer is read without being copied.
