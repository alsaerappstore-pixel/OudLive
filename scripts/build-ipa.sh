#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
# A real device binary, never a simulator binary. Sideloadly signs it on Windows.
xcodebuild -project OudLive.xcodeproj -scheme OudLive \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData -resultBundlePath "build/Build-$(date +%s).xcresult" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
  build 2>&1 | tee build/build.log
APP="$PWD/build/DerivedData/Build/Products/Release-iphoneos/OudLive.app"
test -x "$APP/OudLive"
xcrun lipo -verify_arch arm64 "$APP/OudLive"
/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist"
# Package from a fresh temporary folder so failed/older builds cannot contaminate it.
STAGE=$(mktemp -d "$PWD/build/package.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/Payload"
ditto "$APP" "$STAGE/Payload/OudLive.app"
(cd "$STAGE" && /usr/bin/zip -qry OudLive-unsigned.ipa Payload)
mv "$STAGE/OudLive-unsigned.ipa" build/OudLive-unsigned.ipa
python3 scripts/verify-ipa.py build/OudLive-unsigned.ipa
(cd build && shasum -a 256 OudLive-unsigned.ipa > OudLive-unsigned.ipa.sha256)
echo 'Created build/OudLive-unsigned.ipa — use Sideloadly to sign and install.'
