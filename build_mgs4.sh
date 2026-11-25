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
read -e -r -p "Workspace [$HOME/MGS4-Native]: " WORK
WORK=$(normalize "${WORK:-$HOME/MGS4-Native}")
mkdir -p "$WORK"
WORK=$(cd "$WORK" && pwd -P)
DUMP="$WORK/dump/program_2"
mkdir -p "$WORK/logs" "$WORK/build" "$WORK/dump" "$WORK/game/updates/393216"
if [ -e "$WORK/MGS4.app" ] || [ -L "$WORK/MGS4.app" ]; then
    read -r -p "Existing app will be moved to a backup. Continue? [y/N] " answer
    case "$answer" in y|Y) ;; *) exit 1 ;; esac
fi
if [ -f "$DUMP/ExeFS/main" ] && [ -d "$DUMP/RomFS" ]; then
    read -r -p "Reuse existing dump (must be program 4002, update 393216)? [y/N] " answer
    case "$answer" in y|Y) reuse=1 ;; *) reuse=0 ;; esac
else
    reuse=0
fi
KEYS=$(ask_file "Path to prod.keys")
BASE=$(ask_file "Path to base NSP")
UPDATE=$(ask_file "Path to update NSP (v393216)")
DLC=$(ask_file "Path to multilingual NSP")
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
    read -r -p "Reuse existing multilingual dump (must match selected NSP)? [y/N] " answer
    case "$answer" in y|Y) ;; *) fail "Existing DLC dump protected. Move it aside first." ;; esac
else
    [ ! -e "$DLC_DUMP" ] || fail "Incomplete DLC dump; move it aside first."
    dotnet run --project "$REPO/dm/tools/nx_extract" -c Release -- \
        "$KEYS" --aoc "$DLC" "$DLC_DUMP" 0100D0B01C4F5001 \
        2>&1 | tee "$WORK/logs/multilingual.log"
fi
[ -d "$DLC_DUMP/ww/bank/nx" ] || fail "Missing multilingual assets"

echo
echo "=== BUILDING MGS4 ==="

ICON=()
if [ -f "$WORK/dump/program_2/icon.jpg" ]; then
    ICON=(--icon "$WORK/dump/program_2/icon.jpg")
fi

if [ -e "$WORK/MGS4.app" ] || [ -L "$WORK/MGS4.app" ]; then
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
--work-dir "$WORK/build" \
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
echo
echo "========================================"
echo "  BUILD COMPLETE"
echo "  $WORK/MGS4.app"
echo "========================================"
