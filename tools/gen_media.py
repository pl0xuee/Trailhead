#!/usr/bin/env python3
"""Generates Trailhead/Media/*.tga from vector sources.

Needs rsvg-convert, magick (ImageMagick 7) and chromium on PATH. Icons and the banner
landscape come from docs/mockups (template.html and the three theme CSS files), so the
game art and the design mockups cannot drift apart.

Every texture is an uncompressed 32-bit TGA, the format the Forever client loads.
Shape textures are white so the addon can tint them with the active theme's colours,
and are drawn at half size in game (64 px texture = 32 UI units) to stay sharp.
"""
import os, re, struct, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Trailhead", "Media")
MOCK = os.path.join(ROOT, "docs", "mockups")
PREVIEW = {}  # name -> (w, h, rgba), for the contact sheet


def run(*args, data=None):
    return subprocess.run(args, check=True, capture_output=True, input=data).stdout


def svg_rgba(svg, w, h):
    png = run("rsvg-convert", "-w", str(w), "-h", str(h), data=svg.encode())
    return run("magick", "png:-", "-depth", "8", "rgba:-", data=png)


def write_tga(name, w, h, rgba, white=False, alpha=None):
    px = bytearray(rgba)
    assert len(px) == w * h * 4, (name, len(px), w, h)
    if white:
        for i in range(0, len(px), 4):
            px[i] = px[i + 1] = px[i + 2] = 255
    if alpha is not None:
        for i in range(3, len(px), 4):
            px[i] = alpha[i]
    PREVIEW[name] = (w, h, bytes(px))
    out = bytearray(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8))
    for y in range(h - 1, -1, -1):  # bottom row first
        row = px[y * w * 4:(y + 1) * w * 4]
        row[0::4], row[2::4] = row[2::4], row[0::4]  # RGBA -> BGRA
        out += row
    with open(os.path.join(OUT, name + ".tga"), "wb") as f:
        f.write(out)


def svg(body, w=64, h=None, defs=""):
    h = h or w
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
            f'viewBox="0 0 {w} {h}">{defs}{body}</svg>')


def fade(y2):
    return ('<defs><linearGradient id="g" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" '
            f'y2="{y2}"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#fff" '
            'stop-opacity="0"/></linearGradient></defs>')


def shape(name, fill, line, margin):
    """fill: solid shape. line: 1-unit border. top: the border fading out downwards (a top highlight)."""
    write_tga(name + "-fill", 64, 64, svg_rgba(svg(fill.format("#fff")), 64, 64), white=True)
    write_tga(name + "-line", 64, 64, svg_rgba(svg(line.format("#fff")), 64, 64), white=True)
    write_tga(name + "-top", 64, 64, svg_rgba(svg(line.format("url(#g)"), defs=fade(margin - 2)), 64, 64), white=True)


def rounded(name, r, margin):
    shape(name,
          f'<rect width="64" height="64" rx="{r}" fill="{{}}"/>',
          f'<rect x="1" y="1" width="62" height="62" rx="{max(r - 1, 0.5)}" fill="none" stroke="{{}}" stroke-width="2"/>',
          margin)


def poly(name, pts, inner, margin):
    shape(name,
          f'<polygon points="{pts}" fill="{{}}"/>',
          f'<polygon points="{inner}" fill="none" stroke="{{}}" stroke-width="2" stroke-linejoin="miter"/>',
          margin)


def shapes():
    # name = corner radius in UI units; texture radius is twice that.
    rounded("r12", 24, 28)
    rounded("r7", 14, 18)
    rounded("r4", 8, 12)
    rounded("r2", 4, 8)
    c = 20  # card: top-right and bottom-left corners cut
    poly("cut10", f"0,0 {64-c},0 64,{c} 64,64 {c},64 0,{64-c}",
         f"1,1 {64-c-.4},1 63,{c+.4} 63,63 {c+.4},63 1,{64-c-.4}", 24)
    c = 12  # button: top-left and bottom-right corners cut
    poly("cutb6", f"{c},0 64,0 64,{64-c} {64-c},64 0,64 0,{c}",
         f"{c+.4},1 63,1 63,{64-c-.4} {64-c-.4},63 1,63 1,{c+.4}", 16)
    write_tga("circle-fill", 64, 64, svg_rgba(svg('<circle cx="32" cy="32" r="32" fill="#fff"/>'), 64, 64), white=True)
    write_tga("circle-line", 64, 64, svg_rgba(svg('<circle cx="32" cy="32" r="31" fill="none" stroke="#fff" stroke-width="2"/>'), 64, 64), white=True)
    write_tga("circle-top", 64, 64, svg_rgba(svg('<circle cx="32" cy="32" r="31" fill="none" stroke="url(#g)" stroke-width="2"/>', defs=fade(30)), 64, 64), white=True)
    write_tga("ring", 128, 128, svg_rgba(svg('<circle cx="64" cy="64" r="56" fill="none" stroke="#fff" stroke-width="10"/>', 128), 128, 128), white=True)
    write_tga("bar", 32, 16, svg_rgba(svg('<rect width="32" height="16" rx="8" fill="#fff"/>', 32, 16), 32, 16), white=True)
    blur = ('<defs><filter id="b" x="-100%" y="-100%" width="300%" height="300%">'
            '<feGaussianBlur stdDeviation="13"/></filter></defs>')
    write_tga("shadow", 128, 128, svg_rgba(svg('<rect x="40" y="40" width="48" height="48" rx="10" fill="#fff" filter="url(#b)"/>', 128, defs=blur), 128, 128), white=True)
    glow = ('<defs><radialGradient id="r"><stop offset="0" stop-color="#fff"/><stop offset=".5" stop-color="#fff" '
            'stop-opacity=".35"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient></defs>')
    write_tga("glow", 64, 64, svg_rgba(svg('<circle cx="32" cy="32" r="32" fill="url(#r)"/>', defs=glow), 64, 64), white=True)


EXTRA_ICONS = {
    "check": '<path d="M5 12.500l4.500 4.500L19 7.500"/>',
    "plus": '<path d="M12 5v14M5 12h14"/>',
    "minus": '<path d="M5 12h14"/>',
    "sword": '<path d="M14.500 17.500L3 6V3h3l11.500 11.500"/><path d="M13 19l6-6"/><path d="M16 16l4 4"/><path d="M19 21l2-2"/>',
    "shield": '<path d="M12 3l7.500 2.800v5.700c0 4.600-3.100 7.900-7.500 9.500-4.400-1.600-7.500-4.900-7.500-9.500V5.800z"/><path d="M12 7.500v9"/>',
}


def icons(template):
    found = dict(re.findall(r'<symbol id="(\w+)" viewBox="0 0 24 24">(.*?)</symbol>', template, re.S))
    found.update(EXTRA_ICONS)
    for name, body in sorted(found.items()):
        body = body.replace("currentColor", "#fff")
        doc = ('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 24 24" fill="none" '
               f'stroke="#fff" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">{body}</svg>')
        write_tga("icon-" + name, 64, 64, svg_rgba(doc, 64, 64), white=True)
    tri = found["tri"]
    logo = ('<defs><linearGradient id="l" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffd77a"/>'
            '<stop offset="1" stop-color="#e89a2c"/></linearGradient></defs>'
            '<rect x="2" y="2" width="60" height="60" rx="15" fill="url(#l)"/>'
            '<g transform="translate(14 13) scale(1.5)" fill="none" stroke="#2a1a05" stroke-width="2.3" '
            f'stroke-linecap="round" stroke-linejoin="round">{tri}</g>')
    write_tga("logo", 64, 64, svg_rgba(svg(logo), 64, 64))
    return sorted(found)


HERO_W, HERO_H = 778, 132  # banner size in UI units; must match Modules/Home.lua
HERO_RADIUS = {"night": 12, "journal": 4, "ember": 2}


def heroes(template):
    art = re.search(r'<svg class="art".*?</svg>', template, re.S).group(0)
    with tempfile.TemporaryDirectory() as tmp:
        for name, radius in HERO_RADIUS.items():
            css = open(os.path.join(MOCK, name + ".css")).read()
            page = ('<!doctype html><html><head><meta charset="utf-8"><style>' + css +
                    'html,body{margin:0;background:#000}'
                    f'.hero{{width:{HERO_W}px;height:{HERO_H}px;position:relative;overflow:hidden}}'
                    '.hero svg{position:absolute;inset:0;width:100%;height:100%}'
                    '.shade{position:absolute;inset:0;background:var(--hero-shade)}'
                    f'</style></head><body class="{name}"><div class="hero">{art}<div class="shade"></div></div></body></html>')
            html, shot = os.path.join(tmp, name + ".html"), os.path.join(tmp, name + ".png")
            open(html, "w").write(page)
            subprocess.run(["chromium", "--headless=new", "--disable-gpu", "--hide-scrollbars",
                            "--force-device-scale-factor=2", "--window-size=1000,500",
                            "--screenshot=" + shot, "file://" + html], check=True, capture_output=True)
            rgba = run("magick", shot, "-crop", f"{HERO_W*2}x{HERO_H*2}+0+0", "+repage",
                       "-resize", "1024x256!", "-depth", "8", "rgba:-")
            rx, ry = radius * 1024 / HERO_W, radius * 256 / HERO_H
            mask = svg_rgba(svg(f'<rect width="1024" height="256" rx="{rx:.2f}" ry="{ry:.2f}" fill="#fff"/>', 1024, 256), 1024, 256)
            write_tga("hero-" + name, 1024, 256, rgba, alpha=mask)


def parchment():
    noise = ("<filter id='n' x='0' y='0' width='100%' height='100%'><feTurbulence type='fractalNoise' "
             "baseFrequency='.03 .05' numOctaves='4' seed='7' stitchTiles='stitch'/>"
             "<feColorMatrix values='0 0 0 0 .42  0 0 0 0 .28  0 0 0 0 .1  0 0 0 .55 -.12'/></filter>"
             "<rect width='256' height='256' filter='url(#n)'/>")
    write_tga("parchment", 256, 256, svg_rgba(svg(noise, 256), 256, 256))


def contact_sheet(path):
    """A preview of every texture on a mid-grey board, for checking by eye."""
    cmd = ["magick", "-size", "1400x900", "xc:#4a5568"]
    x = y = 10
    rowh = 0
    with tempfile.TemporaryDirectory() as tmp:
        for name in sorted(PREVIEW):
            w, h, rgba = PREVIEW[name]
            raw = os.path.join(tmp, name + ".rgba")
            open(raw, "wb").write(rgba)
            dw, dh = (w // 2, h // 2) if w > 256 else (w, h)
            if x + dw > 1390:
                x, y, rowh = 10, y + rowh + 10, 0
            cmd += ["(", "-size", f"{w}x{h}", "-depth", "8", "rgba:" + raw, "-resize", f"{dw}x{dh}", ")",
                    "-geometry", f"+{x}+{y}", "-composite"]
            x += dw + 10
            rowh = max(rowh, dh)
        subprocess.run(cmd + [path], check=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    template = open(os.path.join(MOCK, "template.html")).read()
    shapes()
    names = icons(template)
    heroes(template)
    parchment()
    if len(sys.argv) > 1:
        contact_sheet(sys.argv[1])
    total = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
    print(f"{len(os.listdir(OUT))} textures, {total // 1024} KB; icons: {' '.join(names)}")


if __name__ == "__main__":
    main()
