#!/usr/bin/env bash
# Maia conky — IP externe + pays + FAI (ip-api.com), avec cache pour limiter les requetes.
set -u

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/maia-conky"
CACHE="$CACHE_DIR/wan.json"
TTL=300
mkdir -p "$CACHE_DIR"

now="$(date +%s)"
age=999999
[ -f "$CACHE" ] && age=$(( now - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) ))

if [ "$age" -gt "$TTL" ] && command -v curl >/dev/null 2>&1; then
  tmp="$CACHE.tmp"
  if curl -fsSL --max-time 6 "http://ip-api.com/json/?fields=status,query,country,isp&lang=fr" -o "$tmp"; then
    if grep -q '"status":"success"' "$tmp" 2>/dev/null; then mv "$tmp" "$CACHE"; else rm -f "$tmp"; fi
  else
    rm -f "$tmp"
  fi
fi

if [ ! -s "$CACHE" ] || ! command -v jq >/dev/null 2>&1; then
  echo "N/A"; exit 0
fi

case "${1:-ip}" in
  ip)  jq -r '.query // "N/A"' "$CACHE" ;;
  geo) jq -r '((.country // "?") + " · " + (.isp // "?"))' "$CACHE" ;;
  *)   echo "N/A" ;;
esac
