#!/usr/bin/env python3
"""Fail unless a Mach-O universal binary contains both armv7 and arm64 slices."""
from __future__ import annotations
import struct
import sys
from pathlib import Path

CPU_TYPE_ARM = 12
CPU_TYPE_ARM64 = 0x0100000C
FAT_MAGIC = 0xCAFEBABE
FAT_MAGIC_64 = 0xCAFEBABF
FAT_CIGAM = 0xBEBAFECA
FAT_CIGAM_64 = 0xBFBAFECA


def die(msg: str) -> None:
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(1)


def parse(path: Path):
    data = path.read_bytes()
    if len(data) < 8:
        die(f"{path}: file is too small to be Mach-O")

    magic_be = struct.unpack_from(">I", data, 0)[0]
    if magic_be in (FAT_MAGIC, FAT_MAGIC_64):
        endian = ">"
        is64 = magic_be == FAT_MAGIC_64
    elif magic_be in (FAT_CIGAM, FAT_CIGAM_64):
        endian = "<"
        is64 = magic_be == FAT_CIGAM_64
    else:
        die(f"{path}: not a universal/fat Mach-O (magic 0x{magic_be:08x})")

    nfat = struct.unpack_from(endian + "I", data, 4)[0]
    offset = 8
    arches = []
    if is64:
        fmt = endian + "iiQQII"
    else:
        fmt = endian + "iiIII"
    size = struct.calcsize(fmt)

    for _ in range(nfat):
        if offset + size > len(data):
            die(f"{path}: truncated fat architecture table")
        fields = struct.unpack_from(fmt, data, offset)
        cputype = fields[0] & 0xFFFFFFFF
        cpusubtype = fields[1] & 0xFFFFFFFF
        arches.append((cputype, cpusubtype))
        offset += size
    return arches


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <Mach-O binary>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    if not path.is_file():
        die(f"missing binary: {path}")

    arches = parse(path)
    cpu_types = {a[0] for a in arches}
    names = []
    for cputype, cpusubtype in arches:
        if cputype == CPU_TYPE_ARM:
            names.append(f"armv7/ARM(subtype=0x{cpusubtype:x})")
        elif cputype == CPU_TYPE_ARM64:
            names.append(f"arm64(subtype=0x{cpusubtype:x})")
        else:
            names.append(f"cpu=0x{cputype:x}(subtype=0x{cpusubtype:x})")

    print(f"{path}: {', '.join(names)}")
    missing = []
    if CPU_TYPE_ARM not in cpu_types:
        missing.append("armv7")
    if CPU_TYPE_ARM64 not in cpu_types:
        missing.append("arm64")
    if missing:
        die(f"{path}: missing required slice(s): {', '.join(missing)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
