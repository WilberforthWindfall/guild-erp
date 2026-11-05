-- Zwei Spieler (Barlor, Zwerg Pudel), je eigene Add-on-Instanz und eigene gespeicherte Daten.
-- lua51 sim10.lua <GuildERP.lua neu> <SV Barlor> <GuildERP.lua fuer Pudel>
dofile((arg[0]:gsub("sim22%.lua$", "")) .. "stubs.lua")
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
    env.IsInGuild = function() return true end
    env.GetNumGuildMembers = function() return 2 end
    env.GetGuildRosterInfo = function(i) if i == 1 then return "Barlor Rostbart-ClassicBetaPvE", "R", 0, 1, "", "", "", "", true end return "Zwerg Pudelmuetze-ClassicBetaPvE", "R", 0, 1, "", "", "", "", true end
    env.C_GuildInfo = { GuildRoster = function() end }
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
svBarlor.settings.optionen = svBarlor.settings.optionen or {}; svBarlor.settings.optionen.gilde = true
local barlor = neueInstanz("Barlor", svBarlor, fach)
local svPudel = { characters = { ["Classic Beta PvE-Zwerg"] = { name = "Zwerg", faction = "Alliance",
    recipes = { ["Verzauberkunst"] = { [7457] = true, [7418] = true }, ["Schneiderei"] = { [2387] = true } } } },
  recipes = { [7457] = { name = "Armschiene - Geringe Ausdauer", profession = "Verzauberkunst", reagents = { { itemID = 10940, count = 2 }, { itemID = 10938, count = 1 } } },
              [7418] = { name = "Armschiene - Geringe Gesundheit", profession = "Verzauberkunst", reagents = { { itemID = 10940, count = 1 } } },
              [2387] = { name = "Leinenhemd", profession = "Schneiderei", itemID = 2576, reagents = { { itemID = 2996, count = 1 } } } }, settings = { optionen = { gilde = true } } }
local pudel = neueInstanz("Zwerg", svPudel, { { 10940, 3 } }, arg[3])
inGruppe = true -- (Zustellung im Test; Gilde braucht keine Gruppe)
for _, i in ipairs(inst) do i.env.IsInGroup = function() return false end end
fire(barlor, "PLAYER_LOGIN"); fire(pudel, "PLAYER_LOGIN"); RunTimers(); RunTimers()
local d = barlor.env.GuildERPData
local t = {} for n in pairs(d.fremd or {}) do t[#t+1] = n end
realPrint("Gildenabgleich: Barlor kennt Katalog von: " .. table.concat(t, ", "))
realPrint("Kanal-Zähler: " .. tostring(ZAEHL["Barlor:H"]) .. " H, " .. tostring(ZAEHL["Barlor:K"]) .. " K")
realPrint("Mitglieder (online): " .. table.concat(barlor.env.SlashCmdList and (function() return {} end)() or {}, ","))
-- Nachricht aus der Gruppe (PARTY) wird ignoriert
local vorher = d.diagnostics.abgleich.empfangen and d.diagnostics.abgleich.empfangen.H or 0
barlor.frame.scripts.OnEvent(barlor.frame, "CHAT_MSG_ADDON", "GERP1", "H~2", "PARTY", "Fremder Typ-ClassicBetaPvE")
realPrint("PARTY-Nachricht ignoriert: " .. tostring((d.diagnostics.abgleich.empfangen.H or 0) == vorher))
-- Handel mit Nicht-Gildenmitglied
local abgebrochen, gefluestert = 0, nil
barlor.env.UnitIsInMyGuild = function() return false end
barlor.env.UnitName = function(u) if u == "player" then return "Barlor" end if u == "NPC" then return "Fremder" end end
barlor.env.CancelTrade = function() abgebrochen = abgebrochen + 1 end
barlor.env.C_ChatInfo.SendChatMessage = function(t, k, _, z) gefluestert = k .. " an " .. tostring(z) .. ": " .. t end
fire(barlor, "TRADE_SHOW"); fire(barlor, "TRADE_SHOW")
realPrint("Handel abgebrochen: " .. abgebrochen .. "x, geflüstert: " .. tostring(gefluestert))
-- Handel mit Gildenmitglied
barlor.env.UnitIsInMyGuild = function() return true end
fire(barlor, "TRADE_SHOW")
realPrint("Gildenhandel abgebrochen? " .. tostring(abgebrochen > 2))
-- Post
barlor.env.MailFrame = CreateFrame("Frame", "MailFrame")
barlor.env.InboxFrame = CreateFrame("Frame", "InboxFrame")
barlor.env.GetInboxNumItems = function() return 3 end
barlor.env.GetInboxHeaderInfo = function(i)
  if i == 1 then return nil, nil, "Zwerg Pudelmuetze", "Gruß", 0, 0, 30, 0, false, false, false, true, false end
  if i == 2 then return nil, nil, "Fremder", "Billig Gold!", 0, 0, 30, 1, false, false, false, true, false end
  return nil, nil, "Auktionshaus", "Verkauft", 0, 0, 30, 0, false, false, false, false, false
end
fire(barlor, "MAIL_SHOW")
local w = barlor.env.GuildERPPost
local zeilen = {} for _, z in ipairs(w and w.zeilen or {}) do if z.shown then zeilen[#zeilen+1] = z.text.text end end
realPrint("Post-Hinweis: " .. tostring(w and w.shown) .. " | " .. table.concat(zeilen, " / "))
