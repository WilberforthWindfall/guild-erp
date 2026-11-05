-- Zwei Spieler (Barlor, Zwerg Pudel), je eigene Add-on-Instanz und eigene gespeicherte Daten.
-- lua51 sim10.lua <GuildERP.lua neu> <SV Barlor> <GuildERP.lua fuer Pudel>
dofile((arg[0]:gsub("sim10v%.lua$", "")) .. "stubs.lua")
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
local function zaehl(t) local k = {} for n, v in pairs(ZAEHL) do table.insert(k, n .. "=" .. v) end table.sort(k) realPrint("  Nachrichten " .. t .. ": " .. table.concat(k, "  ")) ZAEHL = {} end
zaehl("beim Beitritt")
local po = 0 for _, o in pairs(pudel.env.GuildERPData.orders or {}) do po = po + 1 end
realPrint("  Pudel hat Bestellungen: " .. po)
local fr = d.fremd or {}
for n, e in pairs(fr) do for b, ids in pairs(e.berufe) do local c = 0 for _ in pairs(ids) do c = c + 1 end realPrint("  Barlor kennt von " .. n .. ": " .. b .. " (" .. c .. ")") end end
local pf = pudel.env.GuildERPData.fremd or {}
local pc = 0 for n, e in pairs(pf) do for b, ids in pairs(e.berufe) do for _ in pairs(ids) do pc = pc + 1 end end end
realPrint("  Pudel kennt Rezepte von Barlors Charakteren: " .. pc)
-- Katalog anschauen
Click(f.reiterKat); RunTimers()
local K = f.kat
local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " / ")) end
realPrint("--- Katalog: " .. strip(K.links.beruf.text.text) .. " | " .. strip(K.links.beruf.rechts.text))
Click(K.links.beruf); RunTimers()
for _, z in ipairs(barlor.env.GuildERPAuswahl.zeilen) do if z.shown then realPrint("   Liste: " .. strip(z.text.text) .. " | " .. strip(z.rechts.text)) end end
for _, z in ipairs(barlor.env.GuildERPAuswahl.zeilen) do if z.shown and z.text.text == "Verzauberkunst" then Click(z) end end
RunTimers()
for _, z in ipairs(K.links.zeilen) do if z.benutzt then realPrint("   " .. strip(z.name.text) .. "  [" .. strip(z.wer.text) .. "]") end end
Click(K.links.zeilen[1]); RunTimers()
realPrint("   rechts: " .. strip(K.rechts.karte.name.text) .. " | " .. strip(K.rechts.karte.unter.text))
realPrint("   " .. strip(K.rechts.wer.text))
realPrint("   Zutaten: " .. strip(K.rechts.zutaten.text))
realPrint("   Fuss: " .. strip(K.links.fuss.text))
-- Gruppe neu (z. B. nach Neuverbinden): nichts geaendert -> nur Stand
realPrint("=== Erneuter Beitritt ohne Aenderung")
inGruppe = false; fire(barlor, "GROUP_ROSTER_UPDATE"); fire(pudel, "GROUP_ROSTER_UPDATE"); RunTimers()
barlor.env.B_mitglieder = nil
inGruppe = true; fire(barlor, "GROUP_ROSTER_UPDATE"); fire(pudel, "GROUP_ROSTER_UPDATE"); RunTimers(); RunTimers()
zaehl("erneut")
-- Pudel lernt ein Rezept
realPrint("=== Pudel lernt Umhang - Geringer Schutz")
svPudel.characters["Classic Beta PvE-Zwerg"].recipes["Verzauberkunst"][7771] = true
fire(pudel, "TRADE_SKILL_LIST_UPDATE"); RunTimers(); RunTimers()
zaehl("nach Lernen")
local c = 0 for _ in pairs(d.fremd["Zwerg"].berufe["Verzauberkunst"]) do c = c + 1 end
realPrint("  Barlor kennt jetzt Verzauberkunst von Pudel: " .. c)
-- Tooltip-Test
GameTooltip = CreateFrame("Frame", "GameTooltip"); local zeilen = {}
GameTooltip.SetOwner = function() zeilen = {} end
GameTooltip.SetHyperlink = function(_, l) table.insert(zeilen, "LINK " .. l) end
GameTooltip.SetSpellByID = function(_, id) table.insert(zeilen, "SPELL " .. id) end
GameTooltip.AddLine = function(_, t) table.insert(zeilen, t) end
GameTooltip.Show = function() end
barlor.env.GameTooltip = GameTooltip
Click(f.reiterKat); RunTimers()
local z = K.links.zeilen[1]; z.scripts.OnEnter(z)
realPrint("Tooltip Zeile: " .. table.concat(zeilen, " | "))
K.rechts.karte.scripts.OnEnter(K.rechts.karte)
realPrint("Tooltip Karte: " .. table.concat(zeilen, " | "))
