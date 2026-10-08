#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcrun simctl list devices available -j > build/devices.json
DEVICE=$(python3 -c 'import json; d=json.load(open("build/devices.json")); print(next(x["udid"] for group in d["devices"].values() for x in group if x["name"].startswith("iPhone")))')
xcrun simctl boot "$DEVICE" || true
xcrun simctl bootstatus "$DEVICE" -b
xcodebuild -project OudLive.xcodeproj -scheme OudLive -configuration Debug \
  -sdk iphonesimulator -destination "id=$DEVICE" -derivedDataPath build/Simulator \
  CODE_SIGNING_ALLOWED=NO build > build/simulator.log 2>&1 || { tail -n 80 build/simulator.log; exit 1; }
xcrun simctl install "$DEVICE" build/Simulator/Build/Products/Debug-iphonesimulator/OudLive.app
for PAGE in portrait loops presets hero landscape rack mixer effects library memories legacy; do
  PALETTE=original
  ERA=eighties
  case "$PAGE" in simple) ERA=nineties;; stage) ERA=modern;; esac
  xcrun simctl launch "$DEVICE" com.oudlive.personal "--console-$PAGE" "--$PAGE" "--theme-studio" "--palette-$PALETTE" "--era-$ERA"
  sleep 5
  xcrun simctl io "$DEVICE" screenshot "build/$PAGE.png"
  WIDTH=430
  if [ "$PAGE" = landscape ]; then
    sips -r 270 "build/$PAGE.png" >/dev/null
    WIDTH=1000
  fi
  sips --resampleWidth "$WIDTH" "build/$PAGE.png" --out "build/$PAGE-preview.png" >/dev/null
  sips -s format jpeg -s formatOptions 75 "build/$PAGE-preview.png" --out "build/$PAGE-log.jpg" >/dev/null
  xcrun simctl terminate "$DEVICE" com.oudlive.personal
done
# Compact screenshots in diagnostic logs let a remote reviewer inspect the exact
# simulator UI even if their machine cannot download binary artifacts directly.
python3 - <<'PY'
import base64
from pathlib import Path
for name in ['portrait','loops','presets','hero','landscape','rack','mixer','effects','library','memories','legacy']:
    encoded=base64.b64encode(Path('build/'+name+'-log.jpg').read_bytes()).decode()
    for i in range(0,len(encoded),6000): print('OUD_SCREEN_'+name+':'+encoded[i:i+6000])
PY
