"""Re-encode the validated whole-disk cross-build with Apple's disk image writer."""
import bz2
import hashlib
import os
from pathlib import Path
import plistlib
import struct
import subprocess
import sys
import tempfile
import zlib

image = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory() as temp:
    raw = Path(temp) / "disk.cdr"
    with image.open("rb") as src, raw.open("wb") as out:
        src.seek(-512, 2)
        footer = src.read(512)
        assert footer[:4] == b"koly"
        offset, length = struct.unpack_from(">QQ", footer, 216)
        src.seek(offset)
        blk, = plistlib.loads(src.read(length))["resource-fork"]["blkx"]
        data = blk["Data"]
        assert data[:4] == b"mish"
        for kind, _, sector, count, pos, size in struct.iter_unpack(">IIQQQQ", data[204:]):
            if kind == 0xffffffff:
                break
            assert out.tell() == sector * 512 and 0 < count <= 2048
            src.seek(pos)
            part = {0x80000005: zlib.decompress, 0x80000006: bz2.decompress}[kind](src.read(size))
            assert len(part) == count * 512
            out.write(part)
    final = Path(temp) / "final.dmg"
    subprocess.run(["hdiutil", "convert", str(raw), "-imagekey", "diskimage-class=CRawDiskImage",
                    "-format", "UDZO", "-o", str(final)], check=True)
    subprocess.run(["hdiutil", "verify", str(final)], check=True)
    os.replace(final, image)
    print("Native DMG", image.name, hashlib.sha256(image.read_bytes()).hexdigest(), flush=True)
