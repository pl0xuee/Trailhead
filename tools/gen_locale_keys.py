#!/usr/bin/env python3
"""Lists every text key the addon passes through L["..."], for translators.

  python3 tools/gen_locale_keys.py            one key per line, sorted
  python3 tools/gen_locale_keys.py --lua xxXX a ready-to-fill locale file for that locale

The keys are the English text itself (Trailhead/Locales/enUS.lua returns the key), so a
translation file only maps English text to the translated text. Run from anywhere.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "Trailhead"

# L["text"] with Lua escapes; strings may contain \" and \n.
KEY = re.compile(r'\bL\[\s*"((?:[^"\\\n]|\\.)*)"\s*\]')
ESCAPES = {"n": "\n", "t": "\t", "\\": "\\", '"': '"', "'": "'"}


def unescape(raw):
    return re.sub(r"\\(.)", lambda m: ESCAPES.get(m.group(1), m.group(1)), raw)


def lua_quote(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t") + '"'


def keys():
    found = {}
    for path in sorted(ROOT.rglob("*.lua")):
        if path.parent.name == "Locales":
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for match in KEY.finditer(line):
                found.setdefault(unescape(match.group(1)), f"{path.relative_to(ROOT)}:{number}")
    return found


def main(argv):
    found = keys()
    if len(argv) >= 2 and argv[0] == "--lua":
        locale = argv[1]
        print(f'-- Trailhead translation for {locale}. Fill in the right-hand side; leave a line out to keep English.')
        print('-- Add it to Trailhead.toc straight after Locales\\enUS.lua, so it loads before any other file.')
        print('local _, T = ...')
        print(f'if GetLocale() ~= "{locale}" then return end')
        print('local L = T.L')
        print('local t = {')
        for key in sorted(found):
            print(f'\t[{lua_quote(key)}] = "",')
        print('}')
        print('setmetatable(L, { __index = function(_, key) return t[key] ~= nil and t[key] ~= "" and t[key] or key end })')
    else:
        for key in sorted(found):
            print(key.replace("\n", "\\n"))
        print(f"# {len(found)} keys", file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1:])
