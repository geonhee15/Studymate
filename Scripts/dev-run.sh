#!/bin/zsh
# Dev helper: relaunch the built app on a given screen and save a PNG of the window.
#   Scripts/dev-run.sh [screen] [snapshot.png] [delay-seconds]
#   screen: home | unit:1 | lesson:1-1 | practice:1-1 | quiz:1 | test:1 | mistakes | pastpapers | mock | stats | cheatsheet | settings
set -euo pipefail
cd "$(dirname "$0")/.."
SCREEN="${1:-home}"
NAME="${SCREEN//:/-}"
OUT="${2:-$PWD/build/snap-$NAME.png}"
DELAY="${3:-3}"
[[ "$OUT" = /* ]] || OUT="$PWD/$OUT"
pkill -x Studymate 2>/dev/null || true
sleep 0.5
rm -f "$OUT"
(STUDYMATE_TAB="$SCREEN" STUDYMATE_SNAPSHOT="$OUT" STUDYMATE_SNAPSHOT_DELAY="$DELAY" STUDYMATE_SNAPSHOT_QUIT=1 \
  ./build/Studymate.app/Contents/MacOS/Studymate > build/app.log 2>&1 &)
sleep $((DELAY + 3))
[[ -f "$OUT" ]] && echo "snapshot: $OUT" || { echo "snapshot not written"; tail -5 build/app.log; }
