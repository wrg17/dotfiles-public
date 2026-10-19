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

# ── kdeglobals: theme and colours ────────────────────────────────────────────
#
# kdeglobals used to be stowed, and it was the one remaining churning rc file:
# ~/.config/kdeglobals was a symlink into this repo, so Plasma wrote dialog
# geometry ([DirSelect Dialog]) and file-picker state ([KFileDialog Settings],
# 20 lines of sort order and speedbar width) directly into the git worktree,
# producing a dirty tree every session.
#
# The 134 lines of colour data in it turned out to be a verbatim copy of the
# system BreezeDark scheme — the only differences were two empty-valued keys
# Plasma had written out. So there was no custom scheme to preserve, and the
# whole file reduces to the three keys below plus a scheme name.

set_key kdeglobals Icons Theme Yaru-magenta
set_key kdeglobals KDE LookAndFeelPackage org.kde.breezedark.desktop
set_key kdeglobals KDE widgetStyle Oxygen

# Applied last and via plasma-apply-colorscheme rather than set_key, because the
# colour scheme is ~134 keys across 11 groups: the tool expands the named scheme
# from /usr/share/color-schemes into kdeglobals and recomputes the
# ColorSchemeHash that Plasma uses to detect manual edits. Setting the keys by
# hand would reproduce the exact file this change just stopped tracking.
#
# Deliberately not plasma-apply-lookandfeel: applying the whole look-and-feel
# package resets widget style, icons and panel layout as a side effect, which
# would clobber the keys set above.
if command -v plasma-apply-colorscheme >/dev/null; then
  # Writes to ~/.config/kdeglobals, which is a real local file now — not a
  # symlink into the repo. That is the entire point of the change.
  plasma-apply-colorscheme BreezeDark >/dev/null 2>&1 ||
    echo "    WARN: could not apply BreezeDark colour scheme"
  echo "    kdeglobals: BreezeDark + Oxygen widgets + Yaru-magenta icons"
else
  echo "    plasma-apply-colorscheme not found — colour scheme left as-is"
fi
