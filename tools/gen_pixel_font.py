#!/usr/bin/env python3
"""Generate Godot 4 BMFont (assets/fonts/pixel9.fnt + pixel9.png) and 17 pixel icons
(assets/icons/*.png) directly from Cinderwatch's 70-pixelfont.js.

Usage:
    python3 tools/gen_pixel_font.py [path/to/70-pixelfont.js]
"""
import os
import re
import sys
import struct
import zlib

DEFAULT_SRC = "/tmp/cinderwatch_extract/cinderwatch-main/src/70-pixelfont.js"


def write_png(path: str, width: int, height: int, rgba_bytes: bytes) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw.extend(rgba_bytes[y * stride : (y + 1) * stride])

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def parse_hex_color(h: str) -> tuple[int, int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255


def extract_src_glyphs(js: str) -> dict[str, str]:
    m = re.search(r"const SRC = \{(.*?)\n  \};", js, re.S)
    assert m, "Could not find SRC table in 70-pixelfont.js"
    body = m.group(1)
    glyphs: dict[str, str] = {}
    # Match entries like '!': '#/#/#/#/#/./#', or "'": '#/#', or '\\': '...'
    for line in body.splitlines():
        line = line.strip()
        if not line or line.startswith("//"):
            continue
        em = re.match(r"""^(['"])((?:\\.|(?!\1).)*)\1\s*:\s*'([^']*)'""", line)
        if not em:
            continue
        raw_key = em.group(2)
        val = em.group(3)
        if raw_key == r"\\":
            ch = "\\"
        elif raw_key == r"\'":
            ch = "'"
        else:
            ch = raw_key
        glyphs[ch] = val
    return glyphs


def extract_palette(js: str) -> dict[str, tuple[int, int, int, int]]:
    m = re.search(r"const PAL = \{(.*?)\n  \};", js, re.S)
    assert m, "Could not find PAL table in 70-pixelfont.js"
    pal: dict[str, tuple[int, int, int, int]] = {}
    for km in re.finditer(r"([A-Za-z]):\s*'(#[0-9a-fA-F]{6})'", m.group(1)):
        pal[km.group(1)] = parse_hex_color(km.group(2))
    return pal


def extract_icons(js: str) -> dict[str, list[str]]:
    m = re.search(r"const ICONS = \{(.*?)\n  \};", js, re.S)
    assert m, "Could not find ICONS table in 70-pixelfont.js"
    icons: dict[str, list[str]] = {}
    for im in re.finditer(r"(\w+):\s*\[(.*?)\]", m.group(1), re.S):
        name = im.group(1)
        rows = re.findall(r"'([^']+)'", im.group(2))
        icons[name] = rows
    return icons


def build_font(glyphs: dict[str, str], out_dir: str) -> None:
    LINE = 9
    GAP = 1
    # Also alias em-dash '—' to en-dash '–' if needed
    if "–" in glyphs and "—" not in glyphs:
        glyphs["—"] = glyphs["–"]

    parsed: list[tuple[int, int, int, int, list[str]]] = []
    # Space (ASCII 32): width 3, empty
    parsed.append((32, 0, 0, 0, []))
    for ch, def_str in glyphs.items():
        off = 0
        s = def_str
        if len(s) > 1 and s[1] == ":" and "0" <= s[0] <= "9":
            off = int(s[0])
            s = s[2:]
        rows = s.split("/")
        w = max((len(r) for r in rows), default=0)
        h = len(rows)
        parsed.append((ord(ch), w, h, off, rows))

    parsed.sort(key=lambda x: x[0])

    # Pack into a 128x128 atlas with 1px padding
    atlas_w = 128
    pad = 1
    cx, cy = pad, pad
    row_h = 0
    placements: list[tuple[int, int, int, int, int, int, int, list[str]]] = []
    for code, w, h, off, rows in parsed:
        if code == 32:
            placements.append((32, 0, 0, 0, 0, 0, 3 + GAP, []))
            continue
        if cx + w + pad > atlas_w:
            cx = pad
            cy += row_h + pad
            row_h = 0
        placements.append((code, cx, cy, w, h, off, w + GAP, rows))
        cx += w + pad
        row_h = max(row_h, h)

    atlas_h = 1
    while atlas_h < cy + row_h + pad:
        atlas_h *= 2

    buf = bytearray(atlas_w * atlas_h * 4)
    for code, px, py, w, h, off, xadv, rows in placements:
        for ry, r in enumerate(rows):
            for rx, ch in enumerate(r):
                if ch == "#":
                    idx = ((py + ry) * atlas_w + (px + rx)) * 4
                    buf[idx : idx + 4] = b"\xff\xff\xff\xff"

    png_path = os.path.join(out_dir, "pixel9.png")
    write_png(png_path, atlas_w, atlas_h, bytes(buf))

    fnt_lines = [
        f'info face="Pixel9" size={LINE} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0',
        f"common lineHeight={LINE} base=8 scaleW={atlas_w} scaleH={atlas_h} pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4",
        'page id=0 file="pixel9.png"',
        f"chars count={len(placements)}",
    ]
    for code, px, py, w, h, off, xadv, _ in placements:
        fnt_lines.append(
            f"char id={code:<5d} x={px:<4d} y={py:<4d} width={w:<3d} height={h:<3d} "
            f"xoffset=0 yoffset={off:<2d} xadvance={xadv:<3d} page=0 chnl=15"
        )
    fnt_path = os.path.join(out_dir, "pixel9.fnt")
    with open(fnt_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(fnt_lines) + "\n")
    print(f"Generated {fnt_path} & {png_path} ({atlas_w}x{atlas_h}, {len(placements)} glyphs)")


def build_icons(icons: dict[str, list[str]], pal: dict[str, tuple[int, int, int, int]], out_dir: str) -> None:
    os.makedirs(out_dir, exist_ok=True)
    for name, rows in icons.items():
        h = len(rows)
        w = max((len(r) for r in rows), default=1)
        buf = bytearray(w * h * 4)
        for y, r in enumerate(rows):
            for x, ch in enumerate(r):
                col = pal.get(ch)
                if col:
                    idx = (y * w + x) * 4
                    buf[idx : idx + 4] = bytes(col)
        write_png(os.path.join(out_dir, f"{name}.png"), w, h, bytes(buf))
    print(f"Generated {len(icons)} pixel icons in {out_dir}: {', '.join(icons.keys())}")


def main() -> None:
    src_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC
    with open(src_path, "r", encoding="utf-8") as f:
        js = f.read()
    proj_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    glyphs = extract_src_glyphs(js)
    pal = extract_palette(js)
    icons = extract_icons(js)
    build_font(glyphs, os.path.join(proj_root, "assets", "fonts"))
    build_icons(icons, pal, os.path.join(proj_root, "assets", "icons"))


if __name__ == "__main__":
    main()
