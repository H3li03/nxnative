#!/bin/bash
set -euo pipefail
ISO="$1"
WORK="$2"
[ -f "$ISO" ] || { echo "ISO not found"; exit 1; }
mkdir -p "$WORK/tools"
TMP=$(mktemp -d "$WORK/tools/pc-extract.XXXXXXXX")
MOUNT="$TMP/mount"
mkdir "$MOUNT"
attached=0
cleanup() {
    if [ "$attached" = 1 ]; then
        hdiutil detach "$MOUNT" >&2 || { echo "Detach manually: $MOUNT" >&2; return; }
    fi
    rm -rf "$TMP"
}
trap cleanup EXIT
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT" "$ISO" >&2
attached=1
ARCHIVE="$MOUNT/setup-1.bin"
[ -f "$ARCHIVE" ] || { echo "Base setup-1.bin not found"; exit 1; }
[ "$(stat -f %z "$ARCHIVE")" = 21924976657 ] || { echo "Unsupported PC base archive"; exit 1; }
git clone https://github.com/Helaas/unarc.git "$TMP/unarc" >&2
git -C "$TMP/unarc" checkout --detach 70cd3eb3f1b08feb499a2f4f53c739229aaf86ee >&2
python3.14 - "$TMP/unarc/Environment.cpp" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1])
s=p.read_text(encoding="latin1")
assert s.count("0xEDB88320L")==1
p.write_text(s.replace("0xEDB88320L","0x8E092638L"),encoding="latin1")
PY
make -C "$TMP/unarc" -j1 >&2
OUT=$(mktemp -d "$WORK/PC-Textures.XXXXXXXX")
echo "Extracting to $OUT" >&2
"$TMP/unarc/unarc" x --noarcext "-dp$OUT" "$ARCHIVE" txn_up.1.pak txn_up.2.pak TextureData.pak >&2
printf '%s\n' "$OUT"
