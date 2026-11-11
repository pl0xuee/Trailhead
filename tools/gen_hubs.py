#!/usr/bin/env python3
"""Writes Trailhead/Data/Hubs.lua: the quest hubs of every zone, for each faction.

    python3 -I tools/gen_hubs.py <waypoint_data_dir> <db2_csv_dir> [--report]

<waypoint_data_dir> is the WaypointTracker_Data folder (MIT-licensed data bundling pfQuest and
All The Things: Data.lua, Names_enUS.lua, Curated.lua, Forever.lua). <db2_csv_dir> holds the
game's own tables for this build (AreaTable, UiMap, UiMapAssignment, UiMapXMapArt,
WorldMapOverlay, AreaPOI, TaxiNodes).

Method
  1. Every quest has start NPCs and start objects. Each giver gets a place on a zone map
     (positions players saw in Forever win, then All The Things, then pfQuest). A giver with
     many scattered spawns is skipped; a giver whose spawns sit together is placed at their middle.
  2. A quest belongs to the Alliance or the Horde by its race mask (77 and 178), else by
     whom the giver is friendly to, else to both.
  3. Within a zone, givers are merged into hubs: closest pair first, while the centres are
     within a few percent of the map. A hub needs a few quests.
  4. A hub is named from the nearest of: a town on the game's own point-of-interest list, a
     flight point, a sub-area from the world map overlay (the smallest one holding the hub).
  5. Per faction a hub keeps the number of quests, the lowest and the typical quest level, and
     whether an inn and a flight master stand there. The start hub of a zone, for each
     faction, is the usable hub with the lowest typical level that has enough quests.
  6. Noise is cut: old map extents are corrected (Stormwind, Mulgore, Eastern Plaguelands, Redridge),
     quests far outside a zone's level band (level 60 Argent Dawn or raid quests in low zones) are
     dropped, one-giver hubs and lone hubs of a side in the other side's zone go, and a side's
     start hub prefers its own town. Zephras Isle's hubs are hand-checked (HAND_HUBS); Riverglades
     has none because no quest data for it exists in the sources.
This is 2006-era quest data: quests added by Forever are not in it.
"""
import csv
import math
import re
import statistics
import sys
from collections import defaultdict
from pathlib import Path

csv.field_size_limit(10**9)

LINK = 0.06  # merge hubs whose centres are closer than this share of the map
MIN_QUESTS = 4  # fewer quests than this is not a hub
START_QUESTS = 8  # a start hub needs at least this many quests (fewer is a camp, not a place to level at)  # a start hub needs at least this many quests
VALLEY_MIDDLE = 0.10  # the hub is this close to the middle of its area (map widths, squared up)
START_LEVEL = 5  # a hub whose quests are this low is a starting area, named after the valley or camp
SAME_SPOT = 250  # yards: two map listings this close are one place
ABSORB = 0.075  # a small hub this close to a big one is part of it
SMALL, BIG = 8, 12
SPREAD = 0.06  # a giver whose spawns are further apart than this is skipped
MAX_SPAWNS = 6  # a giver with more spawns than this in one zone is skipped
NEAR = 0.035  # an inn or flight master this close belongs to the hub
ASPECT = 1.5  # zone maps are 3 wide to 2 tall; distances are measured on a square
ALLIANCE, HORDE = 2, 1  # the numbers Game.Faction uses
ALLY_MASK, HORDE_MASK = 77, 178
ART_W, ART_H = 1002, 668  # the map art the overlay rectangles are measured on


MIN_GIVERS = 2  # one quest giver alone is not a hub, however many quests he hands out
TRIM_ABOVE = 25  # a quest this far above the zone's lowest real hub is another bracket's (Argent Dawn, raids)
TRIM_AROUND = 20  # a quest this far from its own hub's middle level is a stray
LATE, LOW_ZONE = 55, 40  # a hub this high in a zone whose lowest hub is this low is endgame noise
UNNAMED_MIN = 10  # a hub that only the zone's name fits needs this many quests
STRAY_SIDE = 15  # the other side's town this big makes a few lone quests of this side stray

JUNK_NAMES = {"Generic"}  # placeholder areas in the game's tables


# Cities and battlegrounds: their quest givers are not a place to level at.
CITY_NAMES = {"Thunder Bluff", "Ironforge", "Undercity", "Orgrimmar", "Stormwind City", "Darnassus"}
NOT_HUBS = {1453, 1454, 1455, 1456, 1457, 1458}
NOT_HUB_NAMES = {"Alterac Valley", "Warsong Gulch", "Arathi Basin"}


def read_csv(folder, name):
    with open(Path(folder) / f"{name}.csv", newline="", encoding="utf-8", errors="replace") as f:
        return list(csv.DictReader(f))


def section(text, name):
    m = re.search(r"\b" + name + r" = \[==\[\n(.*?)\n\s*\]==\]", text, re.S)
    return m.group(1) if m else ""


def parse_spawns(text):
    """'12:505,376,510,376;14:...' -> {area: [(x, y)]} as fractions."""
    out = defaultdict(list)
    for part in filter(None, text.split(";")):
        zone, _, coords = part.partition(":")
        nums = [int(n) for n in coords.split(",") if n]
        for i in range(0, len(nums) - 1, 2):
            out[int(zone)].append((nums[i] / 1000, nums[i + 1] / 1000))
    return out


def faction_letters(text):
    mine = set()
    if "A" in text:
        mine.add(ALLIANCE)
    if "H" in text:
        mine.add(HORDE)
    return mine


class World:
    def __init__(self, data_dir, db_dir):
        data_dir = Path(data_dir)
        data = (data_dir / "Data.lua").read_text(encoding="utf-8", errors="replace")
        names = (data_dir / "Names_enUS.lua").read_text(encoding="utf-8", errors="replace")
        self.units = {}
        for line in section(data, "units").split("\n"):
            f = line.split("\t")
            if len(f) >= 5:
                self.units[int(f[0])] = (f[2], f[4])
        self.objects = {}
        for line in section(data, "objects").split("\n"):
            f = line.split("\t")
            if len(f) >= 3:
                self.objects[int(f[0])] = (f[1], f[2])
        self.quests = []
        for line in section(data, "quests").split("\n"):
            f = line.split("\t")
            if len(f) >= 7 and f[0].isdigit():
                self.quests.append({
                    "id": int(f[0]), "level": int(f[1] or 0), "min": int(f[2] or 0), "races": int(f[3] or 0),
                    "npcs": [int(n) for n in f[5].split(",") if n],
                    "objs": [int(n) for n in f[6].split(",") if n],
                })
        # Quests players found in Forever (the shared list): level and start only, so they are added
        # when the 2006 data does not know the quest. Race is unknown: the giver's side decides.
        known = {q["id"] for q in self.quests}
        for line in (data_dir / "Forever.lua").read_text(encoding="utf-8", errors="replace").split("\n"):
            f = line.split("\t")
            if len(f) >= 5 and f[0] == "Q" and f[1].isdigit() and int(f[1]) not in known and f[3].isdigit() and f[4]:
                starts = [x for x in f[4].split(",") if x[:1] in ("U", "O") and x[1:].isdigit()]
                self.quests.append({
                    "id": int(f[1]), "level": int(f[3]), "min": 0, "races": 0,
                    "npcs": [int(x[1:]) for x in starts if x[0] == "U"],
                    "objs": [int(x[1:]) for x in starts if x[0] == "O"],
                })
        self.unit_names = {}
        for line in section(names, "units").split("\n"):
            f = line.split("\t")
            if len(f) >= 2 and f[0].isdigit():
                self.unit_names[int(f[0])] = f[1]
        self.services = {}
        for line in section(data, "services").split("\n"):
            kind, _, rest = line.partition("\t")
            self.services[kind] = {}
            for item in filter(None, rest.split(",")):
                key, _, fac = item.partition(":")
                self.services[kind][int(key)] = faction_letters(fac)
        # Positions on UiMap ids, from the trusted sources.
        self.fixed = {}  # ("N", id) -> {uimap: [(x,y)]}
        self.fixed_side = {}  # ("N", id) -> {1, 2}
        for fname in ("Curated.lua", "Forever.lua"):  # later (Forever) wins
            for line in (data_dir / fname).read_text(encoding="utf-8", errors="replace").split("\n"):
                f = line.split("\t")
                if len(f) >= 8 and f[0] in ("N", "O") and f[1].isdigit() and faction_letters(f[7]):
                    self.fixed_side[(f[0], int(f[1]))] = faction_letters(f[7])
                if len(f) >= 7 and f[0] in ("N", "O") and f[1].isdigit() and f[6] and ":" in f[6]:
                    spots = parse_spawns(f[6])
                    if spots:
                        self.fixed[(f[0], int(f[1]))] = spots
        # Areas and maps.
        uimap = {r["ID"]: r for r in read_csv(db_dir, "UiMap")}
        self.map_name = {int(k): v["Name_lang"] for k, v in uimap.items()}
        self.area_map = {}
        self.assign = defaultdict(list)
        for a in read_csv(db_dir, "UiMapAssignment"):
            m = uimap.get(a["UiMapID"])
            if not m or m["Type"] != "3":
                continue
            area = int(a["AreaID"] or 0)
            if area and (area not in self.area_map or int(a["OrderIndex"] or 0) == 0):
                self.area_map[area] = int(a["UiMapID"])
            self.assign[int(a["UiMapID"])].append(a)
        table = read_csv(db_dir, "AreaTable")
        self.areas = {int(r["ID"]): r["AreaName_lang"] for r in table}
        self.parent = {int(r["ID"]): int(r["ParentAreaID"] or 0) for r in table}
        self.db_dir = db_dir
        self.map_fixes = self.learn_map_fixes()

    def old_places(self, kind, ident):
        raw = (self.units if kind == "N" else self.objects).get(ident)
        old = {}
        if raw:
            for area, pts in parse_spawns(raw[1]).items():
                if area in self.area_map:
                    old.setdefault(self.area_map[area], []).extend(pts)
        return old

    def learn_map_fixes(self):
        """Some zone maps of Forever (Stormwind, Mulgore, Eastern Plaguelands, Redridge) are drawn to a
        different extent than in 2006, so old positions there sit far from the place. Givers that both
        old and current data place show the shift: a straight-line fit per axis, as tools/gen_seed.py does."""
        pairs = defaultdict(list)
        for (kind, ident), new in self.fixed.items():
            for m, pts in self.old_places(kind, ident).items():
                if m in new and len(pts) <= 2 and len(new[m]) <= 2:
                    pairs[m].append((pts[0], new[m][0]))
        fixes = {}
        for m, plist in pairs.items():
            if len(plist) < 12:
                continue
            off = sorted(math.hypot(o[0] - n[0], o[1] - n[1]) for o, n in plist)
            if off[len(off) // 2] < 0.02:
                continue  # the map agrees: nothing to fix
            fx, fy = fit_axis(plist, 0), fit_axis(plist, 1)
            if fx and fy and fx[2] < 0.01 and fy[2] < 0.01:
                fixes[m] = (fx[0], fx[1], fy[0], fy[1])
        return fixes

    def to_ui(self, map_id, continent, wx, wy):
        best = None
        for a in self.assign.get(map_id, []):
            if a["MapID"] != str(continent):
                continue
            r = [float(a[f"Region_{i}"]) for i in range(6)]
            if not (r[0] <= wx <= r[3] and r[1] <= wy <= r[4]):
                continue
            u = [float(a["UiMin_0"]), float(a["UiMin_1"]), float(a["UiMax_0"]), float(a["UiMax_1"])]
            best = (u[0] + (r[4] - wy) / (r[4] - r[1]) * (u[2] - u[0]),
                    u[1] + (r[3] - wx) / (r[3] - r[0]) * (u[3] - u[1]))
        return best

    def town_area(self, area):
        """Climbs from a small sub-area to the one just under the zone ("The Den" -> "Valley of Trials")."""
        for _ in range(6):
            up = self.parent.get(area, 0)
            if up and self.parent.get(up, 0):
                area = up
            else:
                break
        return area

    def to_world(self, map_id, x, y):
        """A spot on a zone map as (continent, world x, world y); the reverse of to_ui."""
        for a in self.assign.get(map_id, []):
            r = [float(a[f"Region_{i}"]) for i in range(6)]
            u = [float(a["UiMin_0"]), float(a["UiMin_1"]), float(a["UiMax_0"]), float(a["UiMax_1"])]
            if u[2] > u[0] and u[3] > u[1]:
                return (a["MapID"], r[3] - (y - u[1]) / (u[3] - u[1]) * (r[3] - r[0]),
                        r[4] - (x - u[0]) / (u[2] - u[0]) * (r[4] - r[1]))
        return None

    def places(self, kind, ident):
        """Where a giver stands: {uimap: [(x, y)]}.

        Zone rectangles overlap, so one spot can be listed on two maps (the Barrens and Dustwallow
        Marsh both hold Brackenwall Village). Listings that are the same spot in the world are one
        place, kept on the map whose overlay areas hold it. A giver listed at different spots in
        the world travels (Darkmoon Faire) and is left out. Positions players saw win over old data."""
        old = {}
        for m, pts in self.old_places(kind, ident).items():
            if m in self.map_fixes:
                ax, bx, ay, by = self.map_fixes[m]
                pts = [(ax * x + bx, ay * y + by) for x, y in pts]
            old[m] = pts
        seen = self.fixed.get((kind, ident))
        found = seen if seen else old
        if len(found) <= 1:
            return found
        spots = []
        for m, pts in found.items():
            cx, cy = sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)
            spots.append((m, cx, cy, self.to_world(m, cx, cy)))
        first = spots[0][3]
        for m, cx, cy, wp in spots:
            if not wp or not first or wp[0] != first[0] or math.hypot(wp[1] - first[1], wp[2] - first[2]) > SAME_SPOT:
                return {}
        def rank(spot):
            m, cx, cy, _ = spot
            edge = min(cx, 1 - cx, cy, 1 - cy)
            return (self.namer.inside(m, cx, cy), edge)
        return {max(spots, key=rank)[0]: found[max(spots, key=rank)[0]]}

    def friendly(self, kind, ident):
        raw = (self.units if kind == "N" else self.objects).get(ident)
        side = faction_letters(raw[0]) if raw else set()
        return side or self.fixed_side.get((kind, ident)) or {ALLIANCE, HORDE}


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


def centre(points):
    """The middle of a giver's spawns in one zone, or None when they are too many or too spread."""
    if len(points) > MAX_SPAWNS:
        return None
    xs, ys = [p[0] for p in points], [p[1] for p in points]
    if max(xs) - min(xs) > SPREAD or (max(ys) - min(ys)) * ASPECT > SPREAD * ASPECT:
        return None
    return sum(xs) / len(xs), sum(ys) / len(ys)


def quest_factions(quest, giver_friendly):
    """Who the quest is for: by race mask first, else by who the giver is friendly to."""
    races = quest["races"]
    if races not in (0, 255) and (races & ALLY_MASK or races & HORDE_MASK):
        out = set()
        if races & ALLY_MASK:
            out.add(ALLIANCE)
        if races & HORDE_MASK:
            out.add(HORDE)
        return out
    return set(giver_friendly) if giver_friendly else {ALLIANCE, HORDE}


def dist(a, b):
    return math.hypot((a[0] - b[0]) * ASPECT, a[1] - b[1])


def cluster(givers):
    """givers: [{pos, quests: [(level, factions)], ...}] -> merged groups, closest pair first."""
    groups = [{"members": [g], "pos": g["pos"], "weight": len(g["quests"])} for g in givers]
    while len(groups) > 1:
        best = None
        for i in range(len(groups)):
            for j in range(i + 1, len(groups)):
                d = dist(groups[i]["pos"], groups[j]["pos"])
                if d < LINK and (best is None or d < best[0]):
                    best = (d, i, j)
        if not best:
            break
        _, i, j = best
        a, b = groups[i], groups[j]
        w = a["weight"] + b["weight"]
        a["pos"] = ((a["pos"][0] * a["weight"] + b["pos"][0] * b["weight"]) / w,
                    (a["pos"][1] * a["weight"] + b["pos"][1] * b["weight"]) / w)
        a["members"] += b["members"]
        a["weight"] = w
        del groups[j]
    return groups


# Hubs the game text and Warcraft Tavern's Zephras Isle walkthrough fix by hand. The old quest data
# calls the cluster at Constable Aonda "Falaath Village" (that is a quest name); Aonda, the inn and the
# trainers all stand in Shen'dar Village. Thendal Village is where every Skyborne starts: ten quest
# givers are named in the walkthrough there (level 1; later levels there are not confirmed).
# Row: name, map, x, y, quests, lowest, typical, flags (1 inn, 2 flight, 4 start for both sides).
# Steamwheedle Port is on Tanaris's east coast (Warcraft Tavern's Riverglades guide), where the
# naming tables only find the nearer Gadgetzan flight point.
# The naming tables pick the nearest named area, which for three camps is a place next door:
# Nethergarde Keep (the Alliance fort in the Blasted Lands, its flight point in TaxiNodes), Ghost
# Walker Post (the Horde camp beside the Kodo Graveyard) and the Emerald Sanctuary (the druid camp at
# the south end of Felwood; Deadwood Village is the hostile furbolg camp beside it). All three names
# are in the game's AreaTable.
HAND_RENAMES = [("Shen'dar Village", 2521, 0.454, 0.455, 0.03), ("Steamwheedle Port", 1446, 0.66, 0.22, 0.03),
                ("Nethergarde Keep", 1419, 0.664, 0.196, 0.03), ("Ghost Walker Post", 1443, 0.524, 0.538, 0.03),
                ("Emerald Sanctuary", 1448, 0.510, 0.825, 0.065)]
# Row: name, map, x, y, quests, lowest, typical, flags, sides. The Bulwark is the Horde's camp at the
# west gate of the Western Plaguelands. The old data files it under Tirisfal Glades (24 Horde quests
# from 7 givers, levels 53 up, typically 56), so it is placed on the Plaguelands map by hand, at the
# spot the two maps share.
HAND_HUBS = [("Thendal Village", 2521, 0.430, 0.240, 10, 1, 1, 4, (ALLIANCE, HORDE)),
             ("The Bulwark", 1422, 0.264, 0.561, 24, 53, 56, 4, (HORDE,))]
# One side's view of a hub that is the other side's guarded camp: its few quests there come from
# neutral givers standing inside it, and sending a new player in would get them killed.
HAND_DROPS = [(1422, "Chillwind Camp", HORDE), (1448, "Bloodvenom Post", ALLIANCE)]
# Zones with no town at all for either side: nothing there is "the place to start".
NO_START = {1416}
SMALL_TOWN = 5  # a hub with an inn or flight master and this many quests can be a start hub
NEUTRAL_HUBS = {"Ratchet", "Gadgetzan", "Booty Bay", "Everlook", "Cenarion Hold", "Light's Hope Chapel"}


def neutral(h):
    return h["name"] in NEUTRAL_HUBS


class Namer:
    """Names a spot on a zone map from the game's own tables."""

    def __init__(self, world, db_dir):
        self.world = world
        self.towns = defaultdict(list)  # uimap -> [(name, x, y)]
        self.flights = defaultdict(list)
        self.overlays = defaultdict(list)  # uimap -> [(name, x0, y0, x1, y1)]
        continents = {}
        for r in read_csv(db_dir, "Map"):
            continents[r["ID"]] = True
        for poi in read_csv(db_dir, "AreaPOI"):
            name = poi["Name_lang"]
            # Only the towns the game draws on the map (flag 1, importance 2 or 3), not every building.
            if not name or poi["ContinentID"] not in ("0", "1") or int(poi["Flags"] or 0) & 1 == 0 \
                    or int(poi["Importance"] or 0) < 2:
                continue
            wx, wy = float(poi["Pos_0"]), float(poi["Pos_1"])
            for m in self.maps_at(poi["ContinentID"], wx, wy):
                p = world.to_ui(m, poi["ContinentID"], wx, wy)
                if p and 0 <= p[0] <= 1 and 0 <= p[1] <= 1:
                    self.towns[m].append((name, p[0], p[1]))
        for node in read_csv(db_dir, "TaxiNodes"):
            if node["ContinentID"] not in ("0", "1"):
                continue
            wx, wy = float(node["Pos_0"]), float(node["Pos_1"])
            name = node["Name_lang"]
            town = name.split(",")[0].strip()
            for m in self.maps_at(node["ContinentID"], wx, wy):
                p = world.to_ui(m, node["ContinentID"], wx, wy)
                if p and 0 <= p[0] <= 1 and 0 <= p[1] <= 1:
                    self.flights[m].append((town, p[0], p[1]))
        art_of = {}
        for r in read_csv(db_dir, "UiMapXMapArt"):
            art_of.setdefault(r["UiMapID"], []).append(r["UiMapArtID"])
        by_art = defaultdict(list)
        for r in read_csv(db_dir, "WorldMapOverlay"):
            by_art[r["UiMapArtID"]].append(r)
        for m in world.assign:
            for art in art_of.get(str(m), []):
                for r in by_art.get(art, []):
                    w, h = float(r["TextureWidth"]), float(r["TextureHeight"])
                    x0, y0 = float(r["OffsetX"]), float(r["OffsetY"])
                    name = world.areas.get(world.town_area(int(r["AreaID_0"] or 0)))
                    if name and name not in JUNK_NAMES and w > 0 and h > 0:
                        self.overlays[m].append((name, x0 / ART_W, y0 / ART_H, (x0 + w) / ART_W, (y0 + h) / ART_H))

    def maps_at(self, continent, wx, wy):
        out = []
        for m, rows in self.world.assign.items():
            for a in rows:
                if a["MapID"] == continent:
                    out.append(m)
                    break
        return out

    def inside(self, m, x, y):
        """True when an overlay area of this map holds the spot."""
        return any(x0 <= x <= x1 and y0 <= y <= y1 for _, x0, y0, x1, y1 in self.overlays.get(m, []))

    def name(self, m, x, y, typical=99):
        if typical <= START_LEVEL:
            # Level 1 quests start in a named valley ("Valley of Trials"); the game's town list names a
            # building there ("The Den"). When the hub sits in the middle of an overlay area, that is
            # the name; else (a camp inside a bigger area, Camp Narache) the town list is right.
            near = None
            for name, x0, y0, x1, y1 in self.overlays.get(m, []):
                if x0 <= x <= x1 and y0 <= y <= y1:
                    d = dist((x, y), ((x0 + x1) / 2, (y0 + y1) / 2))
                    if near is None or d < near[0]:
                        near = (d, name)
            if near and near[0] < VALLEY_MIDDLE:
                return near[1]
        best = None
        for kind, rank, pool, limit in (("poi", 0, self.towns, 0.08), ("flight", 1, self.flights, 0.05)):
            for name, px, py in pool.get(m, []):
                d = dist((x, y), (px, py))
                if d <= limit and (best is None or d + rank * 0.01 < best[0]):
                    best = (d + rank * 0.01, name)
        if best:
            return best[1]
        inside = []
        for name, x0, y0, x1, y1 in self.overlays.get(m, []):
            if x0 <= x <= x1 and y0 <= y <= y1:
                inside.append(((x1 - x0) * (y1 - y0), name))
        if inside:
            return min(inside)[1]
        near = None
        for name, x0, y0, x1, y1 in self.overlays.get(m, []):
            d = dist((x, y), ((x0 + x1) / 2, (y0 + y1) / 2))
            if near is None or d < near[0]:
                near = (d, name)
        return near[1] if near and near[0] < 0.08 else None


def level_of(quest):
    return quest["level"] if quest["level"] > 0 else quest["min"]


def stats(levels):
    levels = sorted(levels)
    low = levels[int(len(levels) * 0.1)]
    return low, int(round(statistics.median(levels)))


def build(data_dir, db_dir):
    world = World(data_dir, db_dir)
    namer = world.namer = Namer(world, db_dir)
    givers = defaultdict(dict)  # uimap -> {(kind, id): giver}
    for quest in world.quests:
        level = level_of(quest)
        if level <= 0:
            continue
        for kind, ids in (("N", quest["npcs"]), ("O", quest["objs"])):
            for ident in ids:
                friendly = world.friendly(kind, ident)
                factions = quest_factions(quest, friendly)
                for m, pts in world.places(kind, ident).items():
                    pos = centre(pts)
                    if not pos:
                        continue
                    g = givers[m].setdefault((kind, ident), {"pos": pos, "quests": [], "kind": kind, "id": ident})
                    g["quests"].append((level, frozenset(factions)))
    inns = defaultdict(list)  # uimap -> [(pos, factions)]
    fms = defaultdict(list)
    for kind, table in (("inn", world.services.get("innkeeper", {})), ("fm", world.services.get("flight", {}))):
        for ident, facs in table.items():
            for m, pts in world.places("O" if ident < 0 else "N", abs(ident)).items():
                pos = centre(pts) if len(pts) > 1 else pts[0]
                if pos:
                    (inns if kind == "inn" else fms)[m].append((pos, facs or {ALLIANCE, HORDE}))

    def summarize(h, m):
        """The per-side view of a hub from its quests: count, lowest and typical level, inn and flight."""
        per = {}
        for fac in (ALLIANCE, HORDE):
            levels = [lv for lv, facs in h["quests"] if fac in facs]
            if len(levels) < MIN_QUESTS:
                continue
            low, typical = stats(levels)
            inn = any(fac in f and dist(h["pos"], p) <= NEAR for p, f in inns[m])
            fm = any(fac in f and dist(h["pos"], p) <= NEAR for p, f in fms[m])
            per[fac] = {"n": len(levels), "lo": low, "typ": typical, "inn": inn, "fm": fm}
        h["per"] = per

    world.dropped = defaultdict(int)
    hubs = []
    for m, group in sorted(givers.items()):
        if m in NOT_HUBS or world.map_name.get(m) in NOT_HUB_NAMES:
            continue
        for cl in cluster(list(group.values())):
            h = {"map": m, "pos": cl["pos"], "name": None, "givers": len(cl["members"]),
                 "quests": [q for g in cl["members"] for q in g["quests"]]}
            # A town (an inn or a flight master stands there) counts even with one quest giver:
            # Aerie Peak is where the Alliance starts in the Hinterlands.
            town = any(dist(h["pos"], p) <= NEAR for p, _ in inns[m] + fms[m])
            if len(h["quests"]) >= MIN_QUESTS and h["givers"] < MIN_GIVERS and not town:
                world.dropped["hubs of one or two givers"] += 1
            if len(h["quests"]) >= MIN_QUESTS and (h["givers"] >= MIN_GIVERS or town):
                summarize(h, m)
                if h["per"]:
                    hubs.append(h)
    # Noise. Quest levels far from the zone's real band belong to other content (level 60 Argent
    # Dawn and raid quests handed out in low zones); strays are cut, and a hub that is left with
    # too few quests goes. Each step is counted for the report.
    floor = {}
    for m in {h["map"] for h in hubs}:
        real = [min(v["typ"] for v in h["per"].values()) for h in hubs
                if h["map"] == m and max(v["n"] for v in h["per"].values()) >= 6]
        floor[m] = min(real) if real else None
    kept = []
    for h in hubs:
        m = h["map"]
        before = len(h["quests"])
        levels = sorted(lv for lv, _ in h["quests"])
        mid = levels[len(levels) // 2]
        top = (floor[m] + TRIM_ABOVE) if floor[m] is not None else 99
        h["quests"] = [q for q in h["quests"] if abs(q[0] - mid) <= TRIM_AROUND and q[0] <= top]
        world.dropped["quests trimmed"] += before - len(h["quests"])
        summarize(h, m)
        if not h["per"]:
            world.dropped["hubs left too thin"] += 1
            continue
        if floor[m] is not None and floor[m] <= LOW_ZONE and min(v["typ"] for v in h["per"].values()) >= LATE:
            world.dropped["endgame hubs in low zones"] += 1
            continue
        h["name"] = namer.name(m, h["pos"][0], h["pos"][1], min(v["typ"] for v in h["per"].values()))
        if h["name"] in NOT_HUB_NAMES or h["name"] in CITY_NAMES:
            continue
        if h["name"] is None or ":" in h["name"] or h["name"].startswith("Quest Path"):
            # Only the zone's own name fits: a lone scatter of givers, not a town.
            if max(v["n"] for v in h["per"].values()) < UNNAMED_MIN or (h["name"] and ":" in h["name"]):
                world.dropped["unnamed hubs"] += 1
                continue
        kept.append(h)
    hubs = kept
    # One side's few quests in the other side's land (a Horde hub in Duskwood) are stray.
    kept = []
    for h in hubs:
        mine = set(h["per"])
        if len(mine) == 1:
            side = next(iter(mine))
            other = HORDE if side == ALLIANCE else ALLIANCE
            own = max([v["n"] for k in hubs if k["map"] == h["map"] for f, v in k["per"].items() if f == side] or [0])
            theirs = max([v["n"] for k in hubs if k["map"] == h["map"] for f, v in k["per"].items()
                          if f == other and len(k["per"]) == 1] or [0])
            town = h["per"][side]["inn"] or h["per"][side]["fm"]  # its own inn or flight master: a real town
            if own < START_QUESTS and theirs >= STRAY_SIDE and not town:
                world.dropped["lone hubs in the other side's zone"] += 1
                continue
        kept.append(h)
    hubs = kept
    # A small cluster next to a big one is the same town spread out.
    hubs.sort(key=lambda h: -max(v["n"] for v in h["per"].values()))
    kept = []
    for h in hubs:
        size = max(v["n"] for v in h["per"].values())
        host = next((k for k in kept if k["map"] == h["map"] and dist(k["pos"], h["pos"]) < ABSORB
                     and max(v["n"] for v in k["per"].values()) >= BIG), None)
        host_n = max(v["n"] for v in host["per"].values()) if host else 0
        if host and (size < SMALL or size < host_n * 0.6):
            for f, v in h["per"].items():
                w = host["per"].get(f)
                if w:
                    w["n"] += v["n"]
                    w["lo"] = min(w["lo"], v["lo"])
                    w["inn"], w["fm"] = w["inn"] or v["inn"], w["fm"] or v["fm"]
            continue
        kept.append(h)
    hubs = kept
    # Hubs the data cannot name get the zone's name (a lone camp in a thin zone).
    for h in hubs:
        if not h["name"]:
            h["name"] = world.map_name.get(h["map"], "?")
    # When two hubs share a name in a zone, keep the bigger and fold the other in by renaming it
    # with the side of the zone it lies on, so a player never sees two with the same name.
    seen = defaultdict(list)
    for h in hubs:
        seen[(h["map"], h["name"])].append(h)
    for (m, name), same in seen.items():
        if len(same) > 1:
            same.sort(key=lambda h: -sum(p["n"] for p in h["per"].values()))
            for h in same[1:]:
                dx, dy = h["pos"][0] - same[0]["pos"][0], h["pos"][1] - same[0]["pos"][1]
                way = ("north" if dy < 0 else "south") if abs(dy) * ASPECT > abs(dx) else ("west" if dx < 0 else "east")
                h["name"] = f"{name} ({way})"
                if sum(1 for o in hubs if o["map"] == m and o["name"] == h["name"]) > 1:
                    h["name"] = f"{name} ({way} {1 + same.index(h)})"
    # Hand-checked hubs of the new zones (Warcraft Tavern's Zephras Isle walkthrough, whose coordinates
    # match the trainer positions players saw; see HAND_HUBS).
    for name, m, x, y, reach in HAND_RENAMES:
        for h in hubs:
            if h["map"] == m and dist(h["pos"], (x, y)) < reach:
                # Keep "(south)" only when the hub was the smaller of two sharing the old name here.
                old = h["name"].split(" (")
                twin = any(o is not h and o["map"] == m and o["name"] == old[0] and dist(o["pos"], (x, y)) < reach
                           for o in hubs) or any(o is not h and o["map"] == m and o["name"] == name for o in hubs)
                h["name"] = name + (" (" + old[1] if len(old) > 1 and twin else "")
    for m, name, fac in HAND_DROPS:
        for h in hubs:
            if h["map"] == m and h["name"] == name and len(h["per"]) > 1:
                h["per"].pop(fac, None)
    for name, m, x, y, n, lo, typ, flags, sides in HAND_HUBS:
        per = {f: {"n": n, "lo": lo, "typ": typ, "inn": bool(flags & 1), "fm": bool(flags & 2)} for f in sides}
        hubs.append({"map": m, "pos": (x, y), "name": name, "per": per, "givers": n, "hand": True,
                     "start": set(sides) if flags & 4 else set()})
    # Start hubs: the place a new character of a side should go to in a zone. A side's own town
    # (one only it uses, or a neutral town such as Ratchet that both use) beats a hub the other side
    # shares at the same level, so each side in a contested zone starts in its own town.
    for m in {h["map"] for h in hubs}:
        for fac in (ALLIANCE, HORDE):
            mine = [h for h in hubs if h["map"] == m and fac in h["per"]]
            if m in NO_START:
                continue
            if any(fac in h.get("start", ()) for h in mine if h.get("hand")):
                continue  # a hand-checked start hub decides
            def big(h):
                v = h["per"][fac]
                return v["n"] >= START_QUESTS or (v["n"] >= SMALL_TOWN and (v["inn"] or v["fm"]))
            usable = [h for h in mine if big(h)]
            if not usable and not any(v["n"] >= START_QUESTS for h in hubs if h["map"] == m for v in h["per"].values()):
                usable = mine  # a small zone (a new island): the best of what is there
            home = [h for h in usable if len(h["per"]) == 1 or neutral(h)]
            if home:
                usable = home
            if usable:
                # The lowest hub wins, but a small camp (under ten quests, no inn, no flight master)
                # gives way to a town within five levels of it (Revantusk Village over a camp in the hills).
                best = min(usable, key=lambda h: (h["per"][fac]["typ"], -h["per"][fac]["n"]))
                v = best["per"][fac]
                if v["n"] < 10 and not (v["inn"] or v["fm"]):
                    towns = [h for h in usable if (h["per"][fac]["inn"] or h["per"][fac]["fm"])
                             and h["per"][fac]["typ"] - v["typ"] <= 5]
                    if towns:
                        best = min(towns, key=lambda h: (h["per"][fac]["typ"], -h["per"][fac]["n"]))
                best.setdefault("start", set()).add(fac)
    return hubs, world


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def rows(hubs):
    """One row per hub and faction view; the two views of a hub are one row when they agree."""
    out = []
    for h in hubs:
        per = h["per"]
        views = {f: (v["n"], v["lo"], v["typ"], v["inn"], v["fm"]) for f, v in per.items()}
        starts = h.get("start", set())
        if len(views) == 2 and views[ALLIANCE] == views[HORDE]:
            v = per[ALLIANCE]
            out.append((h, 0, v, ALLIANCE in starts, HORDE in starts))
        else:
            for f, v in sorted(per.items()):
                out.append((h, f, v, f in starts and f == ALLIANCE, f in starts and f == HORDE))
    return out


def write(hubs, path, map_name):
    by_map = defaultdict(list)
    for r in rows(hubs):
        by_map[r[0]["map"]].append(r)
    lines = [
        "local _, T = ...",
        "",
        "-- Quest hubs: towns and camps where several quest givers stand, per zone map.",
        "-- Written by tools/gen_hubs.py from quest data of the 2006 game (pfQuest, via the MIT-licensed",
        "-- Waypoint Tracker data) with positions from All The Things and from Forever players, and",
        "-- names from the game's own AreaPOI, TaxiNodes and WorldMapOverlay tables. Quests added by",
        "-- Forever are not in it. Zephras Isle is hand-checked against Warcraft Tavern's walkthrough.",
        "-- Do not edit by hand.",
        "-- Row: { name, x, y, faction, lowest level, typical level, quests, flags }",
        "--   x and y are thousandths of the zone map; faction 0 both, 1 Horde, 2 Alliance;",
        "--   flags: 1 inn, 2 flight master, 4 start hub for the Alliance, 8 start hub for the Horde.",
        "",
        "T.HubData = {",
    ]
    total = 0
    for m in sorted(by_map):
        lines.append(f"\t[{m}] = {{ -- {map_name.get(m, '?')}")
        for h, f, v, sa, sh in sorted(by_map[m], key=lambda r: (r[2]["typ"], r[0]["name"])):
            flags = (1 if v["inn"] else 0) + (2 if v["fm"] else 0) + (4 if sa else 0) + (8 if sh else 0)
            lines.append("\t\t{ %s, %d, %d, %d, %d, %d, %d, %d }," % (
                lua_string(h["name"]), round(h["pos"][0] * 1000), round(h["pos"][1] * 1000), f,
                v["lo"], v["typ"], v["n"], flags))
            total += 1
        lines.append("\t},")
    lines.append("}")
    Path(path).write_text("\n".join(lines) + "\n", encoding="utf-8")
    return total


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 2:
        sys.exit(__doc__)
    hubs, world = build(args[0], args[1])
    out = Path(__file__).resolve().parent.parent / "Trailhead" / "Data" / "Hubs.lua"
    count = write(hubs, out, world.map_name)
    print(f"{len(hubs)} hubs, {count} rows, {len({h['map'] for h in hubs})} zones -> {out}")
    for what, n in sorted(world.dropped.items()):
        print(f"  dropped: {what}: {n}")
    for m, fix in sorted(world.map_fixes.items()):
        print(f"  map corrected: {world.map_name.get(m, m)}")
    if "--report" in sys.argv:
        for m in sorted({h["map"] for h in hubs}):
            print(world.map_name.get(m, m))
            for h in sorted((h for h in hubs if h["map"] == m), key=lambda h: min(v["typ"] for v in h["per"].values())):
                bits = []
                for f, v in sorted(h["per"].items()):
                    bits.append("%s n=%d lo=%d typ=%d%s%s%s" % ("H" if f == HORDE else "A", v["n"], v["lo"], v["typ"],
                                " inn" if v["inn"] else "", " fm" if v["fm"] else "",
                                " START" if f in h.get("start", ()) else ""))
                print("   %-28s (%.2f,%.2f) %s" % (h["name"], h["pos"][0], h["pos"][1], " | ".join(bits)))


if __name__ == "__main__":
    main()
