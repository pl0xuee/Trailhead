#!/usr/bin/env bash
# Builds a release zip locally: checks first, then zips the Trailhead folder (which keeps
# THIRD-PARTY-LICENSES.txt and LICENSE.txt if they are inside it). Output: dist/Trailhead-<version>.zip
set -euo pipefail
cd "$(dirname "$0")/.."
tools/check.sh
version=$(grep -m1 '^## Version' Trailhead/Trailhead.toc | cut -d' ' -f3)
mkdir -p dist
rm -f "dist/Trailhead-$version.zip"
zip -qr "dist/Trailhead-$version.zip" Trailhead -x '*.bak' -x '*~'
cp "dist/Trailhead-$version.zip" dist/Trailhead.zip # the name the README download link points at
echo "Built dist/Trailhead-$version.zip (and dist/Trailhead.zip)"
