#!/usr/bin/env bash
# Regenerate altstore.json for a versioned release and push it back to main
# with ci.skip so the raw feed stays current without starting another
# pipeline. Only the newest version is prepended; older versions stay in the
# feed so users can install or downgrade.
#
# Usage: update-altstore.sh <release-tag>
set -euo pipefail

TAG="${1:-}"
case "$TAG" in
  v[0-9]*) ;;
  *)
    echo "update-altstore: $TAG is not a version tag, skipping"
    exit 0
    ;;
esac

IPA="release-assets/calc84-ios-arm64-unsigned.ipa"
if [ ! -f "$IPA" ]; then
  echo "update-altstore: $IPA missing, skipping"
  exit 0
fi

VERSION="${TAG#v}"
SIZE=$(stat -c%s "$IPA")
DATE=$(gh release view "$TAG" -R justacalico/calc84 --json publishedAt -q .publishedAt 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
NOTES=$(gh release view "$TAG" -R justacalico/calc84 --json body -q .body 2>/dev/null | head -40 || true)
[ -n "$NOTES" ] || NOTES="See the release notes for details."

jq \
  --arg version "$VERSION" \
  --arg date "$DATE" \
  --arg notes "$NOTES" \
  --arg url "https://github.com/justacalico/calc84/releases/download/$TAG/calc84-ios-arm64-unsigned.ipa" \
  --argjson size "$SIZE" '
  .apps[0].versions = (
    [{
      version: $version,
      date: $date,
      localizedDescription: $notes,
      downloadURL: $url,
      size: $size,
      minOSVersion: "13.0"
    }] + [(.apps[0].versions // [])[] | select(.version != $version)]
  )
  | .apps[0].version = $version
  | .apps[0].versionDate = $date
  | .apps[0].downloadURL = $url
  | .apps[0].size = $size
' altstore.json > altstore.json.tmp && mv altstore.json.tmp altstore.json

jq -e ".apps[0].versions[0].version == \"$VERSION\"" altstore.json >/dev/null

if git diff --quiet altstore.json; then
  echo "update-altstore: already up to date"
  exit 0
fi

git config user.name "GitLab CI"
git config user.email "ci@gitlab.com"
git add altstore.json
git commit -q -m "chore: 更新 AltStore 源至 $TAG"

push_update() {
  git push -o ci.skip gitlab-auth HEAD:main
}

if ! push_update; then
  echo "Main moved while updating, rebasing onto latest"
  git fetch gitlab-auth main "+refs/tags/*:refs/tags/*"
  git rebase gitlab-auth/main
  push_update
fi

echo "update-altstore: $VERSION published"
