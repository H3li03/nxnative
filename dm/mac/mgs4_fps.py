#!/usr/bin/env python3
"""Install the tested MGS4 Mac FPS selector into an existing app.
Usage: python3 dm/mac/mgs4_fps.py /path/to/Game.app /path/to/main.unlocked.v2.experimental.bin
Experimental, exact game build only. Run with the game closed.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

SHA = "5741460fc8a07e5ff25528c51a189ad2042e359b12187d5bd2c7dd11a30d3f67"
WRAPPER = r'''#!/bin/bash
set -euo pipefail
MAC=$(cd "$(dirname "$0")" && pwd)
DM="$MAC/../Resources/dm"
MODE=${DM_MGS4_CUSTOM_FPS:?Missing FPS selection}
PYTHON=$(cat "$DM/launcher-python.path")
"$PYTHON" - "$DM" "$MODE" <<'PY'
import sys,struct,hashlib,os,tempfile
from pathlib import Path
root=Path(sys.argv[1]); mode=sys.argv[2]
if mode not in ('0','30','60','120','144'): raise SystemExit('Invalid FPS: '+mode)
fps=int(mode)
b=bytearray((root/'main.launcher-v2.base.bin').read_bytes())
if hashlib.sha256(b).hexdigest() != '5741460fc8a07e5ff25528c51a189ad2042e359b12187d5bd2c7dd11a30d3f67': raise SystemExit('Wrong patch build')
if fps:
    struct.pack_into('<I',b,0x10e4,0x52800014|((1000000//fps)<<5))
    struct.pack_into('<I',b,0x1214,0x910fa2c8)
fd,tmp=tempfile.mkstemp(dir=root)
with os.fdopen(fd,'wb') as f: f.write(b)
os.chmod(tmp,0o644)
os.replace(tmp,root/'main.patched.bin')
print('MGS4 launcher integration: selected='+mode+' internal='+str(fps),flush=True)
PY
export DM_PRESENT_HZ=0 DM_PRESENT_LINK=0 DM_PRESENT_SCREEN=0 DM_SCREEN_MATCH=0 DM_MGS4_FPS=120 DM_FPS_TARGET=120
exec "$MAC/dmhost.original" "$@"
'''

def write(path, data, mode=0o644):
    fd, name = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as f:
            f.write(data)
        os.chmod(name, mode)
        os.replace(name, path)
    finally:
        if os.path.exists(name): os.unlink(name)

def main(app, base):
    mac = app / 'Contents/MacOS'
    dm = app / 'Contents/Resources/dm'
    host = mac / 'dmhost'
    original = mac / 'dmhost.original'
    config = dm / 'launcher.json'
    data = base.read_bytes()
    if hashlib.sha256(data).hexdigest() != SHA:
        raise SystemExit('Unsupported v2 patch')
    d = json.loads(config.read_text())
    if d.get('game','').upper() != '0100D0B01C4F4002':
        raise SystemExit('Not MGS4')
    rows = [s for s in d['settings'] if s['env'] in ('DM_MGS4_FPS','DM_MGS4_CUSTOM_FPS')]
    if len(rows) != 1: raise SystemExit('Unsupported launcher schema')
    if not original.exists():
        if host.read_bytes()[:4] != bytes.fromhex('cffaedfe'):
            raise SystemExit('Expected native ARM64 host; refusing to back up a wrapper')
        shutil.copy2(host, original)
    if original.read_bytes()[:4] != bytes.fromhex('cffaedfe'):
        raise SystemExit('Invalid original host')
    for p in (config, dm/'main.patched.bin', host):
        backup = p.with_name(p.name+'.before-universal-fps')
        if not backup.exists(): shutil.copy2(p, backup)
    rows[0].update(env='DM_MGS4_CUSTOM_FPS', default='60',
                   options=[[str(n),f'{n} FPS'] for n in (30,60,120,144)]+[['0','Unlocked']],
                   note='Experimental FPS limiter and cinematic timing fix.')
    write(dm/'main.launcher-v2.base.bin', data)
    write(dm/'launcher-python.path', (sys.executable+'\n').encode())
    write(config, (json.dumps(d,indent=2)+'\n').encode())
    write(host, WRAPPER.encode(), 0o755)
    print('Installed experimental MGS4 Mac selector. Re-sign if required.')

if __name__ == '__main__':
    if len(sys.argv)!=3: raise SystemExit(__doc__)
    main(Path(sys.argv[1]),Path(sys.argv[2]))
