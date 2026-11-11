#!/usr/bin/env python3 -I
"""Builds Trailhead/Data/ClassSpells.lua from the game's own tables (wago.tools DB2 CSVs,
build 1.60.1.70888): the class trainer's spells by level, with ranks, and what a spell
uses up (SpellReagents, SpellTotems). Run: python3 -I tools/gen_guide_data.py [csv_dir]
The CSVs are untrusted data: this script only reads them as text."""
import csv, sys, os, collections

csv.field_size_limit(10**9)
D = (sys.argv[1] if len(sys.argv) > 1 else "/tmp/th-db2/csv") + "/"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Trailhead", "Data", "ClassSpells.lua")


def rows(name):
    with open(D + name + ".csv", newline="", encoding="utf-8", errors="replace") as f:
        return list(csv.DictReader(f))


def num(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return 0


names = {r["ID"]: r["Name_lang"] for r in rows("SpellName")}
subtext = {r["ID"]: r["NameSubtext_lang"] for r in rows("Spell")}
level = {}
for r in rows("SpellLevels"):
    if r["DifficultyID"] == "0":
        level[r["SpellID"]] = num(r["SpellLevel"]) or num(r["BaseLevel"])
traits = {r["SpellID"] for r in rows("TraitDefinition")}
power = {r["SpellID"] for r in rows("SpellPower")}
cooldown = {r["SpellID"] for r in rows("SpellCooldowns")}
misc = {r["SpellID"]: num(r["Attributes_0"]) for r in rows("SpellMisc")}
items = {r["ID"]: r["Display_lang"] for r in rows("ItemSparse")}
skills = {r["ID"]: r for r in rows("SkillLine")}
classes = {r["ID"]: r for r in rows("ChrClasses")}

owners = collections.defaultdict(set)
for r in rows("SkillRaceClassInfo"):
    owners[r["SkillID"]].add(num(r["ClassMask"]))

# Races that can learn each spell, from the ability rows (0 means every race). A spell open to
# four races or fewer is a racial one (Desperate Prayer, Touch of Weakness).
open_to, anyone = collections.defaultdict(int), set()
for r in rows("SkillLineAbility"):
    mask = num(r["RaceMasks_0"]) | num(r["RaceMasks_1"])
    if mask:
        open_to[r["Spell"]] |= mask & 0xFFFF
    else:
        anyone.add(r["Spell"])
# A rank 1 that only some races get (Holy Light) is not racial when the higher ranks are open to all.
open_names = {names[sid] for sid in anyone if sid in names}
racial = {sid for sid, mask in open_to.items()
          if sid not in anyone and bin(mask).count("1") <= 4 and names.get(sid) not in open_names}

HORDE_CITIES = ("Orgrimmar", "Undercity", "Thunder Bluff")
ALLIANCE_CITIES = ("Stormwind", "Ironforge", "Darnassus")

out = {}
for c in classes.values():
    mask = 1 << (num(c["ID"]) - 1)
    if not c["Filename"] or num(c["ID"]) > 11 or c["Filename"] in ("DEATHKNIGHT", "MONK", "DEMONHUNTER", "EVOKER"):
        continue
    best = {}
    for r in rows("SkillLineAbility"):
        line = skills.get(r["SkillLine"])
        if not line or line["CategoryID"] != "7" or r["AcquireMethod"] == "3":
            continue
        if mask not in owners[r["SkillLine"]] or not (num(r["ClassMask"]) == 0 or num(r["ClassMask"]) & mask):
            continue
        if line["DisplayName_lang"] in ("Beast Training",) or line["DisplayName_lang"].startswith("Pet"):
            continue
        sid = r["Spell"]
        # Racial spells are left out; the teleports are tied to a side by their names instead.
        if sid in racial and names.get(sid, "").split(":")[0] not in ("Teleport", "Portal"):
            continue
        name, lv = names.get(sid), level.get(sid, 0)
        if not name or lv <= 0 or sid in traits or misc.get(sid, 0) & 0x40:
            continue
        # Casts that cost something or recharge are abilities; the rest are procs and passives.
        if sid not in power and sid not in cooldown:
            continue
        rank = num(subtext.get(sid, "").replace("Rank", "").strip())
        faction = ""
        if name.startswith(("Teleport:", "Portal:")):
            city = name.split(":", 1)[1].strip()
            faction = "H" if city in HORDE_CITIES else "A" if city in ALLIANCE_CITIES else ""
        key = (name, rank)
        if key not in best or lv < best[key][0]:
            best[key] = (lv, name, rank, faction, sid)
    out[c["Filename"]] = sorted(best.values())

# What a spell uses up: reagent items and totems, for the spells above only.
totemcats = {r["ID"]: r["Name_lang"] for r in rows("TotemCategory")}
use = collections.defaultdict(dict)
reagents = {r["SpellID"]: r for r in rows("SpellReagents")}
totems = {r["SpellID"]: r for r in rows("SpellTotems")}
for cls, spells in out.items():
    for lv, name, rank, faction, sid in spells:
        found = []
        r = reagents.get(sid)
        if r:
            for i in range(8):
                if num(r["Reagent_%d" % i]) and num(r["ReagentCount_%d" % i]) > 0:
                    found.append((items.get(r["Reagent_%d" % i], "?"), num(r["ReagentCount_%d" % i])))
        t = totems.get(sid)
        if t:
            for i in range(2):
                if num(t["Totem_%d" % i]):
                    found.append((items.get(t["Totem_%d" % i], "?"), 1))
                # A totem spell needs the matching totem item in the bags (Earth, Fire, Water, Air).
                category = totemcats.get(t["RequiredTotemCategoryID_%d" % i])
                if category in ("Earth Totem", "Fire Totem", "Water Totem", "Air Totem"):
                    found.append((category, 1))
        for item, count in found:
            key = (name, item)
            if key not in use[cls] or lv < use[cls][key][0]:
                use[cls][key] = (lv, name, item, count, faction)


# A totem item is needed once per element, so keep only the first spell of each element.
for cls in use:
    seen = {}
    for key, v in sorted(use[cls].items(), key=lambda kv: kv[1]):
        if v[2].endswith(" Totem") and v[2] in seen:
            del use[cls][key]
        elif v[2].endswith(" Totem"):
            seen[v[2]] = True

roles = {c["Filename"]: num(c["RolesMask"]) for c in classes.values() if c["Filename"] in out}


def q(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


lines = ["-- Generated by tools/gen_guide_data.py from the game's own tables (build 1.60.1.70888). Do not edit.",
         "local _, T = ...", "",
         "-- Trainer spells by class: lines of level|name|rank|side (rank 0 = unranked, side A or H when it is one side's only).",
         "T.ClassSpells = {"]
for cls in sorted(out):
    body = ";".join("%d|%s|%d|%s" % (lv, name, rank, faction) for lv, name, rank, faction, sid in out[cls])
    lines.append("\t%s = %s," % (cls, q(body)))
lines += ["}", "", "-- What a class's spells use up: lines of level|spell|item|count|side, from the first spell that needs each item.",
          "T.ClassUses = {"]
for cls in sorted(use):
    body = ";".join("%d|%s|%s|%d|%s" % v for v in sorted(use[cls].values()))
    lines.append("\t%s = %s," % (cls, q(body)))
lines += ["}", "", "-- Which roles each class can fill (the game's own role mask: 2 tank, 4 healer, 8 damage).",
          "T.ClassRoles = {"]
for cls in sorted(roles):
    lines.append("\t%s = %d," % (cls, roles[cls]))
lines += ["}", ""]
with open(OUT, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))
print("wrote", os.path.normpath(OUT), sum(len(v) for v in out.values()), "spells")
