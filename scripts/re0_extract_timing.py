#!/usr/bin/env python3
"""Extract small, address-focused RE0 timing evidence from the local disassembly."""
from pathlib import Path
import re
import hashlib
import os

ROOT = Path(__file__).resolve().parents[1]
DISASM = ROOT / "tmp/re0-analysis/main.disasm.txt"
OUT = ROOT / "tmp/re0-analysis/re0-timing-disassembly.txt"

needles = (
    "7aa7ac", "7aa840", "7aa894", "7aa8f4", "7aa934", "7aa990",
    "7aa320", "7aa330", "1285650", "1284598", "a04238",
)
if not DISASM.is_file():
    raise SystemExit(f"Disassembly not found: {DISASM}")
size = DISASM.stat().st_size
sha = hashlib.sha256(DISASM.read_bytes()).hexdigest()
lines = DISASM.read_text(errors="replace").splitlines()

hits = []
for i, line in enumerate(lines):
    low = line.lower()
    if any(n in low for n in needles):
        hits.append(i)

# Merge overlapping windows so the report remains compact but preserves context.
windows = []
for i in hits:
    lo, hi = max(0, i - 24), min(len(lines), i + 40)
    if windows and lo <= windows[-1][1]:
        windows[-1] = (windows[-1][0], max(windows[-1][1], hi))
    else:
        windows.append((lo, hi))

out = [
    "# RE0 timing disassembly excerpts",
    f"Source: {DISASM}",
    f"Source size: {size} bytes",
    f"Source SHA256: {sha}",
    f"Total lines: {len(lines)}",
    f"Matched lines: {len(hits)}",
    "",
]
for lo, hi in windows:
    out.append(f"## Source lines {lo + 1}-{hi}")
    for j in range(lo, hi):
        out.append(f"{j + 1}: {lines[j]}")
    out.append("")

# Include runtime probe files if present; never include environment files or keys.
for p in (
    Path.home() / "Library/Logs/nxnative/010097000BC10000.log",
    Path("/tmp/re0_timing_probe.log"),
    Path("/tmp/re_movie_clock_probe.log"),
):
    if p.is_file():
        out += [f"## Runtime evidence: {p}", p.read_text(errors="replace")[-30000:], ""]

OUT.write_text("\n".join(out))
print(f"Wrote {OUT} ({OUT.stat().st_size} bytes); disassembly matches={len(hits)}, windows={len(windows)}")
