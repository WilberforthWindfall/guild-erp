-- Zwei Spieler (Barlor, Zwerg Pudel), je eigene Add-on-Instanz und eigene gespeicherte Daten.
-- lua51 sim7.lua <GuildERP.lua> <GuildERP-SV von Barlor>
dofile((arg[0]:gsub("sim7%.lua$", "")) .. "stubs.lua")
GetItemInfo = nil
C_Item = { GetItemIconByID = function(id) return "icon" .. id end }
dofile(arg[2])
local svBarlor = GuildERPData
GuildERPData = nil

local inst = {}
local inGruppe = false
local function neueInstanz(name, sv, taschen)
    local env = setmetatable({}, { __index = _G })
    env.GuildERPData = sv
    env.SlashCmdList = {}
    env.UISpecialFrames = {}
    env.UnitName = function(u)
        if u == "player" then return name end
        if u == "party1" then return name == "Barlor" and "Zwerg Pudel" or "Barlor" end
    end
    env.GetRealmName = function() return "Classic Beta PvE" end
    env.UnitFactionGroup = function() return "Alliance" end
    env.IsInGroup = function() return inGruppe end
    env.IsInRaid = function() return false end
    env.GetNumGroupMembers = function() return inGruppe and 1 or 0 end
    env.Ambiguate = function(n) return n end
    env.C_Container = {
        GetContainerNumSlots = function(b) return b == 0 and #taschen or 0 end,
        GetContainerItemInfo = function(b, s) local e = taschen[s]; if b == 0 and e then return { itemID = e[1], stackCount = e[2] } end end,
    }
    local erster
    env.CreateFrame = function(...)
        local fr = CreateFrame(...)
        local _, nm = ...
        if nm then env[nm] = fr end
        erster = erster or fr
        return fr
    end
    env.print = function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end realPrint("  [" .. name .. "] " .. table.concat(t, " ")) end
    env.C_ChatInfo = {
        RegisterAddonMessagePrefix = function() return true end,
        SendAddonMessage = function(prefix, text, kanal)
            assert(#text <= 255, "Nachricht zu lang: " .. #text)
            for _, andere in ipairs(inst) do
                if andere.name ~= name and inGruppe then
                    andere.frame.scripts.OnEvent(andere.frame, "CHAT_MSG_ADDON", prefix, text, kanal, name)
                end
            end
            return 0
        end,
    }
    local chunk = assert(loadfile(arg[1]))
    setfenv(chunk, env)
    chunk()
    local i = { name = name, env = env, frame = erster }
    table.insert(inst, i)
    return i
end
local function fire(i, ev, ...) i.frame.scripts.OnEvent(i.frame, ev, ...) end

local fach = {}
for id, n in pairs(svBarlor.characters["Classic Beta PvE-Barlor"].bags) do table.insert(fach, { id, n }) end
local barlor = neueInstanz("Barlor", svBarlor, fach)
-- Pudel hat Schwachen Fluxus (3466) und Rauen Stein (2835) dabei
local pudel = neueInstanz("Zwerg Pudel", nil, { { 2880, 5 }, { 2835, 10 } })
fire(barlor, "PLAYER_LOGIN"); fire(pudel, "PLAYER_LOGIN"); RunTimers()

-- Barlor: Kupferstreitaxt waehlen, "Fehlendes bestellen" (noch NICHT in einer Gruppe)
barlor.env.SlashCmdList.GUILDERP(""); RunTimers()
local f = barlor.env.GuildERPFenster
local d = barlor.env.GuildERPData
for id, r in pairs(d.recipes) do if r.name == "Kupferstreitaxt" then d.settings.wunsch = id end end
d.settings.menge = 1
barlor.env.SlashCmdList.GUILDERP(""); barlor.env.SlashCmdList.GUILDERP(""); RunTimers()
local h = f.rechts.hinweis
realPrint("Kasten: " .. h.text.text:gsub("\n", " / ") .. " | Knopf: " .. h.knopf.text .. " " .. tostring(h.knopf.shown))
Click(h.knopf); RunTimers()
local s = barlor.env.GuildERPBestellschein
for i, z in ipairs(s.zeilen) do if z.shown then realPrint(string.format("  Schein %d: [%s] %s x%s - %s", i, z.haken.checked and "x" or " ", z.name.text, z.menge.text, z.hinweis.text)) end end
realPrint("  " .. s.zaehler.text .. " | an: " .. s.an.text.text)
-- eine Zeile abwaehlen (Zeile 1), Menge Zeile 2 +1, Notiz, senden
s.zeilen[1].haken.checked = false; s.zeilen[1].haken.scripts.OnClick(s.zeilen[1].haken)
Click(s.zeilen[2].plus)
s.notiz:SetText("Bis heute Abend?")
realPrint("  nach Abwählen: " .. s.zaehler.text)
Click(s.senden); RunTimers()
realPrint("Ansicht jetzt: " .. tostring(d.settings.ansicht))
local sp2 = f.best.spalten[2]
for _, sch in ipairs(sp2.scheine) do if sch.benutzt then
  realPrint("  Barlor sieht: " .. sch.titel.text .. " / " .. sch.unter.text)
  for _, r in ipairs(sch.zeilen) do if r.shown then realPrint("     " .. r.text.text .. " | " .. r.chip.text .. " | " .. r.zusatz.text) end end
  realPrint("     Fuß: " .. sch.fuss.text)
end end

-- Jetzt Gruppe bilden: Abgleich
realPrint("=== Gruppe gebildet")
inGruppe = true
fire(barlor, "GROUP_ROSTER_UPDATE"); fire(pudel, "GROUP_ROSTER_UPDATE"); RunTimers()

-- Pudel oeffnet Bestellungen
pudel.env.SlashCmdList.GUILDERP(""); RunTimers()
local pf = pudel.env.GuildERPFenster
realPrint("Pudel Reiter: " .. pf.reiterBest.text.text)
Click(pf.reiterBest); RunTimers()
local sp1 = pf.best.spalten[1]
local lieferKnopf
for _, sch in ipairs(sp1.scheine) do if sch.benutzt then
  realPrint("  Pudel sieht: " .. sch.titel.text .. " / " .. sch.unter.text .. " | Notiz: " .. sch.fuss.text)
  for _, r in ipairs(sch.zeilen) do if r.shown then
    realPrint("     " .. r.text.text .. " | " .. r.chip.text .. " | " .. r.zusatz.text .. (r.k1.shown and (" [" .. r.k1.text .. "]") or ""))
    if r.k1.shown and not lieferKnopf and r.text.text:find("^4") then lieferKnopf = r.k1 end
  end end
end end
-- Zusage: Fluxus, Per Post
Click(lieferKnopf); RunTimers()
local zs = pudel.env.GuildERPZusage
realPrint("  Zusage-Fenster: " .. zs.frage.text .. " Menge " .. zs.menge.text .. " " .. zs.von.text .. ", Weg " .. zs.weg.text.text)
Click(zs.weg); RunTimers()
for _, z in ipairs(pudel.env.GuildERPAuswahl.zeilen) do if z.shown and z.text.text == "Per Post" then Click(z) end end
realPrint("  Weg jetzt: " .. zs.weg.text.text)
Click(zs.senden); RunTimers()
-- Pudel markiert geliefert
Click(pf.reiterBest); RunTimers()
for _, sch in ipairs(sp1.scheine) do if sch.benutzt then for _, r in ipairs(sch.zeilen) do if r.shown and r.text.text:find("^4") then
  realPrint("  Pudel nach Zusage: " .. r.zusatz.text .. " [" .. (r.k2.shown and r.k2.text or "-") .. "]")
  Click(r.k2)
end end end end
RunTimers()
realPrint("=== Barlor danach")
Click(f.reiterBest); RunTimers()
for _, sch in ipairs(sp2.scheine) do if sch.benutzt then
  for _, r in ipairs(sch.zeilen) do if r.shown then realPrint("     " .. r.text.text .. " | " .. r.chip.text .. " | " .. r.zusatz.text) end end
  realPrint("     Fuß: " .. sch.fuss.text)
  Click(sch.k1) -- Abschliessen
end end
RunTimers()
for _, o in pairs(pudel.env.GuildERPData.orders) do realPrint("  Pudel sieht Status: " .. o.status) end
Click(pf.reiterBest); RunTimers(); realPrint("  Pudel Reiter: " .. pf.reiterBest.text.text .. " | leer: " .. pf.best.spalten[1].leer.text)
