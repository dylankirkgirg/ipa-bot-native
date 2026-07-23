#!/bin/bash
# Archives IPABot unsigned for a real device, packages it as an .ipa, and
# drops a copy in dist/ (repo-local) and ~/Desktop (iCloud Drive synced) so
# every build is available both places without a manual copy step.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild -project IPABot.xcodeproj -scheme IPABot -sdk iphoneos -configuration Release \
  archive -archivePath build/IPABot.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

rm -rf build/Payload build/IPABot.ipa
mkdir -p build/Payload dist
cp -R build/IPABot.xcarchive/Products/Applications/IPABot.app build/Payload/
(cd build && zip -qr IPABot.ipa Payload)

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" build/Payload/IPABot.app/Info.plist)
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" build/Payload/IPABot.app/Info.plist)
STAMP=$(date +%Y%m%d-%H%M%S)
NAME="IPABot-$VERSION-$BUILD-$STAMP.ipa"

mkdir -p ~/Desktop/IPABot-Builds
cp build/IPABot.ipa "dist/$NAME"
cp build/IPABot.ipa ~/Desktop/IPABot.ipa
cp build/IPABot.ipa "$HOME/Desktop/IPABot-Builds/$NAME"

echo "Built $NAME"
echo "  repo:    dist/$NAME"
echo "  iCloud:  ~/Desktop/IPABot.ipa (latest)"
echo "  iCloud:  ~/Desktop/IPABot-Builds/$NAME (archive, never overwritten)"
