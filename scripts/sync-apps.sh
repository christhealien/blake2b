#!/bin/sh
# Make this store match what is published in the app repos: for each app, take the app folder from the
# newest release tag of its source repo. Run from the root of the store checkout; commits nothing itself.
#   APPS="folder|repo-url|tag-glob;folder|repo-url|tag-glob"   (defaults below)
set -eu
OWNER="${OWNER:-christhealien}"
BASE="${BASE:-https://github.com/$OWNER}"
APPS="${APPS:-blake2b-asic-control|$BASE/blake2b-asic-control|v*;blake2b-datum-gateway|$BASE/datum-gateway-umbrel|datum-v*}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
IFS=';'
for entry in $APPS; do
  folder="${entry%%|*}"; rest="${entry#*|}"; url="${rest%%|*}"; glob="${rest#*|}"
  tag="$(git ls-remote --tags --refs "$url" "$glob" | sed 's|.*refs/tags/||' | sort -V | tail -n1)"
  if [ -z "$tag" ]; then echo "$folder: no release tag matching $glob in $url, leaving as is"; continue; fi
  src="$tmp/$folder"
  git -c advice.detachedHead=false clone -q --depth 1 --branch "$tag" "$url" "$src"
  if [ ! -f "$src/$folder/umbrel-app.yml" ] || ! grep -q "^id: $folder\$" "$src/$folder/umbrel-app.yml"; then
    echo "$folder: $tag has no valid $folder/umbrel-app.yml, leaving as is"; continue
  fi
  rm -rf "./$folder"
  cp -r "$src/$folder" "./$folder"
  mkdir -p "./$folder/data"; [ -e "./$folder/data/.gitkeep" ] || : > "./$folder/data/.gitkeep"
  echo "$folder: from $url at $tag (version $(sed -n 's/^version: "\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "./$folder/umbrel-app.yml" | head -1))"
done
