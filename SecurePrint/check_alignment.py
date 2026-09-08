import sys
import struct
import zipfile
import os

def check_elf_alignment(filename):
    with open(filename, 'rb') as f:
        magic = f.read(4)
        if magic != b'\x7fELF':
            return
        
        ei_class = f.read(1)[0]
        # 1 = 32-bit, 2 = 64-bit
        f.seek(28 if ei_class == 1 else 32)
        phoff = struct.unpack('<I' if ei_class == 1 else '<Q', f.read(4 if ei_class == 1 else 8))[0]
        
        f.seek(42 if ei_class == 1 else 54)
        phentsize = struct.unpack('<H', f.read(2))[0]
        phnum = struct.unpack('<H', f.read(2))[0]
        
        for i in range(phnum):
            f.seek(phoff + i * phentsize)
            p_type = struct.unpack('<I', f.read(4))[0]
            if p_type == 1: # PT_LOAD
                if ei_class == 1: # 32-bit
                    f.seek(phoff + i * phentsize + 28)
                    p_align = struct.unpack('<I', f.read(4))[0]
                else: # 64-bit
                    f.seek(phoff + i * phentsize + 48)
                    p_align = struct.unpack('<Q', f.read(8))[0]
                
                print(f"{info.filename} - PT_LOAD alignment: {p_align} (0x{p_align:x})")
                if p_align < 16384:
                    print(f"WARNING: {info.filename} is NOT 16KB aligned (alignment is {p_align})")

if len(sys.argv) < 2:
    sys.exit(1)

apk_path = sys.argv[1]
with zipfile.ZipFile(apk_path, 'r') as z:
    for info in z.infolist():
        if info.filename.endswith('.so'):
            extracted = z.extract(info, 'elf_check')
            check_elf_alignment(extracted)
