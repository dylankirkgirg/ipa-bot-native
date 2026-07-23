#!/bin/bash
# Archives IPABot unsigned for a real device, packages it as an .ipa, and
# drops a copy in dist/ (repo-local) and ~/Desktop (iCloud Drive synced) so
# every build is available both places without a manual copy step.
#
# Versioning is automatic: marketing version auto-bumps its patch component
# (X.Y.Z -> X.Y.Z+1) every run, tracked in VERSION at repo root. Build number
# is the git commit count, so it's always unique and always increasing with
# no state file needed. Bump minor/major manually by editing VERSION.
set -euo pipefail
cd "$(dirname "$0")/.."

IFS='.' read -r MAJOR MINOR PATCH < VERSION
PATCH=$((PATCH + 1))
MARKETING_VER="$MAJOR.$MINOR.$PATCH"
echo "$MARKETING_VER" > VERSION
BUILD_NUM=$(git rev-list --count HEAD)

xcodebuild -project IPABot.xcodeproj -scheme IPABot -sdk iphoneos -configuration Release \
  archive -archivePath build/IPABot.xcarchive \
  MARKETING_VERSION="$MARKETING_VER" CURRENT_PROJECT_VERSION="$BUILD_NUM" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

rm -rf build/Payload build/IPABot.ipa
mkdir -p build/Payload dist
cp -R build/IPABot.xcarchive/Products/Applications/IPABot.app build/Payload/
(cd build && zip -qr IPABot.ipa Payload)

NAME="IPABot-$MARKETING_VER-$BUILD_NUM.ipa"

mkdir -p ~/Desktop/IPABot-Builds
cp build/IPABot.ipa "dist/$NAME"
cp build/IPABot.ipa ~/Desktop/IPABot.ipa
cp build/IPABot.ipa "$HOME/Desktop/IPABot-Builds/$NAME"

git add VERSION
git commit -q -m "Bump version to $MARKETING_VER (build $BUILD_NUM)" || true

echo "Built $NAME"
echo "  repo:    dist/$NAME"
echo "  iCloud:  ~/Desktop/IPABot.ipa (latest)"
echo "  iCloud:  ~/Desktop/IPABot-Builds/$NAME (archive, never overwritten)"
