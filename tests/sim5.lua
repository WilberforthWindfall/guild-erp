-- 0.3 mit echten Daten: lua51 sim5.lua <GuildERP.lua> <GuildERP-SV> <FD-SV>
dofile((arg[0]:gsub("sim5%.lua$", "")) .. "stubs.lua")
GetItemInfo = nil
C_Item = { GetItemIconByID = function(id) return "icon" .. id end }
dofile(arg[2]); if arg[3] ~= "x" then dofile(arg[3]) end
PLAYER = { name = "Barlor", realm = "Classic Beta PvE", faction = "Alliance", class = "PALADIN", zone = "Eisenschmiede" }
local fach = {}
for id, n in pairs(GuildERPData.characters["Classic Beta PvE-Barlor"].bags) do table.insert(fach, { id, n }) end
CONTAINERS = { [0] = fach }
assert(loadfile(arg[1]))()
Fire("PLAYER_LOGIN"); RunTimers()
SlashCmdList.GUILDERP(""); RunTimers()
local f = GuildERPFenster
local L, R = f.links, f.rechts
local function zeige(t)
  realPrint("=== " .. t)
  realPrint("Handwerk-Knopf: " .. L.handwerk.text.text .. " | " .. L.handwerk.rechts.text .. " | Suche-Platzhalter: " .. L.suche.platzhalter.text)
  for _, k in ipairs(L.koepfe) do if k.benutzt then realPrint("  Gruppe: " .. k.text.text .. " [" .. k.rechts.text .. "]") end end
  local n = 0
  for _, z in ipairs(L.zeilen) do if z.benutzt then n = n + 1 end end
  realPrint("  Zeilen links: " .. n)
  realPrint("Karte: " .. R.karte.name.text .. " | wer=" .. R.auftrag.wer.text.text .. " menge=" .. R.auftrag.menge.text)
  if R.bereit.shown then realPrint("Bereit: " .. R.bereit.text.text .. " | " .. R.bereit.zaehler.tasche.text .. ", " .. R.bereit.zaehler.gruen.text .. ", " .. R.bereit.zaehler.gelb.text .. ", " .. R.bereit.zaehler.rot.text) end
  for _, z in ipairs(R.zeilen) do if z.benutzt then
    realPrint("  R: " .. z.name.text .. "  " .. z.zahl.text .. (z.glanz.shown and "  *LEUCHTET*" or "") .. (z.chip.shown and ("  [" .. z.chip.text.text .. "]") or "")
      .. (z.quelle.shown and ("\n       " .. z.quelle.text:gsub("\n", "\n       ")) or "") .. (z.herst.shown and ("\n       > " .. z.herst.text.text) or "")) end end
  realPrint("Kasten: " .. (R.hinweis.shown and (R.hinweis.text.text .. (R.hinweis.glanz.shown and "  (GRÜN, leuchtet)" or "")) or "-"))
end
zeige("Start")
-- Handwerk-Auswahl oeffnen
Click(L.handwerk); RunTimers()
for _, z in ipairs(GuildERPAuswahl.zeilen) do if z.shown then realPrint("  Popup: " .. z.text.text .. " | " .. z.rechts.text) end end
for _, z in ipairs(GuildERPAuswahl.zeilen) do if z.shown and z.text.text == "Schmiedekunst" then Click(z) end end
RunTimers()
-- graue Gruppe aufklappen
for _, k in ipairs(L.koepfe) do if k.benutzt and k.text.text:find("Noch nicht") then Click(k) end end
RunTimers(); zeige("Schmiedekunst, graue Gruppe offen")
for _, k in ipairs(L.koepfe) do if k.benutzt and k.text.text:find("Noch nicht") then Click(k) end end
-- Menge +5, dann anderes Rezept -> zurueck auf 1
Click(R.auftrag.plus5); Click(R.auftrag.plus); RunTimers()
realPrint("Menge nach +5 +1: " .. R.auftrag.menge.text)
Click(R.auftrag.minus5); RunTimers(); realPrint("Menge nach -5: " .. R.auftrag.menge.text)
Click(R.auftrag.minus5); RunTimers(); realPrint("Menge nach -5 (min 1): " .. R.auftrag.menge.text)
Click(R.auftrag.plus5); RunTimers()
for _, z in ipairs(L.zeilen) do if z.benutzt and z.name.text:find("Raue bronzene Gamaschen") then Click(z) end end
RunTimers(); zeige("Raue bronzene Gamaschen (6 Bronze, 35 in Tasche) - Menge zurueck auf 1?")
for _, z in ipairs(L.zeilen) do if z.benutzt and z.name.text:find("Kupferstreitaxt") then Click(z) end end
RunTimers(); zeige("Kupferstreitaxt")
-- Suche
L.suche:SetText("gürtel"); L.suche.scripts.OnTextChanged(L.suche); RunTimers()
zeige("Suche gürtel")
