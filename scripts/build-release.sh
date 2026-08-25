#!/usr/bin/env bash
set -euo pipefail

repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$repo_root"

tag="${1:-${GITHUB_REF_NAME:-}}"
if [[ -z "$tag" ]]; then
  echo "Usage: scripts/build-release.sh v1.2.3" >&2
  exit 2
fi

version="${tag#v}"
manifest_version="$(jq -r '.version' module.json)"
if [[ "$version" != "$manifest_version" ]]; then
  echo "Tag $tag does not match module.json version $manifest_version" >&2
  exit 1
fi

release_dir="$repo_root/dist"
stage_dir="$release_dir/token-flow"
rm -rf "$release_dir"
mkdir -p "$stage_dir"

cp -R languages scripts templates "$stage_dir/"
rm -f "$stage_dir/scripts/build-release.sh"
cp README.md "$stage_dir/"
[[ ! -f LICENSE ]] || cp LICENSE "$stage_dir/"

# The attached manifest describes this exact release. Its manifest URL remains
# the stable update channel, while download is immutable for historical installs.
jq --arg tag "$tag" \
  '.manifest = "https://github.com/shakugannosaints/token-flow/releases/latest/download/module.json"
   | .download = ("https://github.com/shakugannosaints/token-flow/releases/download/" + $tag + "/module.zip")' \
  module.json > "$stage_dir/module.json"

(
  cd "$stage_dir"
  zip -qr "$release_dir/module.zip" .
)
cp "$stage_dir/module.json" "$release_dir/module.json"

test "$(unzip -Z1 "$release_dir/module.zip" | grep -c '^module.json$')" -eq 1
if unzip -Z1 "$release_dir/module.zip" | grep -q '^token-flow/'; then
  echo "module.zip must contain module.json at its root, not inside token-flow/." >&2
  exit 1
fi
test "$(jq -r '.id' "$release_dir/module.json")" = "token-flow"
test "$(jq -r '.version' "$release_dir/module.json")" = "$version"
test "$(jq -r '.download' "$release_dir/module.json")" = \
  "https://github.com/shakugannosaints/token-flow/releases/download/$tag/module.zip"

echo "Built dist/module.json and dist/module.zip for $tag"
