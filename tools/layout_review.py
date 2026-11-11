#!/usr/bin/env python3
"""Offline layout review: draws every Trailhead page and reports what collides or is cut off.

    python3 tools/layout_review.py [--only PATTERN] [--out DIR] [--no-draw]

Runs the test harness with TH_LAYOUT set (tests/layout.lua writes one JSON file per page and
look), then works out where every frame, texture and text lands from its anchors, the way the
game does, checks the result and draws it with the addon's own textures. The game's fonts are
not on disk, so a stand-in font is scaled to widths measured from a real screenshot.
"""
import argparse, glob, json, os, re, subprocess, sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = "/usr/share/fonts/noto/NotoSerif-Regular.ttf"
FONT_HEAD = "/usr/share/fonts/noto/NotoSerif-Bold.ttf"
K = 0.92          # stand-in font to game font width
S = 1.5           # pixels per UI unit in the drawings
LAYERS = {"BACKGROUND": 0, "BORDER": 1, "ARTWORK": 2, "OVERLAY": 3, "HIGHLIGHT": 9}
STRATA = {"BACKGROUND": 0, "LOW": 1, "MEDIUM": 2, "HIGH": 3, "DIALOG": 4, "FULLSCREEN": 5,
          "FULLSCREEN_DIALOG": 6, "TOOLTIP": 7}

_font1000 = ImageFont.truetype(FONT, 1000)
WIDTH = {c: _font1000.getlength(chr(c)) / 1000 * K for c in range(32, 127)}
OTHER = 0.6 * K


def write_widths(path):
    rows = ["[%d]=%.4f" % (c, w) for c, w in sorted(WIDTH.items())]
    with open(path, "w") as f:
        f.write("return {" + ",".join(rows) + ",other=%.4f}\n" % OTHER)


def line_width(text, size):
    return sum(WIDTH.get(ord(ch), OTHER) for ch in text) * size


def wrap(text, size, width):
    lines = []
    for para in text.split("\n"):
        words, cur = para.split(" "), ""
        for word in words:
            trial = word if not cur else cur + " " + word
            if cur and line_width(trial, size) > width:
                lines.append(cur)
                cur = word
            else:
                cur = trial
        lines.append(cur)
    return lines


class Scene:
    def __init__(self, path):
        data = json.load(open(path))
        self.name = data["name"]
        self.names = data["names"]
        self.errors = data["errors"]
        self.page = data["page"]
        self.o = {o["id"]: o for o in data["objects"]}
        self.kids = {}
        for o in data["objects"]:
            self.kids.setdefault(o["parent"], []).append(o["id"])
        self.rects = {}
        self.busy = set()
        self.info = {}  # text id -> dict(lines, natural, cut)

    # -- geometry ---------------------------------------------------------
    def scale(self, i):
        s = 1.0
        while i:
            o = self.o[i]
            s *= o.get("scale", 1) or 1
            i = o["parent"]
        return s

    def visible(self, i):
        while i:
            o = self.o[i]
            if not o["shown"]:
                return False
            i = o["parent"]
        return True

    def alpha(self, i):
        a = 1.0
        while i:
            o = self.o[i]
            a *= o.get("alpha", 1)
            i = o["parent"]
        return a

    def is_under(self, i, anc):
        while i:
            if i == anc:
                return True
            i = self.o[i]["parent"]
        return False

    def rect(self, i):
        """(left, bottom, right, top) in screen units, y up; None if it cannot be placed."""
        if i in self.rects:
            return self.rects[i]
        if i in self.busy or i not in self.o:
            return None
        self.busy.add(i)
        r = self._rect(i)
        self.busy.discard(i)
        self.rects[i] = r
        return r

    def _rect(self, i):
        o = self.o[i]
        sc = self.scale(i)
        if i == self.names.get("UIParent"):
            return (0.0, 0.0, o["w"], o["h"])
        if "all" in o:
            return self.rect(o["all"])
        hx, vy = {}, {}
        for pt, rel, rpt, x, y in o["points"]:
            rr = self.rect(rel) if rel > 0 else None
            if rr is None:
                continue
            l, b, r, t = rr
            ax = l if "LEFT" in rpt else r if "RIGHT" in rpt else (l + r) / 2
            ay = t if "TOP" in rpt else b if "BOTTOM" in rpt else (b + t) / 2
            ax, ay = ax + x * sc, ay + y * sc
            hx["L" if "LEFT" in pt else "R" if "RIGHT" in pt else "C"] = ax
            vy["T" if "TOP" in pt else "B" if "BOTTOM" in pt else "C"] = ay
        if not hx or not vy:
            if o.get("w") and o.get("h") and not o["points"] and o["kind"] != "Texture" and o["kind"] != "FontString":
                return None
            return None
        is_text = o["kind"] == "FontString"
        text = o.get("text") or ""
        size = float(o.get("size", 12)) * sc
        # width
        if "L" in hx and "R" in hx:
            w = hx["R"] - hx["L"]
            bound = True
        elif o.get("w"):
            w = o["w"] * sc
            bound = True
        else:
            w = max((line_width(t, size) for t in text.split("\n")), default=0) if is_text else 0
            bound = False
        if is_text:
            natural = max((line_width(t, size) for t in text.split("\n")), default=0)
            wraps = o.get("wrap", True)
            if bound and wraps:
                lines = wrap(text, size, w)
            else:
                lines = text.split("\n")
            cut = bound and not wraps and natural > w + 0.5
            clipped = False
            if o.get("maxlines") and len(lines) > o["maxlines"]:
                lines = lines[: int(o["maxlines"])]
                clipped = True
            spacing = o.get("spacing", 0) * sc
            h = len(lines) * size + (len(lines) - 1) * spacing
            self.info[i] = dict(lines=lines, natural=natural, cut=cut, clipped=clipped, bound=bound, size=size,
                                spacing=spacing)
        if "L" in hx:
            left = hx["L"]
        elif "R" in hx:
            left = hx["R"] - w
        else:
            left = hx["C"] - w / 2
        if "T" in vy and "B" in vy:
            top, bottom = vy["T"], vy["B"]
        else:
            if not is_text:
                h = (o.get("h") or 0) * sc
            top = vy["T"] if "T" in vy else vy["B"] + h if "B" in vy else vy["C"] + h / 2
            bottom = top - h
        return (left, bottom, left + w, top)

    # -- walking ----------------------------------------------------------
    def roots(self):
        ui = self.names.get("UIParent")
        out = []
        for i in self.kids.get(ui, []):
            o = self.o[i]
            if o["kind"] in ("Texture", "FontString") or not self.visible(i):
                continue
            r = self.rect(i)
            if r and r[2] - r[0] > 1 and r[3] - r[1] > 1 and self.has_art(i):
                out.append(i)
        return out

    def has_art(self, i):
        for k in self.kids.get(i, []):
            o = self.o[k]
            if not o["shown"]:
                continue
            if o["kind"] in ("Texture", "FontString"):
                return True
            if self.has_art(k):
                return True
        return False

    def order(self, root):
        """Everything visible under root, in drawing order."""
        out = []

        def walk(i):
            regions, frames = [], []
            for k in self.kids.get(i, []):
                o = self.o[k]
                if not o["shown"]:
                    continue
                if o["kind"] in ("Texture", "FontString"):
                    layer = LAYERS.get(o.get("layer") or "ARTWORK", 2)
                    if layer == 9:
                        continue
                    regions.append((layer, o.get("sub") or 0, 1 if o["kind"] == "FontString" else 0, k))
                else:
                    frames.append((STRATA.get(o.get("strata"), 2), o.get("level", 0), k))
            for _, _, _, k in sorted(regions):
                out.append(k)
            for _, _, k in sorted(frames):
                out.append(k)
                walk(k)

        out.append(root)
        walk(root)
        return out


# -- drawing --------------------------------------------------------------
_tex = {}


def texture(path):
    if path in _tex:
        return _tex[path]
    img = None
    if isinstance(path, str):
        m = re.match(r"Interface\\AddOns\\Trailhead\\(.*)$", path)
        if m:
            f = os.path.join(ROOT, "Trailhead", m.group(1).replace("\\", "/") + ".tga")
            if os.path.exists(f):
                img = Image.open(f).convert("RGBA")
    _tex[path] = img
    return img


_fonts = {}


def font(px, head):
    key = (round(px * 4), head)
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(FONT_HEAD if head else FONT, max(1, px))
    return _fonts[key]


def tint(img, color, alpha):
    r, g, b = [float(c) for c in (color[:3] if color else (1, 1, 1))]
    a = (float(color[3]) if color and len(color) > 3 and color[3] is not None else 1.0) * alpha
    bands = img.split()
    out = [bands[0].point(lambda v: v * r), bands[1].point(lambda v: v * g), bands[2].point(lambda v: v * b),
           bands[3].point(lambda v: v * a)]
    return Image.merge("RGBA", out)


def draw(scene, path):
    roots = scene.roots()
    if not roots:
        return None
    rs = [scene.rect(i) for i in roots]
    pad = 24
    L, B = min(r[0] for r in rs) - pad, min(r[1] for r in rs) - pad
    R, T = max(r[2] for r in rs) + pad, max(r[3] for r in rs) + pad
    W, Hh = int((R - L) * S), int((T - B) * S)
    canvas = Image.new("RGBA", (W, Hh), (58, 62, 70, 255))

    def px(r):
        return (int(round((r[0] - L) * S)), int(round((T - r[3]) * S)), int(round((r[2] - L) * S)),
                int(round((T - r[1]) * S)))

    for root in sorted(roots, key=lambda i: (STRATA.get(scene.o[i].get("strata"), 2), i)):
        for i in scene.order(root):
            o = scene.o[i]
            r = scene.rect(i)
            if r is None:
                continue
            x0, y0, x1, y1 = px(r)
            a = scene.alpha(i)
            if o["kind"] == "Texture":
                w, h = x1 - x0, y1 - y0
                if w < 1 and x1 - x0 >= 0 and (r[2] - r[0]) > 0.2:
                    w = 1
                if h < 1 and (r[3] - r[1]) > 0.2:
                    h = 1
                if w < 1 or h < 1 or w > 6000 or h > 6000:
                    continue
                if "solid" in o:
                    c = o["solid"]
                    v = o.get("vertex")
                    col = [float(c[k]) * (float(v[k]) if v and k < len(v) and v[k] is not None else 1) for k in range(3)]
                    al = (float(c[3]) if len(c) > 3 and c[3] is not None else 1) * a
                    tile = Image.new("RGBA", (w, h), tuple(int(max(0, min(1, k)) * 255) for k in col) + (int(al * 255),))
                elif "texture" in o:
                    img = texture(o["texture"])
                    if img is None:  # a game icon: a placeholder
                        tile = Image.new("RGBA", (w, h), (92, 104, 128, int(255 * a)))
                        ImageDraw.Draw(tile).rectangle((0, 0, w - 1, h - 1), outline=(150, 160, 185, int(255 * a)))
                    else:
                        c = o.get("coord") or [0, 1, 0, 1]
                        iw, ih = img.size
                        if "parchment" in o["texture"]:
                            tile = Image.new("RGBA", (w, h))
                            sw, sh = int(iw * S / 2), int(ih * S / 2)
                            small = img.resize((sw, sh))
                            for ty in range(0, h, sh):
                                for tx in range(0, w, sw):
                                    tile.paste(small, (tx, ty))
                        else:
                            box = (c[0] * iw, c[2] * ih, c[1] * iw, c[3] * ih)
                            tile = img.resize((w, h), Image.LANCZOS, box=box)
                        tile = tint(tile, o.get("vertex"), a)
                else:
                    continue
                canvas.alpha_composite(tile, (x0, y0)) if 0 <= x0 and 0 <= y0 and x0 + w <= W and y0 + h <= Hh else \
                    canvas.paste(Image.alpha_composite(canvas.crop((x0, y0, x0 + w, y0 + h)), tile), (x0, y0))
            elif o["kind"] in ("FontString", "EditBox"):
                info = scene.info.get(i)
                text = o.get("text") or ""
                if not text:
                    continue
                if info is None:  # an edit box
                    size = float(o.get("size", 12))
                    info = dict(lines=[text], size=size, spacing=0, cut=False, clipped=False)
                size = info["size"]
                f = font(size * S * K, o.get("style") == "head")
                c = o.get("color") or [1, 1, 1, 1]
                col = tuple(int(float(k) * 255) for k in c[:3]) + (int((float(c[3]) if len(c) > 3 else 1) * a * 255),)
                layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
                d = ImageDraw.Draw(layer)
                width = r[2] - r[0]
                for n, line in enumerate(info["lines"]):
                    if info["cut"] or (info["clipped"] and n == len(info["lines"]) - 1):
                        while line and line_width(line + "...", size) > width:
                            line = line[:-1]
                        line += "..."
                    lw = line_width(line, size)
                    jh = o.get("jh") or "CENTER"
                    lx = r[0] if jh == "LEFT" else r[2] - lw if jh == "RIGHT" else (r[0] + r[2] - lw) / 2
                    ly = r[3] - n * (size + info["spacing"])
                    d.text(((lx - L) * S, (T - ly + size * 0.82) * S), line, font=f, fill=col, anchor="ls")
                canvas.alpha_composite(layer)
    canvas.convert("RGB").save(path)
    return path


# -- checks ---------------------------------------------------------------
def overlap(a, b):
    w = min(a[2], b[2]) - max(a[0], b[0])
    h = min(a[3], b[3]) - max(a[1], b[1])
    return w, h


def on_badge(scene, i):
    """True when a text is centred on a round badge texture (a count on a disc)."""
    for p in scene.o[i].get("points") or []:
        rel = scene.o.get(p[1]) if p[1] is not None else None
        if rel and "circle" in str(rel.get("texture") or ""):
            return True
    return False


def check(scene):
    issues = []
    roots = scene.roots()
    texts, buttons, lines, seen = [], [], [], set()
    drawn = []
    for root in roots:
        drawn += scene.order(root)
    pos = {i: n for n, i in enumerate(drawn)}
    for i in drawn:
        o = scene.o[i]
        r = scene.rect(i)
        if r is None:
            if o["kind"] != "Texture" or o.get("texture") or o.get("solid"):
                if o["kind"] == "FontString" and not o.get("text"):
                    continue
                issues.append(("unplaced", "%s %s has no usable anchor" % (o["kind"], (o.get("text") or "")[:40])))
            continue
        if o["kind"] == "FontString" and (o.get("text") or "").strip():
            texts.append(i)
        elif o["kind"] == "Button" or o.get("click"):
            if r[2] - r[0] > 0 and r[3] - r[1] > 0:
                buttons.append(i)
        elif o["kind"] == "Texture" and "solid" in o:
            if min(r[2] - r[0], r[3] - r[1]) <= 2.01 and max(r[2] - r[0], r[3] - r[1]) > 30:
                lines.append(i)

    def label(i):
        o = scene.o[i]
        if o["kind"] == "FontString":
            return '"%s"' % (o.get("text") or "")[:46]
        for k in scene.kids.get(i, []):
            if scene.o[k]["kind"] == "FontString" and scene.o[k].get("text") and scene.o[k]["shown"]:
                return 'button "%s"' % scene.o[k]["text"][:30]
        r = scene.rect(i)
        return "button %dx%d" % (r[2] - r[0], r[3] - r[1])

    def box(i):
        """The nearest frame above i that draws a box (or is a button), and the page."""
        p = scene.o[i]["parent"]
        while p:
            o = scene.o[p]
            if o.get("panel") or o["kind"] == "Button":
                return p
            p = o["parent"]
        return None

    # A box that covers the page (the welcome) hides what is under it; anything else that
    # lies under a solid box is a finding.
    hidden = set()
    for c in drawn:
        o = scene.o[c]
        if not o.get("panel") or o["kind"] == "Button":
            continue
        solid = False
        for k in scene.kids.get(c, []):
            t = scene.o[k]
            if t["kind"] == "Texture" and t.get("layer") == "BACKGROUND" and t.get("sub") == -6 and t["shown"]:
                v = t.get("vertex") or [1, 1, 1, 1]
                solid = (len(v) < 4 or v[3] is None or float(v[3]) >= 0.9) and scene.alpha(c) >= 0.9
                break
        rc = scene.rect(c)
        if not solid or rc is None:
            continue
        big = (rc[2] - rc[0]) > 600 and (rc[3] - rc[1]) > 400
        for i in texts + buttons:
            if pos[i] > pos[c] or scene.is_under(i, c) or scene.is_under(c, i):
                continue
            # frames drawn earlier in the same parent chain are behind it only if not its ancestors
            r = scene.rect(i)
            w, h = overlap(r, rc)
            if w > 2 and h > 2:
                full = w >= (r[2] - r[0]) - 1 and h >= (r[3] - r[1]) - 1
                if big and full:
                    hidden.add(i)
                elif not big and scene.o[i]["kind"] == "FontString":
                    issues.append(("covered", "%s is covered by a box by %dx%d" % (label(i), w, h)))
    texts = [i for i in texts if i not in hidden]
    buttons = [i for i in buttons if i not in hidden]

    host = scene.page
    host_r = scene.rect(host) if host else None
    for i in texts:
        o, r, info = scene.o[i], scene.rect(i), scene.info[i]
        if info["cut"]:
            issues.append(("cut", "%s is cut off: needs %d, has %d" % (label(i), info["natural"], r[2] - r[0])))
        if info["clipped"]:
            issues.append(("cut", "%s runs past its %d lines" % (label(i), o["maxlines"])))
        b = box(i)
        if b:
            br = scene.rect(b)
            if br:
                over = max(br[0] - r[0], r[2] - br[2], br[1] - r[1], r[3] - br[3])
                # A count on a disc that sits on its box's corner is meant to stick out.
                if over > 1 and not on_badge(scene, i):
                    issues.append(("spill", "%s sticks %d out of its box (%s)" % (label(i), over, label(b))))
                elif scene.o[b]["kind"] == "Button" and scene.o[i]["parent"] == b and not on_badge(scene, i):
                    room = min(r[0] - br[0], br[2] - r[2])
                    if room < 5 and (br[2] - br[0]) < 400:
                        issues.append(("tight", "%s has only %d beside it in its button" % (label(i), room)))
        if host_r and scene.is_under(i, host):
            over = max(host_r[0] - r[0], r[2] - host_r[2], host_r[1] - r[1], r[3] - host_r[3])
            if over > 1:
                issues.append(("offpage", "%s goes %d outside the page" % (label(i), over)))
    for n, a in enumerate(texts):
        ra = scene.rect(a)
        for b in texts[n + 1:]:
            rb = scene.rect(b)
            w, h = overlap(ra, rb)
            if w > 1.5 and h > 1.5:
                issues.append(("overlap", "%s overlaps %s by %dx%d" % (label(a), label(b), w, h)))
            elif h > 0.5 * min(ra[3] - ra[1], rb[3] - rb[1]) and -0.5 <= -w < 4 and w <= 1.5:
                issues.append(("close", "%s and %s are only %d apart" % (label(a), label(b), -w)))
        for b in buttons:
            if scene.is_under(a, b):
                continue
            rb = scene.rect(b)
            w, h = overlap(ra, rb)
            if w > 1.5 and h > 1.5 and pos[b] > pos[scene.o[a]["parent"]]:
                issues.append(("overlap", "%s is under %s by %dx%d" % (label(a), label(b), w, h)))
            elif w > 1.5 and h > 1.5:
                issues.append(("overlap", "%s lies over %s by %dx%d" % (label(a), label(b), w, h)))
        for l in lines:
            rl = scene.rect(l)
            w, h = overlap(ra, rl)
            if w > 3 and h > 0.3 and scene.o[l]["parent"] != scene.o[a]["parent"] or (w > 3 and h > 0.3):
                # a line under the last pixel of a text is fine; through it is not
                inside = min(ra[3] - rl[3], rl[1] - ra[1])
                # a number on a disc sits on the track that joins the discs
                if inside > 0.5 and not on_badge(scene, a):
                    issues.append(("line", "a line runs through %s" % label(a)))
    for n, a in enumerate(buttons):
        ra = scene.rect(a)
        for b in buttons[n + 1:]:
            if scene.is_under(a, b) or scene.is_under(b, a):
                continue
            rb = scene.rect(b)
            w, h = overlap(ra, rb)
            if w > 1 and h > 1:
                issues.append(("overlap", "%s overlaps %s by %dx%d" % (label(a), label(b), w, h)))
            elif not (scene.o[a].get("panel") and scene.o[b].get("panel")):
                pass  # rows of a list sit against each other on purpose
            elif (h > 4 and -3.5 < w <= 1) or (w > 4 and -1.5 < h <= 1):
                issues.append(("touch", "%s and %s touch (gap %d)" % (label(a), label(b), -min(w, h))))
        if host_r and scene.is_under(a, host):
            over = max(host_r[0] - ra[0], ra[2] - host_r[2], host_r[1] - ra[1], ra[3] - host_r[3])
            if over > 1:
                issues.append(("offpage", "%s goes %d outside the page" % (label(a), over)))
    if scene.errors:
        issues.append(("error", "%d Lua errors logged" % scene.errors))
    out = []
    for item in issues:
        if item not in seen:
            seen.add(item)
            out.append(item)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    ap.add_argument("--out", default="/tmp/th-layout")
    ap.add_argument("--no-draw", action="store_true")
    ap.add_argument("--draw", help="draw only pages matching this regular expression")
    ap.add_argument("--skip", default="", help="comma list of issue kinds to leave out")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    for old in glob.glob(os.path.join(args.out, "*.json")):
        os.remove(old)
    write_widths(os.path.join(args.out, "widths.lua"))
    env = dict(os.environ, TH_LAYOUT=args.out)
    if args.only:
        env["TH_LAYOUT_ONLY"] = args.only
    run = subprocess.run(["lua5.1", "tests/run.lua"], cwd=ROOT, env=env, capture_output=True, text=True)
    for line in run.stdout.splitlines():
        if line.startswith("layout") or "layout scene" in line or "FAIL" in line:
            print(line)
    skip = set(args.skip.split(","))
    merged = {}  # (page, kind, message) -> looks
    for path in sorted(glob.glob(os.path.join(args.out, "*.json"))):
        scene = Scene(path)
        page, look = scene.name.rsplit(".", 1)
        for kind, message in check(scene):
            if kind not in skip:
                merged.setdefault((page, kind, message), []).append(look)
        if not args.no_draw and (not args.draw or re.search(args.draw, scene.name)):
            draw(scene, path[:-5] + ".png")
    last = None
    for (page, kind, message), looks in sorted(merged.items()):
        if page != last:
            print("\n== " + page)
            last = page
        print("  [%s] %s%s" % (kind, message, "" if len(looks) == 3 else "  (" + ",".join(looks) + ")"))
    print("\n%d findings" % len(merged))


if __name__ == "__main__":
    main()
