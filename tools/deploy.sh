#!/usr/bin/env bash
# Copies the addon into the game's AddOns folder, after the offline checks pass.
# A copy, not a link: a link into a work folder breaks when that folder goes away.
# Set TRAILHEAD_ADDONS to deploy somewhere else.
set -euo pipefail
cd "$(dirname "$0")/.."
ADDONS="${TRAILHEAD_ADDONS:-$HOME/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns}"
[ -d "$ADDONS" ] || { echo "AddOns folder not found: $ADDONS" >&2; exit 1; }
tools/check.sh
TARGET="$ADDONS/Trailhead"
rm -rf "$TARGET.new"
cp -r Trailhead "$TARGET.new"
rm -rf "$TARGET"
mv "$TARGET.new" "$TARGET"
echo "Deployed $(grep -m1 '^## Version' Trailhead/Trailhead.toc | cut -d' ' -f3) to $TARGET ($(du -sh "$TARGET" | cut -f1))"
