#!/usr/bin/env python3
"""Writes Trailhead/Data/Builds/<CLASS>.lua from tools/builds/<CLASS>.json.

A build is written by talent name; this script looks each name up in the class's talent
tree (tests/fixtures/<class>_tree.lua, the game's own data for build 1.60.1.70888), checks
that the game would take every point in the order given, and writes the Lua file keyed by
the game's node and spell ids.

    tools/gen_builds.py            every class with a spec
    tools/gen_builds.py MAGE       one class
    tools/gen_builds.py --check MAGE   check only, write nothing

Rules checked: a talent's row opens with 5 points in its tree for every row above it; a
talent that leads to another must be full first; no talent goes over its maximum; a build
is 51 points (levels 10 to 60); every talent used has a reason, and every reason is used.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
POINTS = 51
ICONS = {"spark", "sword", "shield", "book", "burst", "moon", "snow", "pick", "bulb", "cap", "hammer", "mtn", "wing"}


def tree(cls):
    text = (ROOT / "tests" / "fixtures" / f"{cls.lower()}_tree.lua").read_text()
    tabs = {int(g): (name, int(order)) for g, name, order in
            re.findall(r'groupID = (\d+), displayName = "([^"]+)", orderIndex = (\d+)', text)}
    rows = {int(k): int(v) for k, v in re.findall(r"\[(\d+)\] = (\d+)", text)}
    nodes = {}
    for row in re.findall(r'"(\d+\|[^"]*)"', text):
        node, _x, y, top, _ranks, groups, spell, name, edges = row.split("|")
        node = int(node)
        tab = next(int(g) for g in groups.split(",") if int(g) in tabs)
        nodes[node] = {
            "id": node, "max": int(top), "spell": int(spell), "name": name, "tab": tab, "tabName": tabs[tab][0],
            "row": rows.get(node, (int(y) - 2130) // 600), "to": [int(e) for e in edges.split(",") if e], "needs": [],
        }
    for node in nodes.values():
        for target in node["to"]:
            nodes[target]["needs"].append(node["id"])
    return tabs, nodes


def lookup(nodes):
    by_name = {}
    for node in nodes.values():
        by_name.setdefault(node["name"], []).append(node)
        by_name.setdefault(f'{node["tabName"]}/{node["name"]}', []).append(node)

    def find(name, where):
        found = by_name.get(name)
        if not found:
            raise SystemExit(f"{where}: no talent named {name!r}")
        if len(found) > 1:
            raise SystemExit(f"{where}: {name!r} is in more than one tree; write it as 'Tree/{name}'")
        return found[0]
    return find


def check(cls, build, nodes, find):
    where = f"{cls} {build['id']}"
    for key in ("id", "name", "suits", "gear", "why", "order", "fight"):
        if key not in build:
            raise SystemExit(f"{where}: missing {key!r}")
    if build.get("icon", "spark") not in ICONS:
        raise SystemExit(f"{where}: icon must be one of {sorted(ICONS)}")
    ranks, in_tab, used, total = {}, {}, set(), 0
    for index, (name, points) in enumerate(build["order"], 1):
        node = find(name, where)
        used.add(node["id"])
        for _ in range(points):
            total += 1
            at = f"{where}: point {total} ({name}, entry {index})"
            if ranks.get(node["id"], 0) >= node["max"]:
                raise SystemExit(f"{at}: {name} only has {node['max']} ranks")
            if in_tab.get(node["tab"], 0) < node["row"] * 5:
                raise SystemExit(f"{at}: row {node['row'] + 1} of {node['tabName']} needs {node['row'] * 5} points in that tree, "
                                 f"and only {in_tab.get(node['tab'], 0)} are there")
            for need in node["needs"]:
                if ranks.get(need, 0) < nodes[need]["max"]:
                    raise SystemExit(f"{at}: needs {nodes[need]['name']} at {nodes[need]['max']} of {nodes[need]['max']} first")
            ranks[node["id"]] = ranks.get(node["id"], 0) + 1
            in_tab[node["tab"]] = in_tab.get(node["tab"], 0) + 1
    if total != POINTS:
        raise SystemExit(f"{where}: {total} points, not {POINTS}")
    reasons = {find(name, where)["id"]: text for name, text in build["why"].items()}
    if set(reasons) != used:
        missing = [nodes[n]["name"] for n in used - set(reasons)]
        extra = [nodes[n]["name"] for n in set(reasons) - used]
        raise SystemExit(f"{where}: reasons do not match the order. No reason for {missing}; reason but no points for {extra}")
    for name, text in build["why"].items():
        if not 12 <= len(text) <= 95:
            raise SystemExit(f"{where}: the reason for {name} must be 12 to 95 characters ({len(text)})")
    for talent, text in build["fight"]:
        if talent is not None and find(talent, where)["id"] not in used:
            raise SystemExit(f"{where}: fight line names {talent!r}, which the build never takes")
        if not 20 <= len(text) <= 110:
            raise SystemExit(f"{where}: fight lines must be 20 to 110 characters ({len(text)}): {text!r}")
    if not 3 <= len(build["fight"]) <= 7:
        raise SystemExit(f"{where}: 3 to 7 fight lines")
    if not 60 <= len(build["suits"]) <= 190:
        raise SystemExit(f"{where}: 'suits' must be 60 to 190 characters ({len(build['suits'])})")
    if not 30 <= len(build["gear"]) <= 150:
        raise SystemExit(f"{where}: 'gear' must be 30 to 150 characters ({len(build['gear'])})")
    return ranks, in_tab


def quote(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write(cls, spec, tabs, nodes, find):
    out = [
        "local _, T = ...", "local L = T.L", "",
        f"-- {cls.capitalize()} builds. Written by tools/gen_builds.py from tools/builds/{cls}.json: change that file,",
        "-- not this one. Talents are keyed by the game's own node ids, each with the spell it must",
        "-- still be; a build whose talents no longer match the live tree is not offered.", "",
        "T.Builds = T.Builds or {}", "", f"T.Builds.{cls} = {{",
    ]
    for build in spec["builds"]:
        _ranks, in_tab = check(cls, build, nodes, find)
        split = ", ".join(f"{in_tab[t]} {tabs[t][0]}" for t in sorted(in_tab, key=lambda t: -in_tab[t]))
        out += ["\t{", f"\t\tid = {quote(build['id'])},", f"\t\tname = L[{quote(build['name'])}],", f"\t\ticon = {quote(build.get('icon', 'spark'))},"]
        if build.get("draft", True):
            out.append("\t\tdraft = true, -- not yet played to the top level")
        out += [f"\t\tsuits = L[{quote(build['suits'])}],", f"\t\tgear = L[{quote(build['gear'])}],", f"\t\t-- {split}.", "\t\ttalents = {"]
        seen = []
        for name, _points in build["order"]:
            node = find(name, cls)
            if node["id"] not in seen:
                seen.append(node["id"])
                reason = next(text for key, text in build["why"].items() if find(key, cls)["id"] == node["id"])
                out.append(f"\t\t\t[{node['id']}] = {{ spell = {node['spell']}, why = L[{quote(reason)}] }}, -- {node['name']}")
        out += ["\t\t},", "\t\torder = {"]
        line = []
        for name, points in build["order"]:
            line.append(f"{{ {find(name, cls)['id']}, {points} }}")
            if len(line) == 5:
                out.append("\t\t\t" + ", ".join(line) + ",")
                line = []
        if line:
            out.append("\t\t\t" + ", ".join(line) + ",")
        out += ["\t\t},", "\t\t-- What to press. A line with a node is shown once that talent has a point in it.", "\t\tfight = {"]
        for talent, text in build["fight"]:
            node = f"node = {find(talent, cls)['id']}, " if talent else ""
            out.append(f"\t\t\t{{ {node}text = L[{quote(text)}] }},")
        out += ["\t\t},", "\t},"]
    out += ["}", ""]
    return "\n".join(out)


def main(argv):
    only_check = "--check" in argv
    wanted = [a.upper() for a in argv if not a.startswith("--")]
    specs = sorted((ROOT / "tools" / "builds").glob("*.json"))
    for path in specs:
        cls = path.stem
        if wanted and cls not in wanted:
            continue
        spec = json.loads(path.read_text())
        tabs, nodes = tree(cls)
        text = write(cls, spec, tabs, nodes, lookup(nodes))
        if not only_check:
            (ROOT / "Trailhead" / "Data" / "Builds" / f"{cls}.lua").write_text(text)
        print(f"{cls}: {len(spec['builds'])} build(s) ok" + ("" if only_check else ", written"))


if __name__ == "__main__":
    main(sys.argv[1:])
