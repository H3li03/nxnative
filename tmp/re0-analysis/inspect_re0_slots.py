import struct

data = open("tmp/re0-analysis/main.elf", "rb").read()
eh = struct.unpack_from("<16sHHIQQQIHHHHHH", data, 0)
phoff, phentsize, phnum = eh[5], eh[9], eh[10]

loads = []
dynamic = None

for i in range(phnum):
    p = struct.unpack_from("<IIQQQQQQ", data, phoff + i * phentsize)
    typ, flags, off, va, pa, fs, ms, align = p
    if typ == 1:
        loads.append((va, va + fs, off))
    elif typ == 2:
        dynamic = (off, fs)

def file_offset(va, size=1):
    for start, end, off in loads:
        if start <= va and va + size <= end:
            return off + va - start
    return None

tags = {}
doff, dsize = dynamic
for p in range(doff, doff + dsize, 16):
    tag, val = struct.unpack_from("<qQ", data, p)
    if tag == 0:
        break
    tags[tag] = val

def symbol(index):
    symtab = tags.get(6)
    strtab = tags.get(5)
    syment = tags.get(11, 24)
    if not symtab or not strtab:
        return "dynsym/string table unavailable"
    off = file_offset(symtab + index * syment, 24)
    if off is None:
        return "symbol outside file-backed segment"
    name, info, other, shndx, value, size = struct.unpack_from(
        "<IBBHQQ", data, off
    )
    so = file_offset(strtab + name)
    if so is None:
        return f"value={value:#x} size={size:#x} name-unmapped"
    end = data.find(b"\0", so)
    label = data[so:end].decode("utf-8", "replace")
    return f"name={label!r} value={value:#x} size={size:#x} shndx={shndx}"

out = []
out.append("=== Dynamic symbols for dispatch slots ===")
for i in (33, 34, 35):
    out.append(f"symbol[{i}]: {symbol(i)}")

base = 0x1baac60
out.append(f"\n=== Static object at {base:#x} ===")
for off in range(0, 0x100, 8):
    pos = file_offset(base + off, 8)
    if pos is None:
        out.append(f"+{off:#04x}: not file-backed (possibly BSS)")
        continue
    q = struct.unpack_from("<Q", data, pos)[0]
    f = struct.unpack_from("<f", data, pos)[0]
    out.append(f"+{off:#04x}: qword={q:#018x} float={f:g}")

result = "\n".join(out) + "\n"
open("tmp/re0-analysis/re0_slot_object_inspection.txt", "w").write(result)
print(result)
