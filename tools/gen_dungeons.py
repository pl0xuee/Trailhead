#!/usr/bin/env python3
"""Writes Trailhead/Data/DungeonIndex.lua from the game's own tables.

    python3 -I tools/gen_dungeons.py <db2_csv_dir>

Reads Map, MapDifficulty, DungeonEncounter, Difficulty, UiMap, UiMapAssignment, AreaPOI
(CSV exports of the game's DB2 tables, build 1.60.1.70888). For every dungeon and raid it
writes the size, the bosses and the door's place on a zone map. Zone rectangles overlap, so
ZONE below says which zone each door is really in; the position is then worked out on that
zone's map. Doors the tables do not have are in OVERRIDES (checked by hand) or left out.
"""
import csv
import pathlib
import sys

csv.field_size_limit(10**9)
ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "Trailhead" / "Data" / "DungeonIndex.lua"

# Instance map id -> the zone (UiMap id) the door is in.
ZONE = {
    33: 1421,    # Shadowfang Keep: Silverpine Forest
    34: 1453,    # The Stockade: Stormwind City
    36: 1436,    # The Deadmines: Westfall
    43: 1413,    # Wailing Caverns: The Barrens
    47: 1413,    # Razorfen Kraul: The Barrens
    48: 1440,    # Blackfathom Deeps: Ashenvale
    70: 1418,    # Uldaman: Badlands
    90: 1426,    # Gnomeregan: Dun Morogh
    109: 1435,   # Sunken Temple: Swamp of Sorrows
    129: 1413,   # Razorfen Downs: The Barrens
    189: 1420,   # Scarlet Monastery: Tirisfal Glades
    209: 1446,   # Zul'Farrak: Tanaris
    229: 1428,   # Blackrock Spire: Blackrock Mountain, on the Burning Steppes side
    230: 1427,   # Blackrock Depths: Blackrock Mountain, on the Searing Gorge side
    249: 1445,   # Onyxia's Lair: Dustwallow Marsh
    289: 1422,   # Scholomance: Western Plaguelands
    309: 1434,   # Zul'Gurub: Stranglethorn Vale
    329: 1423,   # Stratholme: Eastern Plaguelands
    349: 1443,   # Maraudon: Desolace
    389: 1454,   # Ragefire Chasm: Orgrimmar
    409: 1428,   # Molten Core: Blackrock Mountain
    429: 1444,   # Dire Maul: Feralas
    469: 1428,   # Blackwing Lair: Blackrock Mountain
    509: 1451,   # Ruins of Ahn'Qiraj: Silithus
    531: 1451,   # Ahn'Qiraj Temple: Silithus
}

# Doors the tables do not hold: id -> (zone UiMap, x, y), each one checked against two
# sources. Filled in by hand; anything not here and not above has no door.
# Checked by hand against ForeverDungeonRoutes entrances and the Blackrock Depths door (read-only second sources):
# the corpse position in the Map table is off for these three.
OVERRIDES = {
    429: (1444, 0.6485, 0.3007),  # Dire Maul, Feralas
    469: (1428, 0.330, 0.252),    # Blackwing Lair, Burning Steppes (Blackrock Mountain)
    409: (1427, 0.271, 0.725),    # Molten Core, Searing Gorge (Blackrock Mountain)
}

# Doors that the game's AreaPOI table does hold: id -> (AreaPOI id, zone UiMap).
# The map point is the game's own mark of the door and beats the corpse spot, which can
# sit a little way off (Wailing Caverns, Uldaman); each agrees with an independent guide.
POI = {
    43: (1068, 1413),    # Wailing Caverns: The Barrens
    70: (1027, 1418),    # Uldaman: Badlands
    109: (1013, 1435),   # Sunken Temple: Swamp of Sorrows
    249: (1094, 1445),   # Onyxia's Lair: Dustwallow Marsh
    289: (710, 1422),    # Scholomance: Western Plaguelands
    349: (1148, 1443),   # Maraudon: Desolace
    2784: (1239, 1440),  # Demon Fall Canyon: Ashenvale
}

# Dungeons with a map and a door but no boss in the tables yet.
KEEP_EMPTY = {3109}
# Test content in the shipped tables (its only boss is called "Testwerk").
SKIP_IDS = {2720}
# A one-player map with a boss of its own (a second Naxxramas map).
KEEP_SOLO = {2921}

SKIP_NAMES = ("test", "unused")
# Sunken Temple keeps three boss lists (5, 10 and 20 players) with different fights; all of
# them are kept, the five-player list first, because a run can meet any of them.
UNION_ALL = {109}

FIVE_MAN = ("0", "1", "201", "184")  # difficulty ids that are the plain group-of-five lists


def rows(directory, name):
    with open(directory / f"{name}.csv", newline="", encoding="utf-8", errors="replace") as f:
        return list(csv.DictReader(f))


def lua(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main(directory):
    maps = rows(directory, "Map")
    encounters = rows(directory, "DungeonEncounter")
    difficulty = rows(directory, "MapDifficulty")
    uimap = {r["ID"]: r for r in rows(directory, "UiMap")}
    assign = rows(directory, "UiMapAssignment")
    pois = {r["ID"]: r for r in rows(directory, "AreaPOI")}

    def to_ui(ui, continent, wx, wy):
        found = None
        for a in assign:
            if a["UiMapID"] != str(ui) or a["MapID"] != str(continent):
                continue
            r = [float(a[f"Region_{i}"]) for i in range(6)]
            if not (r[0] <= wx <= r[3] and r[1] <= wy <= r[4]):
                continue
            u = [float(a["UiMin_0"]), float(a["UiMin_1"]), float(a["UiMax_0"]), float(a["UiMax_1"])]
            x = u[0] + (r[4] - wy) / (r[4] - r[1]) * (u[2] - u[0])
            y = u[1] + (r[3] - wx) / (r[3] - r[0]) * (u[3] - u[1])
            found = (x, y)
        return found

    out = []
    skipped = []
    for m in maps:
        mid = int(m["ID"])
        if m["InstanceType"] not in ("1", "2"):
            continue
        name = m["MapName_lang"]
        if any(word in name.lower() for word in SKIP_NAMES):
            skipped.append((mid, name, "test or unused"))
            continue
        if mid in SKIP_IDS:
            skipped.append((mid, name, "test content"))
            continue
        kind = "dungeon" if m["InstanceType"] == "1" else "raid"
        sizes = {r["DifficultyID"]: int(r["MaxPlayers"]) for r in difficulty if r["MapID"] == m["ID"]}
        if not sizes or (max(sizes.values()) < 5 and not (mid in KEEP_SOLO)):
            skipped.append((mid, name, "no group size"))
            continue
        # Bosses: the group-of-five lists (a map keeps several, some with only part of the
        # bosses), merged by name. The ten and twenty player versions are other lists.
        by_diff = {}
        for e in encounters:
            if e["MapID"] == m["ID"]:
                by_diff.setdefault(e["DifficultyID"], []).append(e)
        if kind == "dungeon":
            lists = [by_diff[d] for d in FIVE_MAN if d in by_diff]
        else:
            lists = [by_diff[d] for d in by_diff if d == "0"] or list(by_diff.values())
        bosses = []
        if lists:
            lists.sort(key=len, reverse=True)
            seen = {}
            for e in lists[0] + [e for rest in lists[1:] for e in rest]:
                if e["Name_lang"] not in seen:
                    seen[e["Name_lang"]] = e
            bosses = sorted(seen.values(), key=lambda e: (int(e["OrderIndex"]), int(e["ID"])))
            if mid in UNION_ALL:
                main = {e["Name_lang"] for e in lists[0]}
                rest = [e for d in sorted(by_diff) for e in by_diff[d] if e["Name_lang"] not in main]
                extra = {}
                for e in rest:
                    extra.setdefault(e["Name_lang"], e)
                bosses = sorted(lists[0], key=lambda e: (int(e["OrderIndex"]), int(e["ID"]))) + list(extra.values())
        if not bosses and mid not in KEEP_EMPTY:
            skipped.append((mid, name, "no bosses"))
            continue
        if kind == "dungeon":
            size = sizes.get("1", max(sizes.values()))
        else:
            size = max(sizes.values())
        entrance = None
        if mid in OVERRIDES:
            entrance = OVERRIDES[mid]
        elif mid in POI:
            poi = pois[str(POI[mid][0])]
            p = to_ui(POI[mid][1], int(poi["ContinentID"]), float(poi["Pos_0"]), float(poi["Pos_1"]))
            entrance = (POI[mid][1],) + p if p else None
        elif mid in ZONE and m["CorpseMapID"] != "-1":
            p = to_ui(ZONE[mid], int(m["CorpseMapID"]), float(m["Corpse_0"]), float(m["Corpse_1"]))
            if p and 0 <= p[0] <= 1 and 0 <= p[1] <= 1:
                entrance = (ZONE[mid],) + p
            else:
                sys.exit(f"{name}: door falls outside zone {ZONE[mid]}")
        out.append((mid, name, kind, size, entrance, bosses))

    lines = [
        "local _, T = ...",
        "",
        "-- Generated by tools/gen_dungeons.py from the game's own tables (build 1.60.1.70888). Do not edit by hand.",
        "-- Key: instance map id. Bosses are DungeonEncounter ids and names. entrance: zone map and position, when known.",
        "T.DungeonIndex = {",
    ]
    for mid, name, kind, size, entrance, bosses in sorted(out):
        lines.append(f"\t[{mid}] = {{ name = {lua(name)}, kind = \"{kind}\", size = {size},")
        if entrance:
            lines.append(f"\t\tentrance = {{ m = {entrance[0]}, x = {entrance[1]:.3f}, y = {entrance[2]:.3f} }},")
        lines.append("\t\tbosses = {")
        for e in bosses:
            lines.append(f"\t\t\t{{ id = {int(e['ID'])}, name = {lua(e['Name_lang'])} }},")
        lines.append("\t\t} },")
    lines.append("}")
    OUT.write_text("\n".join(lines) + "\n")
    print(f"{len(out)} instances written, {sum(1 for o in out if o[4])} with a door")
    for item in skipped:
        print("skipped", *item)
    for o in out:
        if not o[4]:
            print("no door:", o[0], o[1])


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(pathlib.Path(sys.argv[1]))
