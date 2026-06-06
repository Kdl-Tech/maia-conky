#!/usr/bin/env bash
# ============================================================================
#  install-desktop.sh — Harmonise le bureau Cinnamon avec le thème Conky MAIA
#    - Panneau (barre) : fond sombre semi-transparent + liseré cyan
#    - Bouton menu      : icône anneau néon cyan
#    - Dossiers Papirus : recoloriés en cyan
#
#  Couleurs de référence (cf. conky/maia.conf) :
#    fond #060B0E · accent cyan #00E5FF · vert #00FF99
#
#  Sûr & réversible : crée un backup horodaté, ne modifie aucun thème système
#  (fork dans ~/.themes et ~/.local/share/icons). Idempotent.
# ============================================================================
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"
BK="$HOME/backups/maia-desktop-$TS"

CYAN="#00e5ff"
PANEL_BG="rgba(6, 11, 14, 0.86)"
HOVER_BG="rgba(0, 229, 255, 0.22)"

PANEL_SRC_THEME="/usr/share/themes/Mint-Y-Dark-Aqua"
PANEL_DST_THEME="$HOME/.themes/Maia-Aqua"
ICON_BASE="/usr/share/icons/Papirus"
ICON_DST="$HOME/.local/share/icons/Papirus-Maia"
MENU_ICON_DIR="$HOME/.local/share/icons/maia"
MENU_JSON="$HOME/.config/cinnamon/spices/menu@cinnamon.org/0.json"

echo "→ Harmonisation bureau MAIA (backup : $BK)"
mkdir -p "$BK"

# ---------------------------------------------------------------------------
# 0. Backup de l'existant
# ---------------------------------------------------------------------------
[ -d "$PANEL_DST_THEME" ] && cp -a "$PANEL_DST_THEME" "$BK/Maia-Aqua.before" || true
[ -d "$ICON_DST" ]        && cp -a "$ICON_DST" "$BK/Papirus-Maia.before"   || true
[ -f "$MENU_JSON" ]       && cp -a "$MENU_JSON" "$BK/menu-0.json.before"    || true
{ echo "theme=$(gsettings get org.cinnamon.theme name 2>/dev/null)"
  echo "icons=$(gsettings get org.cinnamon.desktop.interface icon-theme 2>/dev/null)"
} > "$BK/gsettings.before" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 1. Thème de panneau Maia-Aqua (fork de Mint-Y-Dark-Aqua + overrides cascade)
# ---------------------------------------------------------------------------
if [ -d "$PANEL_SRC_THEME" ]; then
  echo "  • Panneau → thème Maia-Aqua"
  rm -rf "$PANEL_DST_THEME"
  cp -a "$PANEL_SRC_THEME" "$PANEL_DST_THEME"
  [ -f "$PANEL_DST_THEME/index.theme" ] && sed -i 's/^Name=.*/Name=Maia-Aqua/' "$PANEL_DST_THEME/index.theme" || true
  # Overrides ajoutés en fin de feuille (le dernier gagne dans la cascade St)
  cat >> "$PANEL_DST_THEME/cinnamon/cinnamon.css" <<CSS

/* ==== MAIA — harmonisation avec le thème Conky ==== */
.panel-top, .panel-bottom, .panel-left, .panel-right { background-color: $PANEL_BG; }
.panel-bottom { box-shadow: 0 -2px $CYAN; }
.panel-top    { box-shadow: 0 2px $CYAN; }
.applet-box:hover, .applet-box:checked { background-color: $HOVER_BG; color: #ffffff; }
CSS
else
  echo "  ⚠ $PANEL_SRC_THEME introuvable — installe le thème 'Mint-Y-Dark-Aqua' (paquet mint-themes)."
fi

# ---------------------------------------------------------------------------
# 2. Dossiers cyan — overlay Papirus-Maia (hérite de Papirus-Dark)
# ---------------------------------------------------------------------------
if [ -d "$ICON_BASE" ]; then
  echo "  • Dossiers → overlay Papirus-Maia (cyan)"
  SIZES="16x16 22x22 24x24 32x32 48x48 64x64"
  rm -rf "$ICON_DST"; mkdir -p "$ICON_DST"
  {
    echo "[Icon Theme]"
    echo "Name=Papirus-Maia"
    echo "Comment=Papirus-Dark, dossiers cyan (harmonise Conky MAIA)"
    echo "Inherits=Papirus-Dark,Papirus,hicolor"
    dirs=""; for s in $SIZES; do dirs="$dirs$s/places,"; done
    echo "Directories=${dirs%,}"; echo ""
    for s in $SIZES; do
      echo "[$s/places]"; echo "Context=Places"; echo "Size=${s%x*}"; echo "Type=Fixed"; echo ""
    done
  } > "$ICON_DST/index.theme"
  n=0
  for s in $SIZES; do
    bdir="$ICON_BASE/$s/places"; odir="$ICON_DST/$s/places"; mkdir -p "$odir"
    [ -d "$bdir" ] || continue
    for f in "$bdir"/folder*.svg "$bdir"/user-*.svg; do
      [ -e "$f" ] || continue
      t="$(readlink "$f" 2>/dev/null || true)"
      case "$t" in
        *blue*) cyan="${t//blue/cyan}"
                [ -e "$bdir/$cyan" ] && { ln -s "$bdir/$cyan" "$odir/$(basename "$f")"; n=$((n+1)); } ;;
      esac
    done
  done
  echo "    $n dossiers repointés en cyan"
  command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f "$ICON_DST" 2>/dev/null || true
else
  echo "  ⚠ $ICON_BASE introuvable — installe 'papirus-icon-theme'."
fi

# ---------------------------------------------------------------------------
# 3. Icône du bouton menu (anneau cyan)
# ---------------------------------------------------------------------------
echo "  • Bouton menu → anneau cyan"
mkdir -p "$MENU_ICON_DIR"
cp "$SRC/icons/maia-menu-ring.svg" "$MENU_ICON_DIR/maia-menu-ring.svg"
if [ -f "$MENU_JSON" ] && command -v python3 >/dev/null; then
  python3 - "$MENU_JSON" "$MENU_ICON_DIR/maia-menu-ring.svg" <<'PY'
import json, sys
p, icon = sys.argv[1], sys.argv[2]
d = json.load(open(p))
for k, v in (("menu-custom", True), ("menu-icon", icon), ("menu-icon-size", 28), ("menu-label", "")):
    if k in d and isinstance(d[k], dict):
        d[k]["value"] = v
json.dump(d, open(p, "w"), indent=4)
PY
else
  echo "    (applet menu non trouvé — règle l'icône à la main : $MENU_ICON_DIR/maia-menu-ring.svg)"
fi

# ---------------------------------------------------------------------------
# 4. Application
# ---------------------------------------------------------------------------
[ -d "$PANEL_DST_THEME" ] && gsettings set org.cinnamon.theme name 'Maia-Aqua' || true
[ -d "$ICON_DST" ]        && gsettings set org.cinnamon.desktop.interface icon-theme 'Papirus-Maia' || true

echo "✓ Bureau harmonisé. Recharge Cinnamon pour tout voir :  cinnamon --replace &"
echo "  Backup / restauration : $BK"
