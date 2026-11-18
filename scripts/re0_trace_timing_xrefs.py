#!/usr/bin/env python3
"""Trace every static xref to RE0's MT timing singleton and nearby field accesses."""
from pathlib import Path
import re, hashlib

root = Path(__file__).resolve().parents[1]
src = root / "tmp/re0-analysis/main.disasm.txt"
out = root / "tmp/re0-analysis/re0-timing-xrefs.txt"
if not src.is_file():
    raise SystemExit(f"Missing {src}")
raw = src.read_bytes()
lines = raw.decode("utf-8", "replace").splitlines()
sha = hashlib.sha256(raw).hexdigest()

# The singleton pointer is addressed through page 0x1285000 + 0x650.
# Keep every occurrence of that page and nearby instructions, then separately
# report direct register-based +0x48/+0x4c/+0x50 accesses.
page_hits = [i for i, line in enumerate(lines) if "0x1285000" in line]
field_hits = [
    i for i, line in enumerate(lines)
    if re.search(r"\[(?:x[0-9]+|xzr), #0x(?:48|4c|50)\]", line)
]
windows = []
for i in sorted(set(page_hits + field_hits)):
    lo, hi = max(0, i - 5), min(len(lines), i + 9)
    if windows and lo <= windows[-1][1]:
        windows[-1] = (windows[-1][0], max(windows[-1][1], hi))
    else:
        windows.append((lo, hi))

parts = [
    "# RE0 MT timing singleton xrefs",
    f"Source: {src}",
    f"Source bytes: {len(raw)}",
    f"Source SHA256: {sha}",
    f"Source lines: {len(lines)}",
    f"Page-reference lines (0x1285000): {len(page_hits)}",
    f"Register field-access lines (+0x48/+0x4c/+0x50): {len(field_hits)}",
    "",
]
for lo, hi in windows:
    parts.append(f"## Lines {lo + 1}-{hi}")
    parts.extend(f"{n + 1}: {lines[n]}" for n in range(lo, hi))
    parts.append("")
out.write_text("\n".join(parts))
print(f"Wrote {out} ({out.stat().st_size} bytes); page refs={len(page_hits)}, field refs={len(field_hits)}")
