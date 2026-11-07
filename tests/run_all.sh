#!/usr/bin/env bash
# Guild ERP – alle Simulationen ausfuehren (Lua 5.1 noetig, z. B. "sudo apt install lua5.1").
# Aufruf aus dem Repo-Ordner:  tests/run_all.sh        (oder LUA=/pfad/zu/lua5.1 tests/run_all.sh)
# Die Sims laden GuildERP/GuildERP.lua mit einer nachgebauten WoW-Schnittstelle (tests/stubs.lua)
# und echten gespeicherten Daten aus tests/fixtures/ (NICHT oeffentlich hochladen, siehe .gitignore).
cd "$(dirname "$0")" || exit 1
LUA="${LUA:-lua5.1}"
G=../GuildERP/GuildERP.lua
SV=fixtures/GuildERP_SV.lua
FD=fixtures/ForeverDashboard_SV.lua
if [ ! -f "$SV" ]; then echo "Fehlt: tests/$SV (Testdaten). Siehe tests/README.md"; exit 2; fi
fehler=0
lauf() { # name, args...
  local name=$1; shift
  local aus; aus=$("$LUA" "$name.lua" "$@" 2>&1); local code=$?
  if [ $code -ne 0 ] || echo "$aus" | grep -qiE 'traceback|attempt to|error'; then
    echo "FEHLER  $name"; echo "$aus" | grep -iE 'traceback|attempt to|error' | head -3; fehler=$((fehler+1))
  else
    echo "ok      $name"
  fi
}
for s in sim5 sim6 sim8 sim8b sim9; do lauf $s "$G" "$SV" "$FD"; done
for s in sim14 sim16 sim17; do lauf $s "$G" "$SV" x; done
for s in sim10 sim13 sim18 sim19 sim21 sim23 sim25; do lauf $s "$G" "$SV"; done
for s in sim15 sim22; do lauf $s "$G" "$SV" "$G"; done
lauf sim24 "$G"
lauf sim26 "$G"
lauf sim27 "$G" "$SV"
lauf sim20 "$G" "$SV" Herr
lauf sim20 "$G" "$SV" Barlor
echo "--- veraltet (Testannahmen passen nicht mehr zu den Testdaten, nur zur Info):"
for s in sim7 sim11 sim12 sim10r sim10v; do
  if "$LUA" "$s.lua" "$G" "$SV" >/dev/null 2>&1; then echo "ok      $s"; else echo "(alt)   $s"; fi
done
echo "Fehler: $fehler"
exit $fehler
