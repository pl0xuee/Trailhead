#!/usr/bin/env bash
# Offline checks: Lua 5.1 syntax for every file, then the test suite. Run from anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."
find Trailhead tests -name '*.lua' -print0 | xargs -0 -n1 luac5.1 -p
lua5.1 tests/run.lua | tail -1
