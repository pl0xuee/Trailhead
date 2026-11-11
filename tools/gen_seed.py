#!/usr/bin/env python3
"""Writes Trailhead/Data/Seed.lua: the built-in list of services for "Find it".

Usage (run with -I, the inputs are untrusted data and are only read as text):
    python3 -I tools/gen_seed.py <waypoint_data_dir> <db2_csv_dir> <cats.json> [out.lua]

Sources, most trusted first: Forever.lua (positions players saw in WoW Forever), Curated.lua
(All The Things), Data.lua (pfQuest, 2006-era positions). Class and profession trainers come
from tools/forever_guides.tsv (Warcraft Tavern's WoW Forever guides); tools/vendcats.json (wiki vendor
category lists, fetched with the wikipedia API) labels vendors without a title. cats.json is no longer used.
DB2 tables give the zone maps and the flight points (TaxiNodes).
"""
import csv
import json
import math
import os
import re
import sys

csv.field_size_limit(10 ** 9)

DATA_DIR, DB2_DIR, CATS_JSON = sys.argv[1], sys.argv[2], sys.argv[3]
OUT = sys.argv[4] if len(sys.argv) > 4 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Trailhead", "Data", "Seed.lua")

# Letter used in the file for each Find it category.
CODE = {"trainer": "t", "vendor": "v", "repair": "r", "inn": "i", "flight": "f", "mailbox": "m",
        "bank": "b", "professions": "p", "auction": "a", "weapons": "w", "stable": "s"}
SERVICE_CATEGORY = {"innkeeper": "inn", "repair": "repair", "banker": "bank", "auctioneer": "auction",
                    "vendor": "vendor", "stablemaster": "stable", "mailbox": "mailbox", "flight": "flight"}
CONTINENT_UIMAP = {"0": "1415", "1": "1414"}  # DB2 Map id -> the continent's UiMap id
CITY_MAPS = {"1453", "1454", "1455", "1456", "1457", "1458"}
SAME_SPOT = 0.006
MAX_SPREAD_POINTS = 4  # more than this many scattered spawn points = a patrol or a mob

# Forever.lua titles that say what a row is when its services column does not.
FLIGHT_TITLES = ("wind rider master", "bat handler", "gryphon master", "zeppelin master", "hippogryph master",
                 "flight master", "flightmaster", "gryphon keeper", "wyvern master", "bat master")


def read_csv(name):
    with open(os.path.join(DB2_DIR, name + ".csv"), newline="", encoding="utf-8", errors="replace") as f:
        return list(csv.DictReader(f))


def section(text, key):
    match = re.search(r"\b" + key + r" = \[==\[\n(.*?)\]==\]", text, re.S)
    return match.group(1) if match else ""


def read(name):
    with open(os.path.join(DATA_DIR, name), encoding="utf-8", errors="replace") as f:
        return f.read()


# ---------------------------------------------------------------------------
# Maps: AreaTable id -> UiMap id, and the transform of each zone onto its continent.

uimap = {r["ID"]: r for r in read_csv("UiMap")}
maps = {r["ID"]: r for r in read_csv("Map")}
assignments = read_csv("UiMapAssignment")
area_rows = {r["ID"]: r for r in read_csv("AreaTable")}
area_names = {k: r["AreaName_lang"] for k, r in area_rows.items()}


def usable_assignment(a):
    """A zone map on a real open-world map (not an instance, battleground or scenario)."""
    m = maps.get(a["MapID"])
    u = uimap.get(a["UiMapID"])
    return bool(m and u and m["InstanceType"] == "0" and u["Type"] == "3")


zone_assign = {}  # UiMap id -> assignment (first order index wins)
for a in sorted(assignments, key=lambda r: int(r["OrderIndex"] or 0)):
    if usable_assignment(a):
        zone_assign.setdefault(a["UiMapID"], a)

area_to_map = {}
for a in assignments:
    if usable_assignment(a) and a["AreaID"] not in ("", "0"):
        area_to_map.setdefault(a["AreaID"], a["UiMapID"])
# Fall back on the name: an AreaTable zone whose name equals a zone map's name.
name_to_map = {}
for ui_id, row in uimap.items():
    if ui_id in zone_assign:
        name_to_map.setdefault(row["Name_lang"], ui_id)


def zone_side(ui):
    """"A" or "H" when the zone belongs to one faction (AreaTable FactionGroupMask 2 or 4)."""
    area = zone_assign[ui]["AreaID"]
    mask = area_rows.get(area, {}).get("FactionGroupMask", "0")
    return {"2": "A", "4": "H"}.get(mask, "")


def map_for_area(area):
    area = str(area)
    if area in area_to_map:
        return area_to_map[area]
    return name_to_map.get(area_names.get(area, ""))


def region(a):
    r = [float(a["Region_%d" % i]) for i in range(6)]
    u = [float(a["UiMin_0"]), float(a["UiMin_1"]), float(a["UiMax_0"]), float(a["UiMax_1"])]
    return r, u


def to_world(a, x, y):
    r, u = region(a)
    wy = r[4] - (x - u[0]) / (u[2] - u[0]) * (r[4] - r[1])
    wx = r[3] - (y - u[1]) / (u[3] - u[1]) * (r[3] - r[0])
    return wx, wy


def from_world(a, wx, wy):
    r, u = region(a)
    x = u[0] + (r[4] - wy) / (r[4] - r[1]) * (u[2] - u[0])
    y = u[1] + (r[3] - wx) / (r[3] - r[0]) * (u[3] - u[1])
    return x, y


def continent_transform(ui_id):
    """(continent UiMap, ax, bx, ay, by) so that cont_x = ax*x+bx and cont_y = ay*y+by, or None."""
    a = zone_assign[ui_id]
    cont = CONTINENT_UIMAP.get(a["MapID"])
    if not cont:
        return None
    ca = next((c for c in assignments if c["UiMapID"] == cont and c["MapID"] == a["MapID"]), None)
    if not ca:
        return None
    p0 = from_world(ca, *to_world(a, 0.0, 0.0))
    p1 = from_world(ca, *to_world(a, 1.0, 1.0))
    return cont, p1[0] - p0[0], p0[0], p1[1] - p0[1], p0[1]


# ---------------------------------------------------------------------------
# Source rows.

class Npc:
    def __init__(self, nid):
        self.id = nid
        self.name = None
        self.faction = None  # "A", "H", "" for both, None unknown
        self.friendly = None
        self.title = ""
        self.services = set()
        self.where = {}  # UiMap id -> [(x, y)] from the best source that has the NPC
        self.source = None


def parse_ui_spawns(text):
    out = {}
    for chunk in text.split(";"):
        if ":" not in chunk:
            continue
        ui, nums = chunk.split(":", 1)
        nums = [n for n in nums.split(",") if n != ""]
        pts = [(int(nums[i]) / 1000.0, int(nums[i + 1]) / 1000.0) for i in range(0, len(nums) - 1, 2)]
        if pts:
            out.setdefault(ui, []).extend(pts)
    return out


def parse_area_spawns(text):
    out = {}
    for ui_area, pts in parse_ui_spawns(text).items():
        ui = map_for_area(ui_area)
        if ui and ui in zone_assign:
            out.setdefault(ui, []).extend(pts)
    return out


def faction_letter(value):
    value = (value or "").strip()
    if value in ("A", "H"):
        return value
    return ""


units, objects = {}, {}


def unit(nid):
    return units.setdefault(nid, Npc(nid))


names_text = read("Names_enUS.lua")
unit_names = dict(l.split("\t", 1) for l in section(names_text, "units").splitlines() if "\t" in l)
object_names = dict(l.split("\t", 1) for l in section(names_text, "objects").splitlines() if "\t" in l)

data_text = read("Data.lua")
for line in section(data_text, "units").splitlines():
    f = line.split("\t")
    if len(f) < 5:
        continue
    n = unit(f[0])
    n.name = unit_names.get(f[0])
    n.friendly = f[2] != ""
    n.faction = faction_letter(f[2]) if f[2] in ("A", "H") else ("" if f[2] else None)
    n.where = parse_area_spawns(f[4])
    n.source = "pfQuest"
    n.rank = f[3]
for line in section(data_text, "objects").splitlines():
    f = line.split("\t")
    if len(f) >= 3:
        o = objects.setdefault(f[0], Npc(f[0]))
        o.name = object_names.get(f[0])
        o.where = parse_area_spawns(f[2])
        o.source = "pfQuest"

service_lists = {}
for line in section(data_text, "services").splitlines():
    key, _, rest = line.partition("\t")
    entries = []
    for token in rest.split(","):
        if ":" in token:
            ident, fac = token.split(":", 1)
            entries.append((ident, fac))
    service_lists[key] = entries

for key, entries in service_lists.items():
    if key not in SERVICE_CATEGORY:
        continue
    for ident, fac in entries:
        pool = objects if ident.startswith("-") else units
        nid = ident.lstrip("-")
        npc = pool.setdefault(nid, Npc(nid))
        npc.services.add(key)
        if npc.faction is None or ident.startswith("-"):
            npc.faction = "" if fac == "AH" else faction_letter(fac)


def overlay(filename, source, trusted_services):
    """Curated.lua and Forever.lua: positions by UiMap id; they win over pfQuest."""
    text = read(filename)
    for line in text.splitlines():
        f = line.split("\t")
        if f[0] not in ("N", "O") or len(f) < 4:
            continue
        pool = units if f[0] == "N" else objects
        if f[0] == "N":
            if len(f) < 7:
                continue
            nid, name, service, spawns = f[1], f[2], f[5], f[6]
            fac = f[7] if len(f) > 7 else ""
            title = f[8] if len(f) > 8 else ""
            hostile = f[3] == "1"
        else:
            nid, name, spawns = f[1], f[2], f[3]
            service, fac, title, hostile = "", "", "", False
        if f[0] == "O" and nid not in objects:
            continue
        where = {k: v for k, v in parse_ui_spawns(spawns).items() if k in zone_assign}
        if f[0] == "N" and nid not in units and not where:
            continue
        npc = pool.setdefault(nid, Npc(nid))
        if name:
            npc.name = npc.name or name
        if where:
            if npc.source == "pfQuest":
                npc.pf_where = npc.where  # kept to learn how the old map differs from the current one
            npc.where = where
            npc.source = source
        if f[0] == "N":
            if not hostile:
                npc.friendly = True
                if fac in ("A", "H"):
                    npc.faction = fac
                elif npc.faction is None:
                    npc.faction = ""
            if title:
                npc.title = title
            if trusted_services:
                for s in service.split(","):
                    s = s.strip()
                    if s == "trainer":
                        npc.services.add("trainer")
                    elif s in SERVICE_CATEGORY:
                        npc.services.add(s)
            elif service == "flight":
                npc.services.add("flight")


overlay("Curated.lua", "ATT", False)
overlay("Forever.lua", "Forever", True)


# ---------------------------------------------------------------------------
# Some zone maps of Forever are drawn to a different extent than the 2006 ones (Stormwind,
# Mulgore, Eastern Plaguelands, Redridge): old positions there sit far from the NPC.
# NPCs that both old and current data place give the shift: a straight-line fit per axis.

def fit_axis(pairs, axis):
    """Least squares new = a * old + b, dropping the worst fifth twice; returns (a, b, median error)."""
    pts = [(o[axis], n[axis]) for o, n in pairs]
    for _ in range(3):
        mx = sum(p[0] for p in pts) / len(pts)
        my = sum(p[1] for p in pts) / len(pts)
        var = sum((p[0] - mx) ** 2 for p in pts)
        if var < 1e-9:
            return None
        a = sum((p[0] - mx) * (p[1] - my) for p in pts) / var
        b = my - a * mx
        errs = sorted(abs(p[1] - (a * p[0] + b)) for p in pts)
        cut = errs[int(len(errs) * 0.8)]
        pts = [p for p in pts if abs(p[1] - (a * p[0] + b)) <= cut]
    return a, b, errs[len(errs) // 2]


def learn_map_fixes():
    pairs = {}
    for npc in units.values():
        old = getattr(npc, "pf_where", None)
        if not old:
            continue
        for ui, pts in old.items():
            new = npc.where.get(ui)
            if new and len(pts) <= 2 and len(new) <= 2:
                pairs.setdefault(ui, []).append((pts[0], new[0]))
    fixes = {}
    for ui, plist in pairs.items():
        if len(plist) < 12:
            continue
        off = sorted(math.hypot(o[0] - n[0], o[1] - n[1]) for o, n in plist)
        if off[len(off) // 2] < 0.02:
            continue  # the map agrees: nothing to fix
        fx, fy = fit_axis(plist, 0), fit_axis(plist, 1)
        if fx and fy and fx[2] < 0.01 and fy[2] < 0.01:
            fixes[ui] = (fx[0], fx[1], fy[0], fy[1])
    return fixes


MAP_FIXES = learn_map_fixes()


def fixed(ui, points):
    if ui not in MAP_FIXES:
        return points
    ax, bx, ay, by = MAP_FIXES[ui]
    return [(ax * x + bx, ay * y + by) for x, y in points]


for pool in (units, objects):
    for npc in pool.values():
        if npc.source == "pfQuest":
            npc.where = {ui: fixed(ui, pts) for ui, pts in npc.where.items()}

# ---------------------------------------------------------------------------
# Choosing one position for a service NPC.

def spread(points):
    best = 0.0
    for i, a in enumerate(points):
        for b in points[i + 1:]:
            best = max(best, math.hypot(a[0] - b[0], a[1] - b[1]))
    return best


def one_position(npc):
    """(ui map, x, y) or None for patrols, mobs and anything that has no usable zone."""
    if not npc.where:
        return None
    where = npc.where
    # An NPC of one side is not in the other side's own zone (a Horde vendor listed in Darkshore
    # is a data slip; his other spawn is the real one).
    other = {"A": "H", "H": "A"}.get(npc.faction or "")
    if other:
        where = {ui: v for ui, v in where.items() if zone_side(ui) != other}
        if not where:
            return None
    # The old data files a city NPC under the city and again under the zone around it
    # ("14:420,99;1637:357,869"): the city's own map is the one a player looks at.
    cities = [ui for ui in where if ui in CITY_MAPS]
    if cities:
        where = {cities[0]: where[cities[0]]}
    if len(where) > 1:
        # In several zones: only fine when it is a couple of fixed posts; take the first.
        total = sum(len(v) for v in where.values())
        if total > 2:
            return None
    ui = next(iter(where))
    pts = where[ui]
    if len(pts) > MAX_SPREAD_POINTS and spread(pts) > 0.06:
        return None
    if len(pts) > 1 and spread(pts) > 0.3:
        return None
    x, y = pts[0]
    if not (0 <= x <= 1 and 0 <= y <= 1):
        return None
    return ui, x, y


# ---------------------------------------------------------------------------
# Places: (category, faction, map, x, y, name, extra)

places = []
seen_keys = set()


def add(cat, faction, ui, x, y, name, extra=""):
    if not name or "|" in name or "\n" in name:
        return
    key = (cat, ui, round(x / SAME_SPOT), round(y / SAME_SPOT), name if cat != "mailbox" else "")
    if key in seen_keys:
        return
    seen_keys.add(key)
    places.append([cat, faction, ui, x, y, name, extra])


# ---------------------------------------------------------------------------
# Class and profession trainers come from Warcraft Tavern's WoW Forever guides
# (tools/forever_guides.tsv): the lists of this game, not the 2006 one, with the new
# race and class combinations (Undead paladins, Dwarf shamans) and the Skyborne isle.
# The old method (a wiki category matched by name) gave wrong classes and missed the new ones.

GUIDE_ZONE = {"Stormwind": "Stormwind City", "Redridge": "Redridge Mountains", "Valey of Honor": "Valley of Honor"}
GUIDE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "forever_guides.tsv")


# Rows of the guide that the game's own data contradicts: Thotar teaches in Razor Hill only
# (the guide lists him again in Bloodhoof Village, where Yaw Sharpmane is the hunter trainer).
GUIDE_DROP = {("Thotar", "Mulgore")}


def zone_map_by_name(name):
    name = GUIDE_ZONE.get(name, name)
    for ui_id, row in uimap.items():
        if ui_id in zone_assign and row["Name_lang"] == name:
            return ui_id
    return None


guide_classes, guide_profs = {}, {}  # (map, name, x, y) -> {"factions": set, ...}
skipped_guide = {}
for line in open(GUIDE_FILE, encoding="utf-8"):
    if line.startswith("#") or not line.strip():
        continue
    kind, what, fac, name, zone, coords, place, extra = (line.rstrip("\n").split("\t") + [""] * 8)[:8]
    if kind not in ("class", "prof"):
        continue  # pet, demon and portal trainers are not the class trainer a new player needs
    if (name, zone) in GUIDE_DROP:
        continue
    ui = zone_map_by_name(zone)
    if not ui:
        skipped_guide[zone] = skipped_guide.get(zone, 0) + 1
        continue
    x, y = [float(v) / 100.0 for v in coords.split(",")]
    pool = guide_classes if kind == "class" else guide_profs
    rec = pool.setdefault((ui, name, round(x, 3), round(y, 3)), {"sides": set(), "what": []})
    rec["sides"].add({"Alliance": "A", "Horde": "H"}.get(fac, ""))
    if what not in rec["what"]:
        rec["what"].append(what)


def guide_side(sides):
    # Listed for both factions (or neutral) means both may use the NPC.
    return next(iter(sides)) if len(sides) == 1 else ""


for (ui, name, x, y), rec in guide_classes.items():
    side = guide_side(rec["sides"])
    for cls in rec["what"]:
        add("trainer", side, ui, x, y, name, cls.upper())
for (ui, name, x, y), rec in guide_profs.items():
    add("professions", guide_side(rec["sides"]), ui, x, y, name, ",".join(rec["what"][:3]))

# Hand-checked places in the new zones (two sources agree). Zephras Isle: the innkeeper
# Coriella Calmbreeze (Forever players, and Warcraft Tavern's walkthrough at 43.1, 43.3).
# Riverglades: the Horde flight point at Rog'mar is a node of the game's own TaxiNodes table
# (id 3203, Horde); the Alliance one at Farholde Keep comes from the data files.
HAND = [
    ("inn", "", "2521", 0.431, 0.433, "Coriella Calmbreeze", ""),
    ("flight", "H", "2548", 0.596, 0.451, "Rog'mar flight master", ""),
]
for cat, fac, ui, x, y, name, extra in HAND:
    add(cat, fac, ui, x, y, name, extra)

# Vendors without a title: a kind from the wiki's vendor category lists, matched by name.
VENDOR_KINDS = [("General goods", "General Goods"), ("Food and drink", "Food & Drink"), ("Drink", "Food & Drink"),
                ("Reagents", "Reagents"), ("Ammo", "Ammunition"), ("Trade supplies", "Trade Supplies"),
                ("Weapons", "Weapons"), ("Armor", "Armor")]
vendor_kind_of = {}
try:
    vend = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "vendcats.json")))
except OSError:
    vend = {}
for cat, label in VENDOR_KINDS:
    for n in vend.get(cat, []):
        kinds = vendor_kind_of.setdefault(n, [])
        if label not in kinds:
            kinds.append(label)
# These are listed under another service, or are not shops a beginner uses.
MOUNT_VENDORS = {"Ogunaro Wolfrunner", "Zjolnir", "Harb Clawhoof", "Zachariah Post", "Katie Hunter", "Veron Amberstill",
                 "Milli Featherwhistle", "Lelanai", "Genn Fairweather", "Unger Statforth"}  # Known.lua lists these
NOT_SHOPS = ("innkeeper", "stable master", "banker", "auctioneer", "battlemaster", "spirit healer") + FLIGHT_TITLES
EVENT_WORDS = ("smokywood", "darkcaller", "winter veil", "hallow", "brewfest", "lunar festival", "midsummer",
               "noblegarden", "harvest festival", "love is in the air", "pilgrim", "children's week", "fireworks")
# Neutral towns serve both sides, whatever the old data says about each NPC.
NEUTRAL_TOWNS = [("1413", 0.626, 0.368, 0.05), ("1434", 0.283, 0.775, 0.05), ("1446", 0.515, 0.275, 0.05),
                 ("1452", 0.614, 0.364, 0.04), ("2548", 0.780, 0.525, 0.06)]


def neutral_town(ui, x, y):
    return any(ui == m and math.hypot(x - cx, y - cy) <= r for m, cx, cy, r in NEUTRAL_TOWNS)


instance_only = 0
for nid, npc in units.items():
    if not npc.name or npc.friendly is False or (npc.friendly is None and not npc.services and not npc.title):
        continue
    fac = npc.faction if npc.faction is not None else ""
    title = (npc.title or "").lower()
    low = npc.name.lower()
    wanted = {SERVICE_CATEGORY[s] for s in npc.services if s in SERVICE_CATEGORY}
    for words, cat in ((("innkeeper",), "inn"), (("banker",), "bank"), (("stable master",), "stable"),
                       (("auctioneer",), "auction"), (FLIGHT_TITLES, "flight")):
        if title in words:
            wanted.add(cat)
    if "vendor" in wanted:
        # Trainers and mount breeders (Known.lua has those) are not general shops.
        if "trainer" in title or re.search(r"breeder|handler|riding|mount", title) or npc.name in MOUNT_VENDORS:
            wanted.discard("vendor")
        elif (title in NOT_SHOPS or "quartermaster" in low or "quartermaster" in title or "battlemaster" in low
                or any(w in title or w in low for w in EVENT_WORDS)):
            wanted.discard("vendor")
    if not wanted:
        continue
    pos = one_position(npc)
    if not pos:
        if not npc.where:
            instance_only += 1
        continue
    ui, x, y = pos
    if neutral_town(ui, x, y) and "flight" not in wanted:
        fac = ""
    for cat in sorted(wanted):
        if cat == "vendor":
            kind = npc.title if npc.title and "trainer" not in title else ""
            if not kind:
                kind = ", ".join(vendor_kind_of.get(npc.name, [])[:2])
            add(cat, fac, ui, x, y, npc.name, kind)
        elif cat == "flight":
            kind = npc.title if npc.title and "trainer" not in title else ""
            add(cat, fac, ui, x, y, npc.name, kind)
        else:
            add(cat, fac, ui, x, y, npc.name, "")

for oid, obj in objects.items():
    if "mailbox" not in obj.services:
        continue
    # A mailbox object has one row per box: every spawn point is a box, not a patrol.
    cities = [ui for ui in obj.where if ui in CITY_MAPS]
    for ui, pts in obj.where.items():
        for x, y in pts:
            if not (0 <= x <= 1 and 0 <= y <= 1):
                continue
            # A city's box is listed again under the zone around the city: keep the city's.
            inside = False
            if ui not in CITY_MAPS:
                wx, wy = to_world(zone_assign[ui], x, y)
                for city in cities:
                    cx, cy = from_world(zone_assign[city], wx, wy)
                    inside = inside or (0 <= cx <= 1 and 0 <= cy <= 1)
            if not inside:
                add("mailbox", obj.faction or "", ui, x, y, "Mailbox", "")

# ---------------------------------------------------------------------------
# A flight master serves the side of the flight point he stands at: the game's own TaxiNodes
# table says which (flags 1025 Alliance, 1026 Horde, 1024/1027 both).

taxi = [(r["ContinentID"], float(r["Pos_0"]), float(r["Pos_1"]), r["Flags"]) for r in read_csv("TaxiNodes")
        if r["Flags"] in ("1024", "1025", "1026", "1027") and not r["Name_lang"].startswith(("zz", "Transport", "Generic"))]
flight_fixed = 0
for place in places:
    if place[0] != "flight" or place[2] not in zone_assign:
        continue
    cont = zone_assign[place[2]]["MapID"]
    wx, wy = to_world(zone_assign[place[2]], place[3], place[4])
    # 1024 is often a second, side-less record at the same spot (a boat or a hidden node): ignore it.
    near = sorted((math.hypot(wx - tx, wy - ty), f) for c, tx, ty, f in taxi if c == cont and f != "1024")
    if near and near[0][0] < 250:
        side = {"1025": "A", "1026": "H"}.get(near[0][1], "")
        if side != place[1]:
            flight_fixed += 1
            place[1] = side

# ---------------------------------------------------------------------------
# Write.

def fmt(v):
    return str(int(round(v * 1000)))


places.sort(key=lambda p: (CODE[p[0]], p[2], p[3], p[4], p[5]))
used_maps = sorted({p[2] for p in places}, key=int)
zone_lines = []
for ui in used_maps:
    tr = continent_transform(ui)
    name = uimap[ui]["Name_lang"]
    if tr:
        zone_lines.append("%s|%s|%.5f|%.5f|%.5f|%.5f|%s" % (ui, tr[0], tr[1], tr[2], tr[3], tr[4], name))
    else:
        zone_lines.append("%s||0|0|0|0|%s" % (ui, name))

place_lines = []
counts = {}
for cat, fac, ui, x, y, name, extra in places:
    counts[cat] = counts.get(cat, 0) + 1
    place_lines.append("|".join([CODE[cat], fac, ui, fmt(x), fmt(y), name, extra]))

out = []
out.append("local _, T = ...\n")
out.append("-- Built-in places for Find it. Generated by tools/gen_seed.py: do not edit by hand.\n")
out.append("-- Positions come from Forever (seen by players), All The Things and pfQuest (2006-era);\n")
out.append("-- see THIRD-PARTY-LICENSES.txt. Parsed on first use by Services/Places.lua.\n")
out.append("-- zones: map|continent map|ax|bx|ay|by|name, continent position = a * map position + b.\n")
out.append("-- places: category|faction|map|x|y|name|extra, x and y in thousandths.\n")
out.append("-- category: t trainer v vendor r repair i inn f flight m mailbox b bank p professions\n")
out.append("--   a auction w weapons s stable. extra: class file (t), professions (p), kind or title (v, f).\n")
out.append("T.Seed = {\n\tzones = [==[\n" + "\n".join(zone_lines) + "\n]==],\n")
out.append("\tplaces = [==[\n" + "\n".join(place_lines) + "\n]==],\n}\n")
text = "".join(out)
with open(OUT, "w", encoding="utf-8") as f:
    f.write(text)
labelled = sum(1 for p in places if p[0] == "vendor" and p[6])
print("wrote", OUT, len(text), "bytes", len(places), "places", counts)
print("flight masters whose side was corrected from the taxi table:", flight_fixed)
print("old maps corrected:", {uimap[k]["Name_lang"]: [round(v, 3) for v in f] for k, f in MAP_FIXES.items()})
print("vendors with a kind: %d of %d; guide rows on unknown zones: %s; service NPCs with only instance spawns: %d"
      % (labelled, counts.get("vendor", 0), skipped_guide, instance_only))
