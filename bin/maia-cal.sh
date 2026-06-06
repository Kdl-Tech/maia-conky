#!/usr/bin/env bash
# Mini-calendrier du mois pour conky (jour courant surligne en ${color2}).
# Genere via Python (aucune dependance 'cal' requise).
python3 - << 'PY'
import calendar, datetime, locale, re
try:
    locale.setlocale(locale.LC_TIME, '')
except locale.Error:
    pass

t = datetime.date.today()
cal = calendar.LocaleTextCalendar(firstweekday=calendar.MONDAY)
raw = cal.formatmonth(t.year, t.month, w=2, l=1).rstrip("\n").split("\n")

# raw[0] = titre mois/annee ; raw[1] = entete jours ; raw[2:] = semaines
out = [raw[1]]
for wk in raw[2:]:
    wk = re.sub(r'(?<!\d)%d(?!\d)' % t.day,
                '${color2}%d${color4}' % t.day, wk)
    out.append(wk)
print("\n".join(out))
PY
