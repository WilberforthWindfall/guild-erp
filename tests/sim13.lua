-- Zwei Spieler (Barlor, Zwerg Pudel), je eigene Add-on-Instanz und eigene gespeicherte Daten.
-- lua51 sim10.lua <GuildERP.lua neu> <SV Barlor> <GuildERP.lua fuer Pudel>
dofile((arg[0]:gsub("sim13%.lua$", "")) .. "stubs.lua")
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
              [2387] = { name = "Leinenhemd", profession = "Schneiderei", itemID = 2576, reagents = { { itemID = 2996, count = 1 } } } } }
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
realPrint("=== Gruppe bilden")
inGruppe = true
fire(barlor, "GROUP_ROSTER_UPDATE"); fire(pudel, "GROUP_ROSTER_UPDATE"); RunTimers(); RunTimers()

local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " / ")) end
local function voll(i) local c for k, v in pairs(i.env.GuildERPData.characters) do if v.name == i.name then c = v end end return c and c.voll end
realPrint("Volle Namen gelernt: Barlor=" .. tostring(voll(barlor)) .. "  Zwerg=" .. tostring(voll(pudel)))
local pd = pudel.env.GuildERPData
realPrint("Barlor kennt Katalog von: " .. table.concat((function() local t = {} for n in pairs(d.fremd) do t[#t+1] = n end return t end)(), ", "))


Click(f.reiterKat); RunTimers()
local Kt = f.kat
Click(Kt.links.beruf); RunTimers()
for _, z in ipairs(barlor.env.GuildERPAuswahl.zeilen) do if z.shown then realPrint("   Beruf: " .. strip(z.text.text) .. " | " .. strip(z.rechts.text)) end end
barlor.env.GuildERPAuswahl:Hide()
-- Schneiderei-Rezept von Zwerg: Leinenhemd (2576) als seelengebunden markieren
d.items[2576] = d.items[2576] or {}; d.items[2576].bind = 1
Click(f.reiterKat); RunTimers()
Click(Kt.links.beruf); RunTimers()
for _, z in ipairs(barlor.env.GuildERPAuswahl.zeilen) do if z.shown then realPrint("   nach BoP: " .. strip(z.text.text) .. " | " .. strip(z.rechts.text)) end end
