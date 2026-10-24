#!/bin/zsh
# Regenerates docs/screenshots/*.png with sample data. Never touches real user data: every store is pointed at a
# scratch folder through STUDYMATE_DEBUG_DATA_DIR and seeded with STUDYMATE_DEBUG_SAMPLE=1.
#   ./build.sh debug && Scripts/screenshots.sh
set -u
cd "$(dirname "$0")/.."
OUT="$PWD/docs/screenshots"; mkdir -p "$OUT"
APP="./build/Studymate.app/Contents/MacOS/Studymate"
D="$(mktemp -d /tmp/studymate-shots.XXXXXX)"
export STUDYMATE_WINDOW=1180x760 STUDYMATE_DEBUG_DATA_DIR="$D" STUDYMATE_DEBUG_SAMPLE=1 STUDYMATE_SNAPSHOT_QUIT=1

shot() {  # shot <name> <tab> <delay> [extra env...]
  local name=$1 tab=$2 delay=$3; shift 3
  pkill -x Studymate 2>/dev/null; sleep 0.4; rm -f "$OUT/$name.png"
  (env STUDYMATE_TAB="$tab" STUDYMATE_SNAPSHOT="$OUT/$name.png" STUDYMATE_SNAPSHOT_DELAY="$delay" "$@" "$APP" > "$D/log-$name.txt" 2>&1 &)
  sleep $((delay + 3))
  [[ -f "$OUT/$name.png" ]] && echo "✔ $name" || echo "✖ $name (see $D/log-$name.txt)"
}

shot home home 3
shot unit unit:1 3
shot lesson lesson:1-1 4
shot lesson-figure lesson:5-2 4
shot practice practice:1-2 5 STUDYMATE_DEBUG_PROBLEM="select:C,hint:1"
shot practice-solved practice:1-4 5 STUDYMATE_DEBUG_PROBLEM="submit:B"
shot stuck-sheet practice:1-4 5 STUDYMATE_DEBUG_PROBLEM="submit:E" STUDYMATE_SNAPSHOT_SCREEN=1
shot practice-jarvis-ko practice:1-5 5 STUDYMATE_DEBUG_THEME=jarvis STUDYMATE_DEBUG_LANG=ko STUDYMATE_DEBUG_PROBLEM="select:D"
shot lesson-dark lesson:1-3 4 STUDYMATE_DEBUG_APPEARANCE=dark
shot quiz-summary quiz:1 6 STUDYMATE_DEBUG_PROBLEM="submit:D,next,submit:C,next,submit:C,next,submit:D,next,submit:B,next,submit:C,next,submit:A,next,submit:B,next"
shot mistakes mistakes 3
shot pastpapers pastpapers 3
shot mock mock 3
shot mock-exam mock:1 5 STUDYMATE_DEBUG_PROBLEM="answer:B,go:12"
shot mock-result mock:1 6 STUDYMATE_DEBUG_PROBLEM="fill:C,finish"
shot paper-grading paper:2019 4 STUDYMATE_DEBUG_PROBLEM="fill:C,grade"
shot stats stats 4
shot cheatsheet cheatsheet 4
shot flashcards cheatsheet 4 STUDYMATE_DEBUG_FLASHCARDS=1
shot settings settings 3
pkill -x Studymate 2>/dev/null
rm -rf "$D"
echo "done → $OUT"
