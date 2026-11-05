-- Zwei Spieler (Barlor, Zwerg Pudel), je eigene Add-on-Instanz und eigene gespeicherte Daten.
-- lua51 sim10.lua <GuildERP.lua neu> <SV Barlor> <GuildERP.lua fuer Pudel>
dofile((arg[0]:gsub("sim15%.lua$", "")) .. "stubs.lua")
GetItemInfo = nil
C_Item = { GetItemIconByID = function(id) return "icon" .. id end }
dofile(arg[2])
local svBarlor = GuildERPData
GuildERPData = nil

local inst = {}
local inGruppe = false
local function neueInstanz(name, sv, taschen, datei)
    local env = setmetatable({}, { __index = _G })
    env.GuildERPData = sv
    env.SlashCmdList = {}
    env.UISpecialFrames = {}
    env.UnitName = function(u)
        if u == "player" then return name end
        if u == "party1" then return name == "Barlor" and "Zwerg" or "Barlor" end
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
            local art = text:sub(1, 1)
            ZAEHL[name .. ":" .. art] = (ZAEHL[name .. ":" .. art] or 0) + 1
            for _, andere in ipairs(inst) do
                if inGruppe then
                    andere.frame.scripts.OnEvent(andere.frame, "CHAT_MSG_ADDON", prefix, text, kanal, name .. (name == "Barlor" and " Rostbart" or " Pudelmuetze") .. "-ClassicBetaPvE")
                end
            end
            return 0
        end,
    }
    local chunk = assert(loadfile(datei or arg[1]))
    setfenv(chunk, env)
    chunk()
    local i = { name = name, env = env, frame = erster }
    table.insert(inst, i)
    return i
end
local function fire(i, ev, ...) i.frame.scripts.OnEvent(i.frame, ev, ...) end


ZAEHL = {}
Minimap = CreateFrame("Frame", "Minimap")
C_Spell = { GetSpellName = function(id) return ({ [7457] = "Armschiene - Geringe Ausdauer", [7418] = "Armschiene - Geringe Gesundheit", [7771] = "Umhang - Geringer Schutz" })[id] end }
local fach = {}
for id, n in pairs(svBarlor.characters["Classic Beta PvE-Barlor"].bags) do table.insert(fach, { id, n }) end
local barlor = neueInstanz("Barlor", svBarlor, fach)
local svPudel = { characters = { ["Classic Beta PvE-Zwerg"] = { name = "Zwerg", faction = "Alliance",
    recipes = { ["Verzauberkunst"] = { [7457] = true, [7418] = true }, ["Schneiderei"] = { [2387] = true } } } },
  recipes = { [7457] = { name = "Armschiene - Geringe Ausdauer", profession = "Verzauberkunst", reagents = { { itemID = 10940, count = 2 }, { itemID = 10938, count = 1 } } },
              [7418] = { name = "Armschiene - Geringe Gesundheit", profession = "Verzauberkunst", reagents = { { itemID = 10940, count = 1 } } },
              [2387] = { name = "Leinenhemd", kategorie = "Hemden", profession = "Schneiderei", itemID = 2576, reagents = { { itemID = 2996, count = 1 } } } } }
local pudel = neueInstanz("Zwerg", svPudel, { { 10940, 3 } }, arg[3])
fire(barlor, "PLAYER_LOGIN"); fire(pudel, "PLAYER_LOGIN"); RunTimers()
-- Barlor bestellt offline etwas
barlor.env.SlashCmdList.GUILDERP(""); RunTimers()
local f = barlor.env.GuildERPFenster
local d = barlor.env.GuildERPData
for id, r in pairs(d.recipes) do if r.name == "Kupferstreitaxt" then d.settings.wunsch = id end end
d.settings.menge = 1; d.settings.ansicht = "werk"
barlor.env.SlashCmdList.GUILDERP(""); barlor.env.SlashCmdList.GUILDERP(""); RunTimers()
Click(f.rechts.hinweis.knopf); RunTimers(); Click(barlor.env.GuildERPBestellschein.senden); RunTimers()
-- Zwerg oeffnet ihr Berufefenster (Spiel liefert Gruppen)
KATS = { [11] = "Armschienenverzauberungen" }
TRADE = { beruf = "Verzauberkunst", rezepte = {
  { id = 7457, name = "Armschiene - Geringe Ausdauer", item = 0, kat = 11, reagents = { { 10940, 2 }, { 10938, 1 } } },
  { id = 7418, name = "Armschiene - Geringe Gesundheit", item = 0, kat = 11, reagents = { { 10940, 1 } } } } }
fire(pudel, "TRADE_SKILL_SHOW"); RunTimers()
TRADE = nil
realPrint("Zwerg gemerkt: 7457=" .. tostring(pudel.env.GuildERPData.recipes[7457].kategorie) .. " 2387=" .. tostring(pudel.env.GuildERPData.recipes[2387].kategorie))
realPrint("Text: " .. pudel.env.GuildERPData.recipes[7457].name)
realPrint("=== Gruppe bilden")
inGruppe = true
fire(barlor, "GROUP_ROSTER_UPDATE"); fire(pudel, "GROUP_ROSTER_UPDATE"); RunTimers(); RunTimers(); RunTimers()
local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " / ")) end
realPrint("Barlor katGruppe: 7457=" .. tostring((d.katGruppe or {})[7457]) .. " 7418=" .. tostring((d.katGruppe or {})[7418]) .. " 2387=" .. tostring((d.katGruppe or {})[2387]))
local Kt = f.kat
for _, b in ipairs({ "Verzauberkunst", "Schneiderei" }) do
  d.settings.katBeruf = b; d.settings.katRezept = nil
  Click(f.reiterKat); RunTimers()
  realPrint("--- Katalog " .. b)
  for _, k in ipairs(Kt.links.koepfe) do if k.benutzt then realPrint("  Gruppe: " .. strip(k.text.text) .. " (" .. k.zahl.text .. ")") end end
end
