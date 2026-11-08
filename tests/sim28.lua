-- 1.6.1 Bestellung absagen mit Grund, grosse Rezept-/Gegenstandsnummern (ueber 100000)
-- lua51 sim28.lua <GuildERP.lua> <GuildERP-SV von Barlor>
dofile((arg[0]:gsub("sim28%.lua$", "")) .. "stubs.lua")
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
local fehler = 0
local function pruefe(ok, text)
  if ok then realPrint("  ok: " .. text) else fehler = fehler + 1; realPrint("  FALSCH: " .. text) end
end
local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " / ")) end

-- Bestellung von Barlor an die Gruppe: Rezept mit grosser Nummer
svBarlor.orders = svBarlor.orders or {}
svBarlor.orders["Barlor-1-1"] = { id = "Barlor-1-1", von = "Barlor", an = "", fuer = "Test", notiz = "", at = 1000,
  kopfRev = 1000, status = "offen", zeilen = { { itemID = 200001, rezeptID = 250000, n = 9, zusagen = {} } } }
local barlor = neueInstanz("Barlor", svBarlor, {})
local pudel = neueInstanz("Zwerg Pudel", nil, {})
fire(barlor, "PLAYER_LOGIN"); fire(pudel, "PLAYER_LOGIN"); RunTimers()
inGruppe = true
fire(barlor, "GROUP_ROSTER_UPDATE"); fire(pudel, "GROUP_ROSTER_UPDATE"); RunTimers()
local po = pudel.env.GuildERPData.orders and pudel.env.GuildERPData.orders["Barlor-1-1"]
pruefe(po ~= nil, "Pudel hat die Bestellung")
pruefe(po and po.zeilen[1].rezeptID == 250000, "Rezeptnummer 250000 bleibt ganz (" .. tostring(po and po.zeilen[1].rezeptID) .. ")")
pruefe(po and po.zeilen[1].itemID == 200001, "Gegenstandsnummer 200001 bleibt ganz")

-- Pudel sagt ab (ueber das Fenster)
pudel.env.SlashCmdList.GUILDERP(""); RunTimers()
local pf = pudel.env.GuildERPFenster
Click(pf.reiterBest); RunTimers()
local schein
for _, s in ipairs(pf.best.spalten[1].scheine) do if s.benutzt and s.shown then schein = s end end
pruefe(schein and schein.k2.shown and schein.k2.text == "Absagen", "Knopf Absagen sichtbar")
Click(schein.k2); RunTimers()
local ab = pudel.env.GuildERPAbsage
pruefe(ab and ab.shown, "Absage-Fenster offen")
Click(ab.wahl); RunTimers()
local eigen
for _, z in ipairs(pudel.env.GuildERPAuswahl.zeilen) do if z.shown and z.text.text == "Eigener Grund …" then eigen = z end end
Click(eigen); RunTimers()
pruefe(ab.eigen.shown, "Feld fuer eigenen Grund sichtbar")
ab.eigen:SetText("Bin heute nicht online")
Click(ab.ok); RunTimers()
local zb = svBarlor.orders["Barlor-1-1"].zeilen[1]
local gefunden
for wer, s in pairs(zb.zusagen) do if s.ab then gefunden = s.ab end end
pruefe(gefunden == "Bin heute nicht online", "Barlor sieht den Grund: " .. tostring(gefunden))
local leer = true
for _, s in ipairs(pf.best.spalten[1].scheine) do if s.benutzt and s.shown and strip(s.unter.text):find("für Test", 1, true) then leer = false end end
pruefe(leer, "Bei Pudel ist die Bestellung aus der Liste")

barlor.env.SlashCmdList.GUILDERP(""); RunTimers()
local bf = barlor.env.GuildERPFenster
Click(bf.reiterBest); RunTimers()
local text
for _, s in ipairs(bf.best.spalten[2].scheine) do if s.benutzt and s.shown then
  text = strip(s.zeilen[1].zusatz.text) .. " | " .. strip(s.zeilen[1].chip.text) end end
realPrint("  Barlor: " .. tostring(text))
pruefe(text and text:find("abgesagt: „Bin heute nicht online“", 1, true) and text:find("| abgesagt", 1, true), "Barlor-Anzeige mit Grund und Chip")
-- Skill-Farben im Rezeptbuch
svBarlor = barlor.env.GuildERPData
local c = svBarlor.characters["Classic Beta PvE-Barlor"]
local rid, beruf
for b, ids in pairs(c.recipes or {}) do for id in pairs(ids) do
  if svBarlor.recipes[id] and svBarlor.recipes[id].reagents then rid, beruf = id, b end end end
c.stufen = { [rid] = 0 }
svBarlor.settings.ansicht = "werk"; svBarlor.settings.wunsch = rid; svBarlor.settings.beruf = beruf
svBarlor.settings.zu = {}
barlor.env.SlashCmdList.GUILDERP(""); barlor.env.SlashCmdList.GUILDERP(""); RunTimers()
Click(bf.reiterWerk); RunTimers()
local farbe
for _, z in ipairs(bf.links.zeilen) do if z.shown and strip(z.name.text) == svBarlor.recipes[rid].name then farbe = z.name.text; realPrint("  Tip: " .. strip(z.tip)) end end
pruefe(farbe and farbe:find("ff8040", 1, true), "Rezept orange (" .. tostring(farbe) .. ")")
realPrint("Fehler: " .. fehler)
if fehler > 0 then os.exit(1) end
