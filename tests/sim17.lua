-- 0.3 mit echten Daten: lua51 sim5.lua <GuildERP.lua> <GuildERP-SV> <FD-SV>
dofile((arg[0]:gsub("sim17%.lua$", "")) .. "stubs.lua")
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
local ATL = {}
C_Texture = { GetAtlasInfo = function(n) if n == "common-button-list-plus" then return nil end return { name = n } end }
local f = GuildERPFenster
local d = GuildERPData
d.settings.ansicht = "werk"; SlashCmdList.GUILDERP(""); SlashCmdList.GUILDERP(""); RunTimers()
local function stand(t)
  local n = 0 for _, b in ipairs(f.seiten or {}) do if b.shown then n = n + 1 end end
  local gk = 0 for _, k in ipairs(f.links.gkoepfe or {}) do if k.benutzt and k.spielAn then gk = gk + 1 end end
  realPrint(t .. ": rahmen=" .. tostring(f.spielRahmen and f.spielRahmen.shown) .. " portrait=" .. tostring(f.portrait and f.portrait.shown)
    .. " seiten=" .. n .. " titel=" .. tostring(f.titel.shown) .. " h=" .. tostring(f.h) .. " gruppenkoepfe(spiel)=" .. gk
    .. " karte=" .. tostring(f.rechts.spielKarte and f.rechts.spielKarte.shown) .. " suche=" .. tostring(f.links.suche.spielM and f.links.suche.spielM.shown)
    .. " fehler=" .. tostring(d.diagnostics.lookFehler))
end
stand("vorher")
SlashCmdList.GUILDERP("optionen"); RunTimers()
local OF = GuildERPOptionen
Click(OF.zeilen[1]); RunTimers()
for _, z in ipairs(GuildERPAuswahl.zeilen) do if z.shown and z.text.text == "Spiel-Look" then Click(z) end end
RunTimers(); stand("Spiel-Look")
for _, b in ipairs(f.seiten) do realPrint("  Seite " .. b.wert .. " gewählt=" .. tostring(b.wahl.shown) .. " zahl='" .. tostring(b.zahl.text) .. "'") end
Click(f.seiten[4]); RunTimers(); realPrint("  nach Klick Katalog: ansicht=" .. d.settings.ansicht .. " kartekat=" .. tostring(f.kat.rechts.spielKarte and f.kat.rechts.spielKarte.shown))
for _, k in ipairs(f.kat.links.koepfe) do if k.benutzt then realPrint("  Kat-Kopf spielAn=" .. tostring(k.spielAn) .. " pfeil=" .. tostring(k.pfeil.texture)) break end end
Click(f.seiten[1]); RunTimers()
Click(OF.zeilen[1]); RunTimers()
for _, z in ipairs(GuildERPAuswahl.zeilen) do if z.shown and z.text.text == "Guild ERP (dunkel)" then Click(z) end end
RunTimers(); stand("zurück")
Click(OF.zeilen[1]); RunTimers()
for _, z in ipairs(GuildERPAuswahl.zeilen) do if z.shown and z.text.text == "Spiel-Look" then Click(z) end end
RunTimers()
realPrint("gkoepfe=" .. #(f.links.gkoepfe or {}) .. " koepfe=" .. #f.links.koepfe)
for _, k in ipairs(f.links.gkoepfe or {}) do realPrint("  g " .. tostring(k.text.text) .. " benutzt=" .. tostring(k.benutzt) .. " spielAn=" .. tostring(k.spielAn)) end
for _, k in ipairs(f.links.koepfe) do realPrint("  k " .. tostring(k.text.text) .. " spielAn=" .. tostring(k.spielAn)) end
