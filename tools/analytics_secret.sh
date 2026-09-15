#!/usr/bin/env bash
# Install the GA4 Measurement Protocol secret in the two places that need it,
# then prove the wiring by sending one event.
#
#   tools/analytics_secret.sh <api-secret>
#
# The secret comes from GA4 Admin -> Data streams -> the com.peeplet.daily
# stream -> Measurement Protocol API secrets -> Create. It only exists once
# Google Analytics is linked to the Firebase project, which is a console step.
set -euo pipefail

secret="${1:-}"
if [[ -z "$secret" ]]; then
	echo "usage: tools/analytics_secret.sh <api-secret>" >&2
	exit 2
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

# What the game reads: untracked, packed into the APK by the export preset.
printf '[analytics]\napi_secret="%s"\n' "$secret" > analytics_secret.cfg
echo "wrote analytics_secret.cfg"

# What CI reads, so builds off main report too.
if command -v gh >/dev/null 2>&1; then
	printf '%s' "$secret" | gh secret set ANALYTICS_API_SECRET --repo flavioriper/daily-games
else
	echo "gh not found: set the ANALYTICS_API_SECRET repo secret by hand" >&2
fi

# One live event, tagged for DebugView. The endpoint answers 204 either way,
# so watch GA4 Admin -> DebugView to see it arrive; that is the only proof
# that the secret itself is good.
"${GODOT:-godot}" --headless --path . --script tools/_analytics_ping.gd
echo
echo "now open GA4 -> Admin -> DebugView and look for game_open"
