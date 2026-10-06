#!/usr/bin/env bash
# Applies the KDE/Plasma settings worth carrying between machines.
#
# Why a script instead of stowed rc files: KDE rewrites its rc files at runtime
# and interleaves real settings with machine-local state — monitor UUIDs,
# geo-coordinates, window geometry, "last used" paths and [$Version] migration
# stamps. Tracking those files meant ~1100 lines of churn around ~240 lines of
# intent, and a permanently dirty worktree. Setting only the keys we care about
# is declarative, diff-free and portable.
#
# Files still stowed as real config (stable, no runtime churn):
#   linux/.config/kdeglobals            colour scheme, fonts, widget style
#   linux/.config/kcminputrc            mouse accel profile, cursor theme
#   linux/.config/fontconfig/fonts.conf font rendering
set -euo pipefail

# Plasma 6 ships kwriteconfig6, Plasma 5 ships kwriteconfig5.
KWRITE=""
for c in kwriteconfig6 kwriteconfig5; do
  command -v "$c" >/dev/null && { KWRITE="$c"; break; }
done
if [ -z "$KWRITE" ]; then
  echo "==> KDE: no kwriteconfig found, skipping (not a Plasma system?)"
  exit 0
fi
echo "==> KDE settings via $KWRITE"

set_key() { # file group key value
  "$KWRITE" --file "$1" --group "$2" --key "$3" "$4"
}

# ── kwin: window manager ─────────────────────────────────────────────────────
# Night Color. Mode=Location lets Plasma geolocate rather than baking in the
# fixed latitude/longitude the rc file would otherwise persist.
set_key kwinrc NightColor Active true
set_key kwinrc NightColor Mode Location
set_key kwinrc NightColor NightTemperature 2900

# Gap between tiles. Per-monitor [Tiling][<uuid>] layouts are deliberately not
# set here — they accumulate one section per monitor arrangement ever attached.
set_key kwinrc Tiling padding 4

# Window decorations
set_key kwinrc org.kde.kdecoration2 library org.kde.kwin.aurorae
set_key kwinrc org.kde.kdecoration2 theme kwin4_decoration_qml_plastik

echo "    kwin configured (log out/in or 'qdbus org.kde.KWin /KWin reconfigure')"
