#!/usr/bin/env bash
# Sends a release zip to the addon's CurseForge project. Run by .github/workflows/curseforge.yml
# when a GitHub release is published.
#
#   CF_API_TOKEN=... tools/curseforge_upload.sh <zip> [release|beta|alpha] [--dry-run]
#
# The version and the game version come from the TOC inside the zip, the project number from
# the repo's TOC, and the changelog from that version's section of CHANGELOG.md.
# --dry-run checks the token, the game version and the changelog, and uploads nothing.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
site=${CF_API_URL:-https://wow.curseforge.com}
forever_type=88568 # CurseForge's game version type for World of Warcraft: Forever

zip=${1:?usage: curseforge_upload.sh <zip> [release|beta|alpha] [--dry-run]}
type=${2:-release}
dry=${3:-}
: "${CF_API_TOKEN:?CF_API_TOKEN is not set (add it as a repository secret)}"
case $type in release | beta | alpha) ;; *) echo "Unknown release type: $type" >&2; exit 1 ;; esac
[ -f "$zip" ] || { echo "No such file: $zip" >&2; exit 1; }

toc_field() { sed -n "s/^## $1: *\\([^ ,]*\\).*/\\1/p" | tr -d '\r' | head -n1; }
project=$(toc_field X-Curse-Project-ID <"$root/Trailhead/Trailhead.toc")
zip_toc=$(unzip -p "$zip" Trailhead/Trailhead.toc)
version=$(toc_field Version <<<"$zip_toc")
interface=$(toc_field Interface <<<"$zip_toc")
[[ $project =~ ^[0-9]+$ ]] || { echo "No X-Curse-Project-ID in Trailhead/Trailhead.toc" >&2; exit 1; }
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "No usable Version in the zip's TOC: '$version'" >&2; exit 1; }
[[ $interface =~ ^[0-9]{5,6}$ ]] || { echo "No usable Interface in the zip's TOC: '$interface'" >&2; exit 1; }
# 16001 is 1.60.1
game="$((10#$interface / 10000)).$((10#$interface / 100 % 100)).$((10#$interface % 100))"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

awk -v head="## $version" '$0 == head { on = 1; next } /^## / { on = 0 } on' "$root/CHANGELOG.md" >"$tmp/changelog.md"
grep -q '[^[:space:]]' "$tmp/changelog.md" || { echo "CHANGELOG.md has no section '## $version'" >&2; exit 1; }

code=$(curl -sS -o "$tmp/versions.json" -w '%{http_code}' -H "x-api-token: $CF_API_TOKEN" "$site/api/game/wow/versions")
if [ "$code" != 200 ]; then
	echo "CurseForge refused the game version list (HTTP $code). Is CF_API_TOKEN right?" >&2
	head -c 400 "$tmp/versions.json" >&2 || true
	exit 1
fi
version_id=$(jq -r --arg v "$game" --argjson t "$forever_type" \
	'[.[] | select(.gameVersionTypeID == $t and .name == $v) | .id] | first // empty' "$tmp/versions.json")
if [ -z "$version_id" ]; then
	echo "CurseForge has no Forever game version named $game. It lists:" >&2
	jq -r --argjson t "$forever_type" '[.[] | select(.gameVersionTypeID == $t) | .name] | join(", ")' "$tmp/versions.json" >&2
	exit 1
fi

echo "Trailhead $version, $type, for Forever $game (game version $version_id), project $project"
if [ "$dry" = "--dry-run" ]; then
	echo "Dry run: the token was accepted and nothing was uploaded."
	exit 0
fi

jq -n --arg name "Trailhead $version" --argjson id "$version_id" --arg type "$type" --rawfile log "$tmp/changelog.md" \
	'{displayName: $name, gameVersions: [$id], releaseType: $type, changelog: $log, changelogType: "markdown"}' >"$tmp/metadata.json"
code=$(curl -sS --retry 3 --retry-delay 10 -o "$tmp/result.json" -w '%{http_code}' \
	-H "x-api-token: $CF_API_TOKEN" -F "metadata=<$tmp/metadata.json" -F "file=@$zip" \
	"$site/api/projects/$project/upload-file")
if [ "$code" != 200 ]; then
	echo "Upload failed (HTTP $code)." >&2
	head -c 800 "$tmp/result.json" >&2 || true
	exit 1
fi
echo "Uploaded. CurseForge file $(jq -r '.id // "?"' "$tmp/result.json"); it shows once a moderator approves it."
