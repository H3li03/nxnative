#!/bin/bash
set -e
set -o pipefail

cd "$(dirname "$0")"
REPO="$PWD"
PYTHON="${PYTHON:-python3.14}"
fail() { echo "Error: $*" >&2; exit 1; }
[ "$(uname -s)" = Darwin ] || fail "macOS required"
[ "$(uname -m)" = arm64 ] || fail "Apple Silicon required (run in a native terminal)"
for cmd in "$PYTHON" dotnet make xcodebuild codesign; do
    command -v "$cmd" >/dev/null || fail "Missing dependency: $cmd"
done
xcodebuild -version >/dev/null || fail "Configure Xcode first"
[ -f "$REPO/scripts/build_ipa_from_nsp.py" ] || fail "Place this script in the nxnative repository root"

normalize() {
    local value="$1"
    case "$value" in
        \'*\') value="${value:1:${#value}-2}" ;;
        \"*\") value="${value:1:${#value}-2}" ;;
        *) value="${value//\\ / }" ;;
    esac
    case "$value" in '~/'*) value="$HOME/${value:2}" ;; esac
    printf '%s\n' "$value"
}
ask_file() {
    local value
    while true; do
        read -e -r -p "$1: " value || return 1
        value=$(normalize "$value")
        if [ -f "$value" ]; then
            (cd "$(dirname "$value")" && printf '%s/%s\n' "$PWD" "$(basename "$value")")
            return
        fi
        echo "File not found. Try again." >&2
    done
}
if [ "${MGS4_GUI:-0}" = 1 ]; then
    WORK="${MGS4_WORK:?Missing workspace}"
else
    read -e -r -p "Workspace [$HOME/MGS4-Native]: " WORK
fi
WORK=$(normalize "${WORK:-$HOME/MGS4-Native}")
mkdir -p "$WORK"
WORK=$(cd "$WORK" && pwd -P)
if [ "${MGS4_GUI:-0}" = 1 ]; then target="${MGS4_TARGET:?Missing target}"; else
    read -r -p "Target: 1 macOS, 2 iPadOS, 3 both [1]: " target
fi
target=${target:-1}
case "$target" in 1|2|3) ;; *) fail "Invalid target" ;; esac
if [ "$target" != 1 ]; then
    command -v xcodegen >/dev/null || fail "Missing dependency: xcodegen"
    xcrun --sdk iphoneos --find clang >/dev/null || fail "iOS SDK required"
fi
DUMP="$WORK/dump/program_2"
mkdir -p "$WORK/logs" "$WORK/build" "$WORK/dump" "$WORK/game/updates/393216"
if [ "$target" != 2 ] && { [ -e "$WORK/MGS4.app" ] || [ -L "$WORK/MGS4.app" ]; }; then
    if [ "${MGS4_GUI:-0}" = 1 ]; then answer=y; else read -r -p "Existing app will be moved to a backup. Continue? [y/N] " answer; fi
    case "$answer" in y|Y) ;; *) exit 1 ;; esac
fi
if [ -f "$DUMP/ExeFS/main" ] && [ -d "$DUMP/RomFS" ]; then
    if [ "${MGS4_GUI:-0}" = 1 ]; then answer="${MGS4_REUSE:-n}"; else read -r -p "Reuse existing dump (must be program 4002, update 393216)? [y/N] " answer; fi
    case "$answer" in y|Y) reuse=1 ;; *) reuse=0 ;; esac
else
    reuse=0
fi
if [ "${MGS4_GUI:-0}" = 1 ]; then
    KEYS="${MGS4_KEYS:?Missing keys}"
    BASE="${MGS4_BASE:?Missing base NSP}"
    UPDATE="${MGS4_UPDATE:?Missing update NSP}"
    DLC="${MGS4_DLC:?Missing DLC NSP}"
    for path in "$KEYS" "$BASE" "$UPDATE" "$DLC"; do
        [ -f "$path" ] || fail "File not found: $path"
    done
else
    KEYS=$(ask_file "Path to prod.keys")
    BASE=$(ask_file "Path to base NSP")
    UPDATE=$(ask_file "Path to update NSP (v393216)")
    DLC=$(ask_file "Path to multilingual NSP")
fi
if [ "$reuse" = 0 ]; then
    [ ! -e "$DUMP" ] && [ ! -L "$DUMP" ] || fail "Existing dump protected. Move it aside or choose another workspace."
    dotnet run --project "$REPO/dm/tools/nx_extract" -c Release -- \
        "$KEYS" "$BASE" "$UPDATE" "$DUMP" --program=0100D0B01C4F4002 \
        2>&1 | tee "$WORK/logs/extraction.log"
fi
[ -f "$DUMP/ExeFS/main" ] && [ -d "$DUMP/RomFS" ] || fail "Incomplete extraction"
for path in "$WORK/game/updates/393216/exefs" "$WORK/game/updates/393216/romfs"; do
    if [ -e "$path" ] && [ ! -L "$path" ]; then fail "Not a symlink: $path"; fi
done
echo
echo "=== PREPARING DUMP ==="

ln -sfn "$WORK/dump/program_2/ExeFS" \
"$WORK/game/updates/393216/exefs"

ln -sfn "$WORK/dump/program_2/RomFS" \
"$WORK/game/updates/393216/romfs"

DLC_DUMP="$WORK/dump/multilingual"
if [ -d "$DLC_DUMP/ww/bank/nx" ]; then
    if [ "${MGS4_GUI:-0}" = 1 ]; then answer="${MGS4_REUSE:-n}"; else read -r -p "Reuse existing multilingual dump (must match selected NSP)? [y/N] " answer; fi
    case "$answer" in y|Y) ;; *) fail "Existing DLC dump protected. Move it aside first." ;; esac
else
    [ ! -e "$DLC_DUMP" ] || fail "Incomplete DLC dump; move it aside first."
    dotnet run --project "$REPO/dm/tools/nx_extract" -c Release -- \
        "$KEYS" --aoc "$DLC" "$DLC_DUMP" 0100D0B01C4F5001 \
        2>&1 | tee "$WORK/logs/multilingual.log"
fi
[ -d "$DLC_DUMP/ww/bank/nx" ] || fail "Missing multilingual assets"

echo

if [ -n "${MGS4_PC_ISO:-}" ]; then
    [ -z "${MGS4_PC_TEXTURES:-}" ] || fail "Choose either ISO or extracted textures"
    MGS4_PC_TEXTURES=$(bash "$REPO/tools/mgs4-builder/extract_pc.sh" "$MGS4_PC_ISO" "$WORK")
fi
# Import only the six verified base-PC archives, preserving the original NX assets.
if [ -n "${MGS4_PC_TEXTURES:-}" ]; then
    "$PYTHON" - "$MGS4_PC_TEXTURES" "$DUMP/RomFS" "$DLC_DUMP" <<'PY'
import pathlib, sys, shutil, tempfile, os
src, rom, dlc = map(pathlib.Path, sys.argv[1:])
if (src / "MGS4").is_dir():
    src = src / "MGS4"
sizes = {"common": (1733122,3175475,4859421106), "ww": (927746,175942,1280007417)}
names = ("txn_up.1.pak","txn_up.2.pak","paks/TextureData.pak")
# Custom FreeArc CRC used by the verified PC base archive.
poly = 0x8E092638
table = []
for i in range(256):
    c = i
    for _ in range(8):
        c = (c >> 1) ^ (poly if c & 1 else 0)
    table.append(c)
def crc(path):
    c = 0xffffffff
    with path.open("rb") as f:
        while chunk := f.read(1024*1024):
            for b in chunk:
                c = (c >> 8) ^ table[(c ^ b) & 255]
    return c ^ 0xffffffff
expected = {"common": (0x5d72435f,0xcd6cf1a9,0xf5cb7cde),
            "ww": (0xa279b24d,0x536a7fb8,0x2fdc5e1b)}
jobs = []
for region, root in (("common",rom),("ww",dlc)):
    for name,size,checksum in zip(names,sizes[region],expected[region]):
        rel = pathlib.Path(region)/"textures/PC_TXN_UP"/name
        p = src/rel
        if not p.is_file() or p.stat().st_size != size:
            raise SystemExit(f"Missing or unexpected PC archive: {p}")
        print(f"Verifying {p}",flush=True)
        if crc(p) != checksum:
            raise SystemExit(f"PC archive CRC mismatch: {p}")
        jobs.append((p,root/rel))
for p,d in jobs:
    d.parent.mkdir(parents=True,exist_ok=True)
    if d.is_symlink():
        raise SystemExit(f"Refusing existing symlink: {d}")
    fd,tmp = tempfile.mkstemp(dir=d.parent)
    os.close(fd)
    try:
        shutil.copyfile(p,tmp)
        os.replace(tmp,d)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)
    print(f"Imported {d}",flush=True)
PY
    # Separate cache from Switch-only builds.
    BUILD_SUFFIX="-pc"
else
    BUILD_SUFFIX=""
    [ ! -e "$DUMP/RomFS/common/textures/PC_TXN_UP" ] || fail "PC archives already in dump; use a clean workspace for Switch-only builds"
fi

echo "=== BUILDING MGS4 ==="

ICON=()
if [ -f "$WORK/dump/program_2/icon.jpg" ]; then
    ICON=(--icon "$WORK/dump/program_2/icon.jpg")
fi

if [ "$target" != 2 ]; then
if [ "$target" != 2 ] && { [ -e "$WORK/MGS4.app" ] || [ -L "$WORK/MGS4.app" ]; }; then
    backup=$(mktemp -d "$WORK/app-backup.XXXXXXXX")
    mv "$WORK/MGS4.app" "$backup/"
    echo "Previous app saved in $backup"
fi
"$PYTHON" "$REPO/scripts/build_ipa_from_nsp.py" \
"$WORK/game" \
--platform mac-app \
--title-id 0100D0B01C4F4002 \
-p v393216 \
--app-name "Metal Gear Solid 4" \
"${ICON[@]}" \
--work-dir "$WORK/build$BUILD_SUFFIX" \
--provisional \
--no-prebake \
--keep-extracted \
--progress lines \
-o "$WORK/MGS4.app" \
2>&1 | tee "$WORK/logs/build.log"

test -x "$WORK/MGS4.app/Contents/MacOS/dmhost"
if [ -n "$DLC_DUMP" ]; then
    AOC="$WORK/MGS4.app/Contents/Resources/aoc"
    mkdir -p "$AOC"
    [ ! -e "$AOC/1" ] && [ ! -L "$AOC/1" ] || fail "DLC destination already exists"
    mkdir "$AOC/1"
    cp -R "$DLC_DUMP/ww" "$AOC/1/"
    codesign --force --sign - "$WORK/MGS4.app"
fi
codesign --verify --deep --strict "$WORK/MGS4.app"
fi
if [ "$target" != 1 ]; then
    AOC_STAGE="$WORK/game-aoc$BUILD_SUFFIX"
    mkdir -p "$AOC_STAGE/1"
    if [ ! -d "$AOC_STAGE/1/ww" ]; then cp -R "$DLC_DUMP/ww" "$AOC_STAGE/1/"; fi
    [ -d "$AOC_STAGE/1/ww/bank/nx" ] || fail "Incomplete staged DLC"
    if [ -e "$WORK/MGS4.ipa" ]; then
        backup=$(mktemp -d "$WORK/ipa-backup.XXXXXXXX")
        mv "$WORK/MGS4.ipa" "$backup/"
    fi
    DM_MGS4_AOC_DIR="$AOC_STAGE" "$PYTHON" "$REPO/scripts/build_ipa_from_nsp.py" \
        "$WORK/game" --platform ios --title-id 0100D0B01C4F4002 -p v393216 \
        --app-name "Metal Gear Solid 4" "${ICON[@]}" --work-dir "$WORK/build-ios$BUILD_SUFFIX" \
        --provisional --no-prebake --keep-extracted --progress lines \
        -o "$WORK/MGS4.ipa" 2>&1 | tee "$WORK/logs/build-ios.log"
    test -s "$WORK/MGS4.ipa"
fi
echo
echo "========================================"
echo "  BUILD COMPLETE"
[ "$target" = 2 ] || echo "  $WORK/MGS4.app"
[ "$target" = 1 ] || echo "  $WORK/MGS4.ipa (unsigned)"
echo "========================================"
