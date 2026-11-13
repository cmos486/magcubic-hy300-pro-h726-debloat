#!/usr/bin/env python3
"""Lista (solo lectura) el contenido de una imagen Allwinner IMAGEWTY (update.img de PhoenixSuit).

No extrae ni modifica nada: lee la cabecera global y las cabeceras de 1024 bytes
de cada fichero y muestra maintype/subtype/nombre/tamaño/offset.

Uso: python3 -I imagewty_list.py update.img
"""
import struct
import sys

HDR = 1024


def cstr(b):
    return b.split(b"\0", 1)[0].decode("ascii", "replace")


def main(path):
    with open(path, "rb") as f:
        head = f.read(HDR)
        if head[:8] != b"IMAGEWTY":
            sys.exit(f"No es IMAGEWTY en claro (magic={head[:8]!r}); puede estar cifrada")
        hver, hsize, ram_base, version, image_size, img_hdr_size = struct.unpack_from("<6I", head, 8)
        # Formato v3 y posteriores (0x300, 0x417...): pid/vid/hwid/fwid desde 0x24, num_files en 0x3C
        pid, vid, hwid, fwid = struct.unpack_from("<4I", head, 0x24)
        num_files = struct.unpack_from("<I", head, 0x3C)[0]
        print(f"header_version=0x{hver:x} image_size={image_size}")
        print(f"pid=0x{pid:x} vid=0x{vid:x} hardware_id=0x{hwid:x} firmware_id=0x{fwid:x} num_files={num_files}")
        print(f"{'#':>3} {'maintype':<9} {'subtype':<17} {'stored':>11} {'original':>11} {'offset':>11}  filename")
        for i in range(num_files):
            f.seek(HDR * (i + 1))
            h = f.read(HDR)
            maintype = cstr(h[8:16])
            subtype = cstr(h[16:32])
            fname = cstr(h[0x24:0x24 + 256])
            stored, original, offset = (struct.unpack_from("<I", h, o)[0] for o in (0x124, 0x12C, 0x134))
            print(f"{i:>3} {maintype:<9} {subtype:<17} {stored:>11} {original:>11} {offset:>11}  {fname}")


if __name__ == "__main__":
    main(sys.argv[1])
