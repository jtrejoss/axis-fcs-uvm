#!/usr/bin/env python3
"""
Golden-model cross-check for the CRC-32 algorithms used in this project.
  * bitwise reflected CRC (as implemented in the RTL)
  * table-driven CRC (as implemented in the UVM reference model)
  * Python zlib.crc32 (independent reference)
Also checks the Ethernet residue property: CRC(frame || FCS_le) == 0x2144DF1C.
"""
import random
import zlib

POLY = 0xEDB88320


def crc_bitwise(data: bytes) -> int:
    c = 0xFFFFFFFF
    for b in data:
        c ^= b
        for _ in range(8):
            c = (c >> 1) ^ POLY if c & 1 else c >> 1
    return c ^ 0xFFFFFFFF


TABLE = []
for i in range(256):
    c = i
    for _ in range(8):
        c = (c >> 1) ^ POLY if c & 1 else c >> 1
    TABLE.append(c)


def crc_table(data: bytes) -> int:
    c = 0xFFFFFFFF
    for b in data:
        c = TABLE[(c ^ b) & 0xFF] ^ (c >> 8)
    return c ^ 0xFFFFFFFF


def main(n=2000, seed=1):
    rng = random.Random(seed)
    vectors = [b"", b"\x00", b"\xff", b"123456789", bytes(256), b"\xff" * 256]
    vectors += [bytes(rng.getrandbits(8) for _ in range(rng.randint(1, 256))) for _ in range(n)]
    for v in vectors:
        ref = zlib.crc32(v)
        assert crc_bitwise(v) == ref, v
        assert crc_table(v) == ref, v
        if v:
            frame = v + ref.to_bytes(4, "little")
            assert zlib.crc32(frame) == 0x2144DF1C
    assert crc_bitwise(b"123456789") == 0xCBF43926   # standard check value
    print(f"OK: {len(vectors)} vectors, bitwise == table == zlib, Ethernet residue verified")


if __name__ == "__main__":
    main()
