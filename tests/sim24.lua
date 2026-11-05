-- Teilen (ab 1.4): Fundorte und Auktionshaus-Preise zwischen zwei Spielern.
-- lua51 sim24.lua <GuildERP.lua>
dofile((arg[0]:gsub("sim24%.lua$", "")) .. "stubs.lua")
GetItemInfo = nil
C_Item = { GetItemIconByID = function(id) return "icon" .. id end }
Minimap = CreateFrame("Frame", "Minimap")

local jetzt = time()
local inst, inGruppe, ZAEHL = {}, false, {}
local function neueInstanz(name, voll, sv, fraktion)
    local env = setmetatable({}, { __index = _G })
    env.GuildERPData = sv
    env.SlashCmdList, env.UISpecialFrames = {}, {}
    env.UnitName = function(u)
        if u == "player" then return name end
        if u == "party1" then return name == "Barlor" and "Zwerg" or "Barlor" end
    end
    env.GetRealmName = function() return "Forever" end
    env.UnitFactionGroup = function() return fraktion end
    env.IsInGroup = function() return inGruppe end
    env.IsInRaid = function() return false end
    env.GetNumGroupMembers = function() return inGruppe and 2 or 0 end
    env.Ambiguate = function(n) return n end
    env.C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() end }
    local erster
    env.CreateFrame = function(...)
        local fr = CreateFrame(...)
        local _, nm = ...
        if nm then env[nm] = fr end
        erster = erster or fr
        return fr
    end
    env.print = function() end
    env.C_ChatInfo = {
        RegisterAddonMessagePrefix = function() return true end,
        SendAddonMessage = function(prefix, text, kanal)
            assert(#text <= 255, "Nachricht zu lang: " .. #text)
            local art = text:sub(1, 1)
            ZAEHL[name .. ":" .. art] = (ZAEHL[name .. ":" .. art] or 0) + 1
            for _, andere in ipairs(inst) do
                if inGruppe then
                    andere.frame.scripts.OnEvent(andere.frame, "CHAT_MSG_ADDON", prefix, text, kanal, voll .. "-Forever")
                end
            end
            return 0
        end,
    }
    local chunk = assert(loadfile(arg[1]))
    setfenv(chunk, env)
    chunk()
    local i = { name = name, voll = voll, env = env, frame = erster }
    table.insert(inst, i)
    return i
end
local function daten(name, fraktion)
    return { characters = { ["Forever-" .. name] = { name = name, faction = fraktion, recipes = {} } }, recipes = {}, items = {},
        settings = {}, orders = {}, plans = {} }
end
local function preis(sv, fraktion)
    sv.prices = sv.prices or {}
    sv.prices[fraktion] = sv.prices[fraktion] or {}
    return sv.prices[fraktion]
end
local function zustellen(i, text, voll)
    i.frame.scripts.OnEvent(i.frame, "CHAT_MSG_ADDON", "GERP1", text, "PARTY", voll .. "-Forever")
end

local svB = daten("Barlor", "Alliance")
svB.quellen = {
    ["Kupferkettengürtel"] = { { art = "Händler", wer = "Händlerin Grün", zone = "Eisenschmiede", x = 52.8, y = 44.9, kosten = 1200, skill = 50,
        beruf = "Schmiedekunst", fraktion = "Alliance", at = jetzt - 100 } },
    ["Hordenrezept"] = { { art = "Lehrer", wer = "Ork", zone = "Orgrimmar", beruf = "Schmiedekunst", fraktion = "Horde", at = jetzt - 100 } },
    ["Beuterezept"] = { { art = "Beute", wer = "Kobold", zone = "Elwynn", skill = 10, beruf = "Kochkunst", at = jetzt - 50 } },
}
local pb = preis(svB, "Alliance")
pb[2840] = { min = 100, avg = 120, n = 5, at = jetzt - 10 }    -- neuer als der von Zwerg
pb[2770] = { min = 300, avg = 310, n = 2, at = jetzt - 500 }   -- aelter als der von Zwerg
pb[2589] = { leer = true, at = jetzt - 20 }                    -- nicht im Angebot
pb[2318] = { min = 7, avg = 7, n = 1, at = jetzt - 4 * 86400 } -- zu alt zum Teilen
pb[2996] = { min = 9, avg = 9, n = 1, at = jetzt - 30, von = "Dritter" } -- nicht weiterreichen
preis(svB, "Horde")[1111] = { min = 1, avg = 1, n = 1, at = jetzt }

local svZ = daten("Zwerg", "Alliance")
local pz = preis(svZ, "Alliance")
pz[2840] = { min = 999, avg = 999, n = 1, at = jetzt - 1000 }
pz[2770] = { min = 111, avg = 111, n = 1, at = jetzt - 200 }

local barlor = neueInstanz("Barlor", "Barlor Rostbart", svB, "Alliance")
local zwerg = neueInstanz("Zwerg", "Zwerg Pudelmuetze", svZ, "Alliance")
inGruppe = true
for _, i in ipairs(inst) do
    i.frame.scripts.OnEvent(i.frame, "PLAYER_LOGIN")
end
RunTimers(); RunTimers()

-- Fundorte: angekommen, mit Herkunft, Horde nicht
local q = svZ.quellen["Kupferkettengürtel"]
assert(q and #q == 1, "Fundort nicht angekommen")
q = q[1]
assert(q.art == "Händler" and q.wer == "Händlerin Grün" and q.zone == "Eisenschmiede" and q.x == 52.8 and q.kosten == 1200 and q.skill == 50, "Fundort falsch")
assert(q.at == jetzt - 100, "Zeitstempel fehlt")
assert(q.von and q.von:find("Barlor", 1, true), "Herkunft fehlt")
assert(svZ.quellen["Beuterezept"][1].fraktion == nil, "Beute ist ohne Fraktion")
assert(not svZ.quellen["Hordenrezept"], "Horde-Quelle darf Allianz nicht erreichen")

-- Preise: neuerer gewinnt, Herkunft, nur eigene und frische
assert(pz[2840].min == 100 and pz[2840].von and pz[2840].at == jetzt - 10, "neuerer Preis muss gewinnen")
assert(pz[2770].min == 111 and not pz[2770].von, "aelterer Preis darf nicht gewinnen")
assert(pz[2589] and pz[2589].leer, "'nicht im Angebot' fehlt")
assert(not pz[2318], "alter Preis wird nicht geteilt")
assert(not pz[2996], "fremder Preis wird nicht weitergereicht")
assert(not svZ.prices["Horde"] or not svZ.prices["Horde"][1111], "Horde-Preis wird nicht geteilt")
assert(pb[2770].min == 111 and pb[2770].von, "Barlor muss Zwergs neueren Preis haben")

-- zweite Runde: nichts neu, nichts doppelt, kein neues Paket
-- (Wurde ein eigener Preis durch einen neueren ersetzt, aendert sich der Stand: das darf einmal
-- ein Paket ausloesen, danach muss Ruhe sein.)
NOW_OFFSET = 60
assert(ZAEHL["Barlor:Z"] and ZAEHL["Barlor:Z"] >= 1, "Barlor hat kein Paket gesendet")
zustellen(barlor, "H~2", zwerg.voll)
zustellen(zwerg, "H~2", barlor.voll)
RunTimers(); RunTimers()
NOW_OFFSET = 90
local z, z2 = ZAEHL["Barlor:Z"], ZAEHL["Zwerg:W"]
zustellen(barlor, "H~2", zwerg.voll)
zustellen(zwerg, "H~2", barlor.voll)
RunTimers(); RunTimers()
assert(ZAEHL["Barlor:Z"] == z and ZAEHL["Zwerg:W"] == z2, "unveraenderter Stand wurde erneut gesendet")
assert(#svZ.quellen["Kupferkettengürtel"] == 1, "Fundort doppelt")

-- Zeitstempel aus der Zukunft wird gekappt
zustellen(zwerg, "W~901~1~1~Alliance^4444=5=5=1=" .. (jetzt + 999999), barlor.voll)
assert(pz[4444] and pz[4444].at == time(), "Zukunfts-Zeit muss gekappt werden")
-- fremde Fraktion im Kopf wird verworfen, kaputte Nachrichten schaden nicht
zustellen(zwerg, "W~902~1~1~Horde^5555=5=5=1=" .. jetzt, barlor.voll)
assert(not pz[5555], "Preis der anderen Fraktion angenommen")
for _, m in ipairs({ "Z~903~1~1~x=y", "Z~904~1~1~====", "W~905~1~1~abc", "W~906~1~1~Alliance^a=b", "T~", "R~", "Z~kaputt" }) do
    zustellen(zwerg, m, barlor.voll)
end
assert(not svZ.quellen["x"], "kaputter Fundort gespeichert")

-- eigenes Gesehenes bleibt, auch wenn jemand anderes etwas meldet
zustellen(barlor, "Z~907~1~1~Beuterezept=Beute=Kobold=Elwynn=====Kochkunst==" .. jetzt, zwerg.voll)
assert(svB.quellen["Beuterezept"][1].von == nil, "Eigener Fund wurde ueberschrieben")

-- grosse Menge: bleibt in der Grenze und kommt vollstaendig an
NOW_OFFSET = 120
for n = 1, 400 do
    svB.quellen["Rezept Nummer " .. n] = { { art = "Lehrer", wer = "Lehrer Ä", zone = "Sturmwind", x = 1.5, y = 2.5, kosten = 100, skill = n,
        beruf = "Alchemie", fraktion = "Alliance", at = jetzt - n } }
end
local vorher = ZAEHL["Barlor:Z"]
zustellen(barlor, "H~2", zwerg.voll)
RunTimers(); RunTimers()
local teile = ZAEHL["Barlor:Z"] - vorher
assert(teile > 0 and teile <= 40, "Paket ausserhalb der Grenze: " .. teile)
assert(svZ.quellen["Rezept Nummer 1"], "neueste Fundorte muessen ankommen")
assert(not svZ.quellen["Rezept Nummer 400"], "aelteste passen nicht mehr ins Paket")

-- Option aus: nichts annehmen, nichts senden
NOW_OFFSET = 180
svZ.settings.optionen = { teilen = false }
svB.quellen["Ganz neu"] = { { art = "Lehrer", wer = "Neu", zone = "Sturmwind", beruf = "Alchemie", fraktion = "Alliance", at = jetzt } }
zustellen(barlor, "H~2", zwerg.voll)
RunTimers(); RunTimers()
assert(not svZ.quellen["Ganz neu"], "Option aus: darf nichts annehmen")
local vorherZ = ZAEHL["Zwerg:T"] or 0
NOW_OFFSET = 240
svZ.quellen["Eigen"] = { { art = "Lehrer", wer = "E", zone = "Z", beruf = "Alchemie", at = jetzt } }
zustellen(zwerg, "H~2", barlor.voll)
RunTimers(); RunTimers()
assert((ZAEHL["Zwerg:T"] or 0) == vorherZ, "Option aus: darf nichts senden")
realPrint("Teilen ok: " .. teile .. " Teile im grossen Paket")
