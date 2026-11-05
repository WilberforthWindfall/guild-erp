-- Zwei Spieler (Barlor, Zwerg Pudel), je eigene Add-on-Instanz und eigene gespeicherte Daten.
-- lua51 sim10.lua <GuildERP.lua neu> <SV Barlor> <GuildERP.lua fuer Pudel>
dofile((arg[0]:gsub("sim12%.lua$", "")) .. "stubs.lua")
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

-- Pudel kennt auch Geringe Magieessenz (10938) aus Seltsamem Staub (10940); Rezept 7418 braucht 10940
Click(f.reiterKat); RunTimers()
local Kt = f.kat
d.settings.katBeruf = "Verzauberkunst"; d.settings.katRezept = 7457
Click(f.reiterKat); RunTimers()
realPrint("--- Katalog links:")
for _, k in ipairs(Kt.links.koepfe) do if k.benutzt then realPrint("  Gruppe: " .. strip(k.text.text) .. " (" .. k.zahl.text .. ")") end end
for _, z in ipairs(Kt.links.zeilen) do if z.benutzt then realPrint("     " .. strip(z.name.text) .. " [" .. strip(z.wer.text) .. "]") end end
realPrint("--- Baum rechts: " .. strip(Kt.rechts.zTitel.text))
for _, z in ipairs(Kt.rechts.baumZeilen) do if z.benutzt then realPrint("   " .. (z.knopf.shown and "[-] " or "    ") .. strip(z.name.text) .. " " .. strip(z.zahl.text) .. " | " .. strip(z.info.text)) end end
-- Gruppe zuklappen
Click(Kt.links.koepfe[1]); RunTimers()
local n = 0 for _, z in ipairs(Kt.links.zeilen) do if z.benutzt and z.shown then n = n + 1 end end
realPrint("Nach Zuklappen sichtbare Rezepte: " .. n .. " | rechts noch: " .. strip(Kt.rechts.karte.name.text))
-- Bestellen -> bei Zwerg: kein Fenster, Knopf leuchtet
Click(Kt.links.koepfe[1]); RunTimers()
Click(Kt.rechts.form.knopf); RunTimers(); RunTimers()
local H = pudel.env.GuildERPHinweis
local MK = pudel.env.GuildERPMinimapKnopf
realPrint("--- Zwerg: Fenster in der Mitte: " .. tostring(H and H.shown) .. " | Minimap-Knopf: " .. tostring(MK and MK.shown) .. " leuchtet " .. tostring(MK and MK.glanz.shown) .. " Zahl " .. tostring(MK and MK.zahl.text))
GameTooltip = CreateFrame("Frame", "GameTooltip"); local tt = {}
GameTooltip.SetOwner = function() tt = {} end; GameTooltip.AddLine = function(_, t) table.insert(tt, t) end; GameTooltip.Show = function() end
pudel.env.GameTooltip = GameTooltip
MK.scripts.OnEnter(MK)
realPrint("  Tooltip: " .. strip(table.concat(tt, " | ")))
Click(MK, "LeftButton"); RunTimers()
realPrint("  nach Klick: Ansicht " .. pudel.env.GuildERPData.settings.ansicht .. " | leuchtet " .. tostring(MK.glanz.shown) .. " | Zahl '" .. tostring(MK.zahl.text) .. "'")
-- Optionen: Fenster in der Mitte
Click(MK, "RightButton"); RunTimers()
local OF = pudel.env.GuildERPOptionen
realPrint("--- Optionen offen: " .. tostring(OF.shown))
for _, el in ipairs(OF.zeilen) do realPrint("   " .. (el.text and strip(el.text.text) or tostring(el:GetChecked()))) end
Click(OF.zeilen[1]); RunTimers()
for _, z in ipairs(pudel.env.GuildERPAuswahl.zeilen) do if z.shown and z.text.text == "Fenster in der Mitte" then Click(z) end end
RunTimers()
realPrint("  Neues anzeigen jetzt: " .. strip(OF.zeilen[1].text.text))
Click(OF.plus); RunTimers()
realPrint("  Größe: " .. OF.groesse.text)
-- Barlor bestellt nochmal -> jetzt Fenster
Click(f.reiterKat); RunTimers()
d.settings.katRezept = 7418; Click(f.reiterKat); RunTimers()
Click(Kt.rechts.form.knopf); RunTimers(); RunTimers()
H = pudel.env.GuildERPHinweis
realPrint("  Zwerg: Fenster in der Mitte jetzt: " .. tostring(H and H.shown) .. " | " .. (H and strip(H.text.text) or ""))
-- Baum mit eigenem Rezept: Kupferstreitaxt (Kupferbarren kann Barlor herstellen)
local axt
for id, r in pairs(d.recipes) do if r.name == "Kupferstreitaxt" then axt = id end end
d.settings.katBeruf = "Schmiedekunst"; d.settings.katRezept = axt
Click(f.reiterKat); RunTimers()
realPrint("--- Baum Kupferstreitaxt: " .. strip(Kt.rechts.zTitel.text))
for _, z in ipairs(Kt.rechts.baumZeilen) do if z.benutzt then realPrint("   " .. (z.knopf.shown and "[-] " or "    ") .. strip(z.name.text) .. " " .. strip(z.zahl.text) .. " | " .. strip(z.info.text)) end end
for _, k in ipairs(Kt.links.koepfe) do if k.benutzt then realPrint("  Gruppe: " .. strip(k.text.text) .. " (" .. k.zahl.text .. ")") end end
