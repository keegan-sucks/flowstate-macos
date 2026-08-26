#!/usr/bin/env bash
#
# Cut a new Flowstate release and update the Homebrew cask in one step.
#
#   scripts/release.sh <version>      e.g.  scripts/release.sh 1.1
#
# It bumps the version, builds a Release .app, zips it, tags + pushes this repo,
# publishes a GitHub Release with the zip, then bumps version + sha256 in the cask
# on the tap repo. Uses your existing `gh` auth — no secrets required.
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "usage: $0 <version>   e.g. $0 1.1"
  exit 1
fi

APP_REPO="keegan-sucks/flowstate-macos"
TAP_REPO="keegan-sucks/homebrew-tap"
export PATH="/opt/homebrew/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Bumping project.yml to $VERSION"
sed -i '' -E "s/(MARKETING_VERSION: )\"[^\"]*\"/\1\"$VERSION\"/" project.yml

echo "==> Building Release"
xcodegen generate
xcodebuild -project Flowstate.xcodeproj -scheme Flowstate -configuration Release \
  -derivedDataPath build -destination 'platform=macOS' build >/dev/null

APP="build/Build/Products/Release/Flowstate.app"
ZIP="build/Flowstate.app.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
echo "==> version=$VERSION  sha256=$SHA"

echo "==> Tagging + pushing $APP_REPO"
git add project.yml
git commit -m "Release v$VERSION" || true
git tag -f "v$VERSION"
git push origin main
git push -f origin "v$VERSION"

echo "==> Publishing GitHub release"
if gh release view "v$VERSION" --repo "$APP_REPO" >/dev/null 2>&1; then
  gh release upload "v$VERSION" "$ZIP" --repo "$APP_REPO" --clobber
else
  gh release create "v$VERSION" "$ZIP" --repo "$APP_REPO" \
    --title "Flowstate $VERSION" --notes "Flowstate $VERSION"
fi

echo "==> Updating the cask in $TAP_REPO"
TAP_DIR="$(mktemp -d)"
gh repo clone "$TAP_REPO" "$TAP_DIR" >/dev/null 2>&1
git -C "$TAP_DIR" config user.name  "Keegan Burke"
git -C "$TAP_DIR" config user.email "services@keegan.sucks"
CASK="$TAP_DIR/Casks/flowstate.rb"
sed -i '' -E "s/(  version )\"[^\"]*\"/\1\"$VERSION\"/" "$CASK"
sed -i '' -E "s/(  sha256 )\"[^\"]*\"/\1\"$SHA\"/" "$CASK"
git -C "$TAP_DIR" add Casks/flowstate.rb
git -C "$TAP_DIR" commit -m "flowstate $VERSION" || true
git -C "$TAP_DIR" push origin HEAD
rm -rf "$TAP_DIR"

echo
echo "==> Released v$VERSION."
echo "    brew upgrade --cask flowstate"
echo "    (ad-hoc signed — first launch may need:"
echo "     xattr -dr com.apple.quarantine /Applications/Flowstate.app )"
