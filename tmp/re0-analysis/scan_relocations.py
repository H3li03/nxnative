import struct

path = "tmp/re0-analysis/main.elf"
data = open(path, "rb").read()

eh = struct.unpack_from("<16sHHIQQQIHHHHHH", data, 0)
phoff, phentsize, phnum = eh[5], eh[9], eh[10]

loads = []
dynamic = None

for i in range(phnum):
    p = struct.unpack_from("<IIQQQQQQ", data, phoff + i * phentsize)
    typ, flags, off, va, pa, filesz, memsz, align = p
    if typ == 1:
        loads.append((va, va + filesz, off))
    elif typ == 2:
        dynamic = (off, filesz)

def file_offset(va):
    for start, end, off in loads:
        if start <= va < end:
            return off + va - start
    raise ValueError(f"Indirizzo non mappato: {va:#x}")

if not dynamic:
    raise SystemExit("PT_DYNAMIC non trovato")

doff, dsize = dynamic
tags = {}

for pos in range(doff, doff + dsize, 16):
    tag, val = struct.unpack_from("<qQ", data, pos)
    if tag == 0:
        break
    tags[tag] = val

rela = tags.get(7)
relasz = tags.get(8, 0)
relaent = tags.get(9, 24)
jmprel = tags.get(23)
pltrelsz = tags.get(2, 0)

print(f"DT_RELA={rela!r} size={relasz:#x} entry={relaent}")
print(f"DT_JMPREL={jmprel!r} size={pltrelsz:#x}")

targets = {0x1284468, 0x1285650}
found = 0

def scan(address, size, label):
    global found
    if address is None or size == 0:
        print(f"\n{label}: non presente")
        return

    if relaent != 24:
        raise ValueError(f"DT_RELAENT inatteso: {relaent}")

    off = file_offset(address)
    count = size // 24
    print(f"\n{label}: {count} relocation")

    for i in range(count):
        r_offset, r_info, addend = struct.unpack_from(
            "<QQq", data, off + i * 24
        )
        r_type = r_info & 0xffffffff
        sym = r_info >> 32

        if r_offset in targets or 0x1284000 <= r_offset < 0x1286000:
            print(
                f"target={r_offset:#x} type={r_type} "
                f"sym={sym} addend={addend:#x}"
            )
            found += 1

scan(rela, relasz, "RELA")
scan(jmprel, pltrelsz, "JMPREL")

print(f"\nCorrispondenze nella zona globale: {found}")
