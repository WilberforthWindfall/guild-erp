-- Werkstatt (ab 1.4.1): zeigt nur, was der gerade gespielte Charakter kann.
-- lua51 sim26.lua <GuildERP.lua>
dofile((arg[0]:gsub("sim26%.lua$", "")) .. "stubs.lua")
GetItemInfo = nil
C_Item = { GetItemIconByID = function(id) return "icon" .. id end }
Minimap = CreateFrame("Frame", "Minimap")
GuildERPData = {
    characters = {
        ["Forever-Zwerg"] = { name = "Zwerg", faction = "Alliance", recipes = { ["Schmiedekunst"] = { [1] = true, [3] = true } },
            bags = {}, bank = {} },
        ["Forever-Hilda"] = { name = "Hilda", faction = "Alliance", recipes = { ["Kochkunst"] = { [2] = true }, ["Schmiedekunst"] = { [3] = true } },
            bags = { [2840] = 7 }, bank = {} },
    },
    recipes = {
        [1] = { name = "Kupferbarren schmieden", profession = "Schmiedekunst", itemID = 2840, reagents = { { itemID = 2770, count = 1 } } },
        [2] = { name = "Verkohltes Wolfsfleisch", profession = "Kochkunst", itemID = 2589, reagents = { { itemID = 2318, count = 1 } } },
        [3] = { name = "Kupferkettengürtel", profession = "Schmiedekunst", itemID = 2851, reagents = { { itemID = 2840, count = 2 } } },
    },
    items = {}, settings = {}, orders = {},
    plans = { [2] = { id = "Hilda-P1", rezeptID = 2, menge = 1, wer = "Hilda", at = 1 },
              [3] = { id = "Hilda-P2", rezeptID = 3, menge = 1, wer = "Hilda", at = 1 } },
}
local d = GuildERPData

local function offnen()
    SlashCmdList.GUILDERP(""); RunTimers()
    if not GuildERPFenster.shown then SlashCmdList.GUILDERP(""); RunTimers() end
end
local function rezepte()
    local namen = {}
    for _, z in ipairs(GuildERPFenster.links.zeilen) do
        if z.benutzt then namen[#namen + 1] = (z.name.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
    end
    table.sort(namen)
    return table.concat(namen, ",")
end
local function kopfZahl(titel)
    for _, k in ipairs(GuildERPFenster.links.koepfe) do
        if k.benutzt and string.find(k.text.text, titel, 1, true) then return k.rechts.text end
    end
end

PLAYER = { name = "Zwerg", realm = "Forever", faction = "Alliance", class = "WARRIOR", zone = "Eisenschmiede" }
assert(loadfile(arg[1]))()
Fire("PLAYER_LOGIN"); RunTimers()
offnen()
local f = GuildERPFenster
local L = f.links

-- Zwerg: nur Schmiedekunst, nur eigene Rezepte
assert(L.handwerk.text.text == "Schmiedekunst", "Beruf falsch: " .. L.handwerk.text.text)
assert(L.handwerk.rechts.text == "Zwerg, 2 Rezepte", "Text falsch: " .. L.handwerk.rechts.text)
assert(kopfZahl("Gelernt") == "2", "Zahl falsch: " .. tostring(kopfZahl("Gelernt")))
-- Kochkunst (nur Hilda) steht nicht in der Auswahl
Click(L.handwerk); RunTimers()
for _, z in ipairs(GuildERPAuswahl.zeilen) do
    assert(not (z.shown and z.text and z.text.text == "Kochkunst"), "Kochkunst gehoert nicht in Zwergs Werkstatt")
end
GuildERPAuswahl:Hide()

-- Wer stellt her? Auch beim Rezept, das beide koennen: nur Zwerg
d.settings.wunsch = 3
offnen()
assert(string.find(f.rechts.auftrag.wer.text.text, "Zwerg", 1, true), "Hersteller falsch: " .. f.rechts.auftrag.wer.text.text)
assert(not string.find(f.rechts.auftrag.wer.text.text, "Hilda", 1, true), "Hilda darf hier nicht stehen")
assert(d.plans[3].wer == "Hilda", "Anschauen darf den Planauftrag nicht umschreiben")

-- Zutaten bei Hilda zaehlen weiter mit (Stueckliste sieht alle eigenen Charaktere)
local gefunden = false
for _, z in ipairs(f.rechts.zeilen) do
    if z.benutzt and string.find(tostring(z.rechtsText and z.rechtsText.text or z.menge and z.menge.text or ""), "2", 1, true) then gefunden = true end
end
assert(gefunden or f.rechts.bereit.shown, "Stueckliste fehlt")

-- Sprung aus einem Planauftrag von Hilda: verstaendlicher Hinweis
d.settings.wunsch = 2
offnen()
assert(string.find(f.rechts.karte.name.text, "Verkohltes Wolfsfleisch", 1, true), "Rezeptname fehlt")
assert(string.find(f.rechts.karte.unter.text, "Das kann Hilda", 1, true), "Hinweis fehlt: " .. f.rechts.karte.unter.text)
assert(not f.rechts.auftrag.shown, "kein Herstellauftrag fuer fremden Charakter")

-- Noch nicht gelernt: mit Quelle erscheint Kochkunst als Beruf (Option), und Hildas Rezept ist fuer Zwerg ungelernt
d.settings.wunsch = nil
d.quellen = { ["Verkohltes Wolfsfleisch"] = { { art = "Lehrer", wer = "Gremlock", zone = "Dun Morogh", beruf = "Kochkunst", fraktion = "Alliance", at = 1 } } }
d.settings.beruf = "Kochkunst"
offnen()
assert(L.handwerk.text.text == "Kochkunst", "Option an: Beruf mit Quelle muss erscheinen")
assert(L.handwerk.rechts.text == "noch nicht gelernt", "Text falsch: " .. L.handwerk.rechts.text)
assert(kopfZahl("Noch nicht gelernt") == "1, Quelle bekannt", "Rezept fehlt unter Noch nicht gelernt")
assert(kopfZahl("Gelernt") == nil, "kein Kopf Gelernt")

-- Katalog zeigt weiter alle (Kat nutzt die volle Sammlung)
d.settings.ansicht = "kat"; d.settings.katBeruf = "Kochkunst"
offnen()
assert(f.kat, "Katalog fehlt")
d.settings.ansicht = nil

-- Hilda: sieht ihre Rezepte
d.quellen = {}
d.settings.beruf = nil
PLAYER.name = "Hilda"
offnen()
assert(L.handwerk.text.text == "Kochkunst", "Hilda: Beruf falsch")
assert(L.handwerk.rechts.text == "Hilda, 1 Rezept", "Hilda: Text falsch: " .. L.handwerk.rechts.text)
realPrint("Werkstatt ok")
