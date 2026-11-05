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

-- Zutaten-Zeile: die Haendler-Zeile endet vor dem Knopf "Bestellen" (lief im Spiel darunter)
d.vendors = { [2770] = { ["Golorn Frostbeard"] = { zone = "Dun Morogh", x = 46.8, y = 53, price = 2, stack = 1, faction = "Alliance", at = 1 } } }
d.settings.wunsch = 1
offnen()
local geprueft = false
for _, z in ipairs(f.rechts.zeilen) do
    if z.benutzt and z.itemID == 2770 then
        assert(z.bestellen.shown, "Knopf Bestellen fehlt")
        assert(string.find(z.quelle.text, "Golorn", 1, true), "Haendler fehlt: " .. z.quelle.text)
        local rechts
        for _, p in ipairs(z.quelle.points) do
            if p[1] == "RIGHT" then rechts = p end
        end
        assert(rechts and rechts[2] == z.bestellen and rechts[3] == "LEFT", "Zeile laeuft unter den Knopf")
        geprueft = true
    end
end
assert(geprueft, "Zutaten-Zeile nicht gefunden")

-- Verfuegbarkeit: jeder Zustand hat ein eigenes Bildsymbol, fehlt die Grafik, kommt die Raute
local function symbolVon(itemID)
    for _, z in ipairs(f.rechts.zeilen) do
        if z.benutzt and z.itemID == itemID then return z.punkt.texture, z.punkt.w end
    end
end
local bild, breite = symbolVon(2770)
assert(bild == "Interface\\RaidFrame\\ReadyCheck-NotReady" and breite == 14, "fehlt: " .. tostring(bild))
assert(f.rechts.bereit.rauten.tasche.texture == "Interface\\Icons\\INV_Misc_Bag_08", "Tasche im Zaehler falsch")
assert(f.rechts.bereit.rauten.gruen.texture == "Interface\\Icons\\INV_Box_01", "Woanders im Zaehler falsch")
d.settings.wunsch = 3
offnen()
assert(symbolVon(2840) == "Interface\\Icons\\INV_Box_01", "woanders (bei Hilda): " .. tostring(symbolVon(2840)))
local symbole = {}
for _, st in ipairs({ "tasche", "gruen", "blau", "gelb", "rot" }) do
    local t = f.rechts.bereit.rauten[st].texture
    assert(t and not symbole[t], "Symbol doppelt oder fehlt: " .. st)
    symbole[t] = true
end
GetFileIDFromPath = function() return nil end -- Grafik im Spiel nicht vorhanden
d.settings.wunsch = 1
offnen()
local ersatz, ersatzBreite = symbolVon(2770)
assert(string.find(tostring(ersatz), "WHITE8X8", 1, true) and ersatzBreite == 8, "Rueckfall fehlt: " .. tostring(ersatz))
GetFileIDFromPath = nil

-- Altes Wunschrezept von Hilda (Wunsch gilt fuer alle Charaktere): bleibt still, kein Hinweis
d.settings.wunsch = 2
offnen()
assert(string.find(f.rechts.karte.name.text, "Noch kein Wunschrezept", 1, true), "altes Wunschrezept: " .. f.rechts.karte.name.text)
assert(d.settings.wunsch == 2, "Hildas Wunschrezept soll erhalten bleiben")

-- Sprung aus einem Planauftrag von Hilda: verstaendlicher Hinweis
d.settings.wunsch = nil
d.settings.ansicht = "plan"
offnen()
-- Plaene anderer Charaktere sind zugeklappt: Bereich oeffnen
for _, k in ipairs(f.plan.koepfe or {}) do
    if k.benutzt and k.scripts.OnClick then Click(k); RunTimers() end
end
for i = 1, #f.plan.karten do
    local k = f.plan.karten[i]
    if d.settings.wunsch ~= 2 and k.benutzt and k.werkstatt.scripts.OnClick then
        Click(k.werkstatt); RunTimers()
        if d.settings.wunsch ~= 2 then d.settings.ansicht = "plan"; offnen() end
    end
end
assert(d.settings.wunsch == 2, "Sprung aus dem Planauftrag hat nicht geklappt")
assert(string.find(f.rechts.karte.name.text, "Verkohltes Wolfsfleisch", 1, true), "Rezeptname fehlt: " .. f.rechts.karte.name.text)
assert(string.find(f.rechts.karte.unter.text, "Das kann Hilda", 1, true), "Hinweis fehlt: " .. f.rechts.karte.unter.text)
assert(not f.rechts.auftrag.shown, "kein Herstellauftrag fuer fremden Charakter")

-- Standard: nur Berufe, die dieser Charakter hat, auch wenn Quellen bekannt sind (so vom Nutzer gewuenscht)
d.settings.ansicht = nil
d.settings.wunsch = "g:Kochkunst:Verkohltes Wolfsfleisch"
d.quellen = { ["Verkohltes Wolfsfleisch"] = { { art = "Lehrer", wer = "Gremlock", zone = "Dun Morogh", beruf = "Kochkunst", fraktion = "Alliance", at = 1 } } }
d.settings.beruf = "Kochkunst"
offnen()
assert(L.handwerk.text.text == "Schmiedekunst", "Kochkunst darf nicht erscheinen: " .. L.handwerk.text.text)
assert(d.settings.wunsch == nil, "graues Wunschrezept aus fremdem Beruf muss weg")

-- Charakter ganz ohne Beruf: keine Berufe, keine Rezepte
local schmied = d.characters["Forever-Zwerg"].recipes
d.characters["Forever-Zwerg"].recipes = {}
offnen()
assert(string.find(L.handwerk.text.text, "Noch kein Handwerk bekannt", 1, true), "ohne Beruf: " .. L.handwerk.text.text)
assert(rezepte() == "", "ohne Beruf keine Rezepte: " .. rezepte())
assert(kopfZahl("Noch nicht gelernt") == nil, "ohne Beruf kein Bereich Noch nicht gelernt")
d.characters["Forever-Zwerg"].recipes = schmied

-- Option an: mit Quelle erscheint Kochkunst als Beruf, und Hildas Rezept ist fuer Zwerg ungelernt
d.settings.optionen = d.settings.optionen or {}
d.settings.optionen.ungelernt = true
d.settings.wunsch = nil
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
