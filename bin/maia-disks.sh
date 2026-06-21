#!/usr/bin/env bash
# Module disques pour Conky Maia.
# La sortie contient des variables Conky (${color...}, ${fs_bar}) :
# execpi les ré-interprète, donc on génère directement du markup Conky.
set -u

line() {
  local name="$1" dev="$2" model="$3"
  local mp size used total pct

  # parmi le device et ses partitions enfants, on garde le montage du
  # plus gros système de fichiers (évite d'attraper /boot/efi)
  local m best=0 bytes
  mp=""
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    bytes=$(df -B1 --output=size "$m" 2>/dev/null | tail -1 | tr -d ' ')
    [ -n "$bytes" ] || continue
    if [ "$bytes" -gt "$best" ]; then best=$bytes; mp=$m; fi
  done < <(lsblk -nro MOUNTPOINT "$dev" 2>/dev/null)
  size=$(lsblk -ndo SIZE "$dev" 2>/dev/null | tr -d ' ')

  if [ -n "$mp" ]; then
    used=$(df -h --output=used "$mp" 2>/dev/null | tail -1 | tr -d ' ')
    total=$(df -h --output=size "$mp" 2>/dev/null | tail -1 | tr -d ' ')
    pct=$(df  --output=pcent "$mp" 2>/dev/null | tail -1 | tr -d ' %')
    : "${pct:=0}"
    echo " \${color1}${name}\${color}\${color4}  ${model}\${color}\${alignr}\${color2}${used} / ${total}  ${pct}%\${color}"
    if   [ "$pct" -ge 90 ]; then echo "\${color3}\${fs_bar 8,360 ${mp}}\${color}"
    elif [ "$pct" -ge 70 ]; then echo "\${color2}\${fs_bar 8,360 ${mp}}\${color}"
    else                         echo "\${color1}\${fs_bar 8,360 ${mp}}\${color}"
    fi
  else
    echo " \${color1}${name}\${color}\${color4}  ${model}\${color}\${alignr}\${color4}${size} · non monte\${color}"
  fi
}

line "NVMe" /dev/nvme0n1   "PNY CS3030 1To"
line "SSD"  /dev/sdb       "Netac · maison"
line "HDD"  /dev/sda       "WD 3To"
