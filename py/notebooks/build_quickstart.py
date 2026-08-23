# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Author py/notebooks/quickstart.ipynb, then execute it so the committed file
carries real outputs for GitHub to render. Run from the repo root:

    python3 py/notebooks/build_quickstart.py

CI re-executes the notebook against an installed wheel; this script only
regenerates it after an API change."""
import os

import nbformat as nbf
from nbclient import NotebookClient

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "quickstart.ipynb")

CELLS = [
    ("md", """# UniChecksum — Python quickstart

`unichecksum` is a Cython extension over the UniChecksum C ABI, shipped as a
self-contained wheel: the native library travels inside the package, so
installing it needs neither Nim nor a compiler.

```
pip install unichecksum
```

CI executes this notebook against the wheel the release actually publishes, so
an output below that stops matching fails the build."""),
    ("md", "## The API"),
    ("code", """import unichecksum

unichecksum.version(), unichecksum.__version__"""),
    ("md", """Three families, each pinned to the parameters its consuming format
mandates. `"123456789"` is the input every CRC catalogue publishes a check value
for, which makes it the first thing to try against any implementation."""),
    ("code", """data = b"123456789"
{
    "crc32": hex(unichecksum.crc32(data)),
    "crc64": hex(unichecksum.crc64(data)),
    "adler32": hex(unichecksum.adler32(data)),
}"""),
    ("md", """## zlib agrees

CRC-32 and Adler-32 are the two the standard library also implements, which
makes `zlib` a free independent check."""),
    ("code", """import zlib

(unichecksum.crc32(data) == zlib.crc32(data),
 unichecksum.adler32(data) == zlib.adler32(data))"""),
    ("md", """## Continuing a previous result

The second argument is a checksum to continue from, the same convention as
`zlib.crc32`, so data arriving in pieces needs no separate state object."""),
    ("code", """first, second = b"12345", b"6789"
running = unichecksum.crc32(first)
unichecksum.crc32(second, running) == unichecksum.crc32(first + second)"""),
    ("md", """## The empty input is not zero everywhere

A CRC starts at all-ones and ends by inverting, so with nothing in between the
two cancel. Adler-32 starts its low half at one and never transforms its output,
so the empty input keeps that one — treating zero as "no checksum computed" is
safe for the CRCs and wrong for Adler-32."""),
    ("code", """(unichecksum.crc32(b""), unichecksum.crc64(b""), unichecksum.adler32(b""))"""),
    ("md", """## Any bytes-like object

A contiguous buffer is read in place, without being copied. A strided
memoryview cannot be, so it is copied once instead — the result is the same
either way."""),
    ("code", """import array

strided = memoryview(b"abcdef")[::2]
(unichecksum.crc32(bytearray(data)) == unichecksum.crc32(data),
 unichecksum.crc32(array.array("B", data)) == unichecksum.crc32(data),
 unichecksum.crc32(strided) == unichecksum.crc32(b"ace"))"""),
    ("md", """A `str` has no bytes until it is encoded, so it is refused rather
than guessed at."""),
    ("code", """try:
    unichecksum.crc32("123456789")
except TypeError as exc:
    print("TypeError:", exc)"""),
    ("md", """## The C ABI underneath

The same entry points are reachable from anything that speaks C. There the
contract is expressed by clamping instead of raising — an exception must never
unwind across an ABI boundary:

```c
unichecksum_crc32(NULL, 8);                 /* 0     — nothing was read */
unichecksum_crc32_update(state, NULL, 8);   /* state — unchanged */
```

See `include/UniChecksum.h`, and the book for the full picture."""),
]


def main():
    nb = nbf.v4.new_notebook()
    nb.cells = [
        nbf.v4.new_markdown_cell(src) if kind == "md" else nbf.v4.new_code_cell(src)
        for kind, src in CELLS
    ]
    nb.metadata["kernelspec"] = {
        "display_name": "Python 3",
        "language": "python",
        "name": "python3",
    }
    # Execute from the repo root, never from py/: there, `import unichecksum`
    # would resolve to the py/unichecksum source tree instead of the installed
    # package, and the notebook would stop testing what it claims to test.
    NotebookClient(nb, timeout=120, kernel_name="python3",
                   resources={"metadata": {"path": ROOT}}).execute()
    with open(OUT, "w") as f:
        nbf.write(nb, f)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
