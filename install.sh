#!/usr/bin/env bash
# Installe le conky MAIA dans ~/.config/conky et ~/.local/bin
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
CONKY_DIR="$HOME/.config/conky"
BIN_DIR="$HOME/.local/bin"

echo "→ Installation MAIA Conky"
mkdir -p "$CONKY_DIR" "$BIN_DIR"

# 1. Conky + Lua (en ajustant le chemin lua_load au home courant)
sed "s#__HOME__#$HOME#g" "$SRC/conky/maia.conf" > "$CONKY_DIR/maia.conf"
cp "$SRC/conky/maia-rings.lua" "$CONKY_DIR/maia-rings.lua"

# 2. Scripts
cp "$SRC/bin/"*.sh "$BIN_DIR/"
chmod +x "$BIN_DIR/"maia-weather.sh "$BIN_DIR/"maia-wan.sh "$BIN_DIR/"maia-cal.sh

echo "✓ Fichiers installés."

# 3. Dépendances manquantes ?
for c in conky jq curl python3; do
  command -v "$c" >/dev/null 2>&1 || echo "  ⚠ '$c' manquant — installe-le (voir README)."
done
command -v sensors >/dev/null 2>&1 || echo "  ⚠ 'lm-sensors' manquant — températures indisponibles."

# 4. Autostart (optionnel)
read -rp "Lancer au démarrage de session ? [o/N] " a
if [[ "${a,,}" == "o" ]]; then
  mkdir -p "$HOME/.config/autostart"
  cat > "$HOME/.config/autostart/maia-conky.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Maia Conky
Exec=conky -c $CONKY_DIR/maia.conf
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=8
Terminal=false
EOF
  echo "✓ Autostart activé."
fi

# 5. Lancer maintenant
pkill -x conky 2>/dev/null || true
sleep 1
(setsid conky -c "$CONKY_DIR/maia.conf" >/dev/null 2>&1 < /dev/null &)
echo "✓ Conky lancé. Bon rice ! 🛰️"
