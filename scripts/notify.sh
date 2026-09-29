#!/bin/bash
# Fires a macOS notification with today's CKS study topic. Run by launchd daily.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

TODAY="$(date +"%b %e" | tr -s ' ')"
TODAY_ISO="$(date +%F)"
START_ISO="2026-09-22"
END_ISO="2026-11-15"

if [[ "$TODAY_ISO" < "$START_ISO" || "$TODAY_ISO" > "$END_ISO" ]]; then
  exit 0
fi

MATCH="$(grep -rn --include='day-*.md' "^#\+.*($TODAY)" plan 2>/dev/null | head -1 || true)"
[[ -z "$MATCH" ]] && MATCH="$(grep -n "^#\+.*($TODAY)" SETUP.md 2>/dev/null | sed 's/^/SETUP.md:/' | head -1 || true)"
[[ -z "$MATCH" ]] && exit 0

HEADING="$(echo "$MATCH" | sed -E 's/^[^:]+:[0-9]+:#+ *//')"

/usr/bin/osascript -e "display notification \"Open Terminal and run: cks-today\" with title \"CKS Study — $TODAY\" subtitle \"$(echo "$HEADING" | sed 's/"/\\"/g')\""
