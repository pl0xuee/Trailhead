#!/usr/bin/env bash
# Offline checks: Lua 5.1 syntax for every file, no stray globals in the addon, then the test
# suite. Run from anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."
find Trailhead tests -name '*.lua' -print0 | xargs -0 -n1 luac5.1 -p

# Every global the addon writes on purpose. Anything else is a missing `local`: it leaks into
# every other addon and can clash with the game's own names.
ALLOWED_GLOBALS=" TrailheadDB TrailheadCharDB SLASH_TRAILHEAD1 SLASH_TRAILHEAD2 BINDING_HEADER_TRAILHEAD BINDING_NAME_TRAILHEAD_TOGGLE Trailhead_OnAddonCompartmentClick Trailhead "
stray=0
while IFS= read -r -d '' file; do
	while read -r name; do
		[ -z "$name" ] && continue
		case "$ALLOWED_GLOBALS" in
			*" $name "*) ;;
			*) echo "stray global '$name' written in $file"; stray=1 ;;
		esac
	done < <(luac5.1 -p -l "$file" | awk '/SETGLOBAL/ { print $NF }' | sort -u)
done < <(find Trailhead -name '*.lua' -print0)
if [ "$stray" -ne 0 ]; then
	echo "0 passed, 1 failed (stray globals)"
	exit 1
fi

lua5.1 tests/run.lua | tail -1
