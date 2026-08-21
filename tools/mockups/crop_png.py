#!/usr/bin/env python3
"""Trim a PNG to the first N rows, in pure Python.

Headless Chrome paints only the layout viewport (window height minus ~87px of
chrome), so the mockups are shot in a taller window and the extra strip is cut
off here. Row filters only ever reference the previous row, so keeping a prefix
of scanlines needs no un-filtering — just a re-deflate and fresh CRCs."""
import struct, sys, zlib

def chunks(data):
    pos = 8
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        ctype = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        yield ctype, body

def chunk(ctype, body):
    return (struct.pack(">I", len(body)) + ctype + body +
            struct.pack(">I", zlib.crc32(ctype + body) & 0xFFFFFFFF))

def crop(path, keep_rows):
    raw = open(path, "rb").read()
    header, idat = None, b""
    for ctype, body in chunks(raw):
        if ctype == b"IHDR": header = body
        elif ctype == b"IDAT": idat += body

    width, height, depth, color, comp, filt, interlace = struct.unpack(">IIBBBBB", header)
    if interlace or depth != 8:
        raise SystemExit("unsupported PNG variant in " + path)
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color]
    stride = 1 + width * channels

    if keep_rows >= height:
        return
    pixels = zlib.decompress(idat)[:keep_rows * stride]
    out = (b"\x89PNG\r\n\x1a\n" +
           chunk(b"IHDR", struct.pack(">IIBBBBB", width, keep_rows, depth, color, comp, filt, 0)) +
           chunk(b"IDAT", zlib.compress(pixels, 9)) +
           chunk(b"IEND", b""))
    open(path, "wb").write(out)

if __name__ == "__main__":
    crop(sys.argv[1], int(sys.argv[2]))
