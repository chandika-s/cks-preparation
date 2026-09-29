#!/bin/bash
# Prints today's CKS study section based on the current date.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

TODAY="$(date +"%b %e" | tr -s ' ')"   # e.g. "Sep 23", "Nov 5"
TODAY_ISO="$(date +%F)"
START_ISO="2026-09-22"
END_ISO="2026-11-15"

if [[ "$TODAY_ISO" < "$START_ISO" ]]; then
  echo "CKS plan starts $START_ISO — nothing scheduled yet."
  exit 0
fi
if [[ "$TODAY_ISO" > "$END_ISO" ]]; then
  echo "CKS plan window ($START_ISO to $END_ISO) is over. Exam day has passed — go check your result, or replan if you rescheduled."
  exit 0
fi

MATCH="$(grep -rn --include='day-*.md' "^#\+.*($TODAY)" plan 2>/dev/null | head -1 || true)"
[[ -z "$MATCH" ]] && MATCH="$(grep -n "^#\+.*($TODAY)" SETUP.md 2>/dev/null | sed 's/^/SETUP.md:/' | head -1 || true)"

if [[ -z "$MATCH" ]]; then
  echo "No scheduled entry found for today ($TODAY). Check README.md's calendar table."
  exit 0
fi

FILE="${MATCH%%:*}"
REST="${MATCH#*:}"
LINE="${REST%%:*}"

echo "======================================================================"
echo " CKS study — $TODAY  ($FILE)"
echo "======================================================================"
cat "$FILE"
echo "----------------------------------------------------------------------"
echo "Task file: $REPO/$FILE"
if [[ "$FILE" == plan/* ]]; then
  echo "Answer (after you attempt it): $REPO/answers/${FILE#plan/}"
fi
