#!/usr/bin/env bash
set -u

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/maia-conky"
CACHE_FILE="$CACHE_DIR/weather.json"
OUT_FILE="$CACHE_DIR/weather.txt"
TTL_SECONDS=600
LOCATION="${MAIA_WEATHER_LOCATION:-}"

mkdir -p "$CACHE_DIR"

now="$(date +%s)"
cache_age=999999
if [ -f "$CACHE_FILE" ]; then
  mtime="$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)"
  cache_age=$((now - mtime))
fi

if [ "$cache_age" -gt "$TTL_SECONDS" ] && command -v curl >/dev/null 2>&1; then
  if [ -n "$LOCATION" ]; then
    url="https://wttr.in/${LOCATION}?format=j1&lang=fr"
  else
    url="https://wttr.in/?format=j1&lang=fr"
  fi

  tmp="$CACHE_FILE.tmp"
  if curl -fsSL --max-time 6 "$url" -o "$tmp"; then
    mv "$tmp" "$CACHE_FILE"
  else
    rm -f "$tmp"
  fi
fi

if [ ! -s "$CACHE_FILE" ] || ! command -v jq >/dev/null 2>&1; then
  printf 'Meteo: indisponible\n'
  exit 0
fi

jq -r '
  def safe(x): if x == null or x == "" then "?" else x end;
  .current_condition[0] as $c
  | .nearest_area[0] as $a
  | .weather[0] as $d
  | [
      ("Meteo " + safe($a.areaName[0].value)),
      (safe($c.lang_fr[0].value // $c.weatherDesc[0].value) + "  " + safe($c.temp_C) + "C  ressenti " + safe($c.FeelsLikeC) + "C"),
      ("Vent " + safe($c.windspeedKmph) + " km/h  Humidite " + safe($c.humidity) + "%"),
      ("Pluie " + safe($c.precipMM) + " mm  Pression " + safe($c.pressure) + " hPa"),
      ("UV " + safe($c.uvIndex) + "  Visibilite " + safe($c.visibility) + " km"),
      ("Min/Max " + safe($d.mintempC) + "C / " + safe($d.maxtempC) + "C")
    ]
  | .[]' "$CACHE_FILE" > "$OUT_FILE" 2>/dev/null || printf 'Meteo: erreur donnees\n' > "$OUT_FILE"

cat "$OUT_FILE"
