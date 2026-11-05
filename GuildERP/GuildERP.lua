-- Guild ERP 1.4 (Beta)
-- Werkstatt: links das Rezeptbuch (Handwerk waehlen, suchen), rechts der Herstellauftrag mit
-- mehrstufiger Stueckliste und Ampel, ob alles da ist.
-- Liest ausschliesslich ueber die normale Add-on-Schnittstelle (nur lesend) und speichert
-- in GuildERPData (SavedVariables). Es werden keine Spielhandlungen ausgefuehrt oder
-- automatisiert: nichts wird gekauft, hergestellt, verschickt oder gehandelt.
-- Einzige Ausnahme (Wunsch des Nutzers): Auf DEINEN Klick "Im Berufefenster öffnen" oeffnet
-- Guild ERP das normale Berufefenster, waehlt das Rezept an und traegt die Menge ein.
-- Herstellen klickst du dort selbst.
-- Ab 0.5: Bestellungen in der Gruppe. Das sind nur Vermerke (wer braucht was, wer liefert),
-- die per Add-on-Nachricht an die Gruppe gehen. Uebergeben macht jeder selbst.
-- Ab 0.6: Planauftraege (vorgemerkte Herstellungen). Zusagen der Gruppe verringern den Bedarf.
-- Ab 0.7: Unter-Zutaten im Planauftrag aufklappbar, Fenster "Auftragsnetz" (nur Anzeige).
-- Ab 0.8: Auktionshaus-Preise der Zutaten (nur suchen und lesen, nie kaufen oder einstellen).
-- Ab 0.9: Stand-Abgleich in der Gruppe (nur Geaendertes wird gesendet), Reiter "Katalog".
-- Ab 1.0: aus dem Katalog bestellen (auch Verzauberungen), Hinweisfenster, Zusage als Planauftrag,
-- Stornieren mit Abhaengigkeiten, volle Namen (Vor- und Nachname).
-- Ab 1.1: Katalog in Gruppen und mit Zutaten-Baum, Knopf an der Minimap, Optionen.
-- Ab 1.4: merkt sich selbst, wo es noch nicht gelernte Rezepte gibt (Lehrer, Haendler, Beute).
-- Ist der Reiseführer (ForeverDashboard) installiert, liest Guild ERP dessen Rezeptkatalog
-- zusaetzlich mit. Ohne Reiseführer laeuft alles genauso.

local ADDON_TITEL = "|cffd4af37Guild ERP|r"
local frame = CreateFrame("Frame")
local K = {} -- Konstanten (spart Platz fuer lokale Namen)
K.VERSION = "1.4"
K.ICON_UNBEKANNT = "Interface\\Icons\\INV_Misc_QuestionMark"
K.ICON_TITEL = "Interface\\Icons\\Trade_BlackSmithing"
K.ICON_REZEPT = "Interface\\Icons\\INV_Scroll_03"
K.WEISS = "Interface\\Buttons\\WHITE8X8"
K.MAX_TIEFE = 6
K.LISTE_ZEILEN = 16
K.MENGE_MAX = 200
K.GOLD = { 0.79, 0.65, 0.30 }
K.GOLD_DUNKEL = { 0.42, 0.34, 0.15 }
K.TEXT = { 0.93, 0.89, 0.78 }
K.GEDAEMPFT = { 0.60, 0.58, 0.52 }
K.STATUS_RGB = {
    gruen = { 0.36, 0.77, 0.42 },
    gelb = { 0.91, 0.71, 0.24 },
    rot = { 0.88, 0.38, 0.29 },
    tasche = { 0.50, 0.94, 0.56 },
    blau = { 0.50, 0.70, 0.92 },
}
K.ZAEHLER = { "tasche", "gruen", "blau", "gelb", "rot" }
-- farbiges Quadrat als Text-Symbol (die Spielschrift hat keine Raute)
function K.Punkt(st)
    local c = K.STATUS_RGB[st] or { 0.6, 0.6, 0.6 }
    return string.format("|TInterface\\Buttons\\WHITE8X8:8:8:0:0:8:8:0:8:0:8:%d:%d:%d|t",
        math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
end
K.STATUS_HEX = { gruen = "5cc46a", gelb = "e8b53e", rot = "e0604b", tasche = "7ff08f", blau = "7fb2ea" }
K.NEBENBERUFE = {
    ["Kochkunst"] = true, ["Angeln"] = true, ["Erste Hilfe"] = true,
    ["Cooking"] = true, ["Fishing"] = true, ["First Aid"] = true,
}
K.QUALITAET_HEX = { [0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd", [4] = "a335ee", [5] = "ff8000" }
K.QUALITAET_RGB = {
    [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 },
    [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 },
}

local Fenster
local FensterAktualisieren
local wahlHersteller = {} -- nur fuer diese Sitzung: [rezeptID] = Name des Herstellers
local B = {} -- Bestellungen in der Gruppe (Funktionen weiter unten)
local P = {} -- Planauftraege (Version 0.6)
local A = {} -- Auktionshaus-Preise (Version 0.8)
local Kat = {} -- Katalog: wer kann was (Version 0.9)
local O = {} -- Optionen und Minimap-Knopf (Version 1.1)

local function Melden(text)
    print(ADDON_TITEL .. ": " .. text)
end

local function Farbe(hex, text)
    return "|cff" .. hex .. tostring(text) .. "|r"
end

-- ---------------------------------------------------------------------------
-- Gespeicherte Daten
-- characters[Realm-Name] = { name, realm, faction, classToken, level,
--     recipes = { [Beruf] = { [rezeptID] = true } },
--     bags = { [itemID] = Anzahl }, bagsAt, bank = { [itemID] = Anzahl }, bankAt }
-- recipes[rezeptID] = { name, profession, itemID, icon, numMade, reagents = { {itemID, count} }, at }
-- items[itemID] = { name, icon, q }   (Namen/Symbole/Seltenheit zwischenspeichern)
-- vendors[itemID] = { [Haendler] = { zone, x, y, price, stack, faction, at } }
-- quellen[Rezeptname] = { { art = "Lehrer|Händler|Beute", wer, zone, x, y, kosten, skill, beruf, fraktion, at } }
-- settings = { window, wunsch, menge, zu, beruf, grau }
-- ---------------------------------------------------------------------------
local function Daten()
    GuildERPData = GuildERPData or {}
    local d = GuildERPData
    d.characters = d.characters or {}
    d.recipes = d.recipes or {}
    d.items = d.items or {}
    d.vendors = d.vendors or {}
    d.quellen = d.quellen or {}
    d.settings = d.settings or {}
    d.diagnostics = d.diagnostics or {}
    d.orders = d.orders or {}
    d.addonVersion = K.VERSION
    return d
end

-- ---------------------------------------------------------------------------
-- Fehlerschutz (ab 1.4): Ein Fehler in Guild ERP soll nie ein Fehlerfenster aufmachen. Alles, was
-- das Spiel aufruft (Ereignisse, Klicks, Zeitgeber, Befehle), laeuft ueber O.Sicher. Fehler werden
-- gesammelt (diagnostics.fehler, siehe /gerp info). Die Tests setzen GERP_STRENG, dann werden Fehler
-- weitergereicht, damit sie dort auffallen.
-- ---------------------------------------------------------------------------
K.FEHLER_MAX = 20

function O.Fehler(ort, text)
    pcall(function()
        local d = Daten()
        text = string.sub(tostring(text), 1, 300)
        d.diagnostics.fehler = d.diagnostics.fehler or {}
        local liste = d.diagnostics.fehler
        local eintrag
        for _, e in ipairs(liste) do
            if e.text == text and e.ort == ort then
                eintrag = e
            end
        end
        if not eintrag then
            eintrag = { ort = ort, text = text, n = 0, version = K.VERSION }
            table.insert(liste, eintrag)
            if #liste > K.FEHLER_MAX then
                table.remove(liste, 1)
            end
        end
        eintrag.n = eintrag.n + 1
        eintrag.at = time()
        -- pro Sitzung nur einmal im Chat, das Spiel laeuft ja normal weiter
        if not O.fehlerGemeldet then
            O.fehlerGemeldet = true
            Melden("Kleiner Fehler im Add-on, das Spiel läuft normal weiter. /gerp info zeigt Details.")
        end
    end)
    if GERP_STRENG then
        error(ort .. ": " .. tostring(text), 0)
    end
end

function O.SicherErgebnis(ort, ok, ...)
    if ok then
        return ...
    end
    O.Fehler(ort, (...))
end

function O.Sicher(ort, fn, ...)
    return O.SicherErgebnis(ort, pcall(fn, ...))
end

-- wie CreateFrame, aber alle Skripte des Fensters laufen ueber den Fehlerschutz
function O.Rahmen(...)
    local f = CreateFrame(...)
    local setzen = f.SetScript
    f.SetScript = function(self, art, fn)
        if type(fn) == "function" then
            local echt = fn
            fn = function(...)
                return O.Sicher(art, echt, ...)
            end
        end
        return setzen(self, art, fn)
    end
    return f
end

-- wie C_Timer.After, aber mit Fehlerschutz
function O.Nach(sekunden, fn)
    C_Timer.After(sekunden, function()
        O.Sicher("Zeitgeber", fn)
    end)
end

local function CharakterSchluessel()
    local name = UnitName("player")
    local realm = GetRealmName and GetRealmName()
    if not name or not realm then
        return nil
    end
    return realm .. "-" .. name, name, realm
end

local function Charakter()
    local d = Daten()
    local schluessel, name, realm = CharakterSchluessel()
    if not schluessel then
        return nil
    end
    local c = d.characters[schluessel] or {}
    d.characters[schluessel] = c
    c.name, c.realm = name, realm
    if UnitFactionGroup then
        c.faction = UnitFactionGroup("player") or c.faction
    end
    if UnitClass then
        local _, token = UnitClass("player")
        c.classToken = token or c.classToken
    end
    c.level = (UnitLevel and UnitLevel("player")) or c.level
    c.recipes = c.recipes or {}
    return c, schluessel
end

local function SpielerFraktion()
    return (UnitFactionGroup and UnitFactionGroup("player")) or "Alliance"
end

local function ItemIDAusLink(link)
    if type(link) ~= "string" then
        return nil
    end
    return tonumber(string.match(link, "item:(%d+)"))
end

local function ItemMerken(itemID, name, icon, q)
    if not itemID then
        return
    end
    local d = Daten()
    local e = d.items[itemID] or {}
    if type(name) == "string" and name ~= "" then
        e.name = name
    end
    if icon then
        e.icon = icon
    end
    if q then
        e.q = q
    end
    d.items[itemID] = e
end

-- Name eines Gegenstands ueber alle offiziellen Wege (je nach Spielversion verschieden)
local function ItemNameLesen(itemID)
    if C_Item and C_Item.GetItemNameByID then
        local ok, n = pcall(C_Item.GetItemNameByID, itemID)
        if ok and type(n) == "string" and n ~= "" then
            return n
        end
    end
    if C_Item and C_Item.GetItemInfo then
        local ok, n = pcall(C_Item.GetItemInfo, itemID)
        if ok and type(n) == "string" and n ~= "" then
            return n
        end
    end
    if GetItemInfo then
        local ok, n = pcall(GetItemInfo, itemID)
        if ok and type(n) == "string" and n ~= "" then
            return n
        end
    end
    if C_TooltipInfo and C_TooltipInfo.GetItemByID then
        local ok, daten = pcall(C_TooltipInfo.GetItemByID, itemID)
        local zeile = ok and type(daten) == "table" and daten.lines and daten.lines[1]
        if zeile and type(zeile.leftText) == "string" and zeile.leftText ~= "" and zeile.leftText ~= RETRIEVING_ITEM_INFO then
            return zeile.leftText
        end
    end
    return nil
end

-- Rueckgabe: Name (oder nil, solange das Spiel ihn noch laedt)
local function ItemName(itemID)
    if not itemID then
        return nil
    end
    local n = ItemNameLesen(itemID)
    if n then
        ItemMerken(itemID, n)
        return n
    end
    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
    local e = GuildERPData.items[itemID]
    return e and e.name
end

local function ItemIcon(itemID)
    if not itemID then
        return nil
    end
    if C_Item and C_Item.GetItemIconByID then
        local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
        if ok and icon then
            return icon
        end
    end
    if GetItemIcon then
        local ok, icon = pcall(GetItemIcon, itemID)
        if ok and icon then
            return icon
        end
    end
    local e = GuildERPData.items[itemID]
    return e and e.icon
end

local function ItemQualitaet(itemID)
    if not itemID then
        return nil
    end
    local q
    if C_Item and C_Item.GetItemQualityByID then
        local ok, w = pcall(C_Item.GetItemQualityByID, itemID)
        if ok and type(w) == "number" then
            q = w
        end
    end
    if not q and GetItemInfo then
        local ok, _, _, w = pcall(GetItemInfo, itemID)
        if ok and type(w) == "number" then
            q = w
        end
    end
    if q then
        ItemMerken(itemID, nil, nil, q)
        return q
    end
    local e = GuildERPData.items[itemID]
    return e and e.q
end

local function Geld(kupfer)
    if not kupfer or kupfer <= 0 then
        return ""
    end
    local g, s, c = math.floor(kupfer / 10000), math.floor(kupfer / 100) % 100, kupfer % 100
    local teile = {}
    if g > 0 then
        table.insert(teile, g .. " Gold")
    end
    if s > 0 then
        table.insert(teile, s .. " Silber")
    end
    if c > 0 then
        table.insert(teile, c .. " Kupfer")
    end
    return table.concat(teile, " ")
end

local function Alter(zeitpunkt, live)
    if live then
        return "jetzt"
    end
    if not zeitpunkt then
        return "Stand unbekannt"
    end
    local s = time() - zeitpunkt
    if s < 120 then
        return "gerade eben"
    elseif s < 3600 then
        return "vor " .. math.floor(s / 60) .. " Min."
    elseif s < 86400 then
        return "vor " .. math.floor(s / 3600) .. " Std."
    end
    local tage = math.floor(s / 86400)
    return tage == 1 and "vor 1 Tag" or ("vor " .. tage .. " Tagen")
end

local function Ort()
    local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
    local x, y
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local karte = C_Map.GetBestMapForUnit("player")
        if karte then
            local position = C_Map.GetPlayerMapPosition(karte, "player")
            if position then
                local px, py = position:GetXY()
                if px and py then
                    x = math.floor(px * 1000 + 0.5) / 10
                    y = math.floor(py * 1000 + 0.5) / 10
                end
            end
        end
    end
    return zone, x, y
end

local function NpcFraktion()
    if not UnitExists or not UnitExists("npc") then
        return nil
    end
    local fraktion = UnitFactionGroup and UnitFactionGroup("npc")
    if fraktion == "Alliance" or fraktion == "Horde" then
        return fraktion
    end
    if UnitReaction and UnitReaction("npc", "player") then
        return "Neutral"
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Bestand: Taschen (immer) und Bank (nur solange DU das Bankfenster offen hast).
-- Dabei werden auch Namen und Symbole der Gegenstaende gemerkt.
-- ---------------------------------------------------------------------------
local function FaecherZahl(beutel)
    if C_Container and C_Container.GetContainerNumSlots then
        local ok, n = pcall(C_Container.GetContainerNumSlots, beutel)
        if ok then
            return n or 0
        end
    end
    if GetContainerNumSlots then
        local ok, n = pcall(GetContainerNumSlots, beutel)
        if ok then
            return n or 0
        end
    end
    return 0
end

local function FachInhalt(beutel, fach)
    if C_Container and C_Container.GetContainerItemInfo then
        local ok, info = pcall(C_Container.GetContainerItemInfo, beutel, fach)
        if ok then
            if type(info) == "table" and info.itemID then
                local name = info.itemName or (type(info.hyperlink) == "string" and string.match(info.hyperlink, "|h%[(.-)%]|h"))
                ItemMerken(info.itemID, name, info.iconFileID, info.quality)
                return info.itemID, info.stackCount or 1
            end
            return nil
        end
    end
    if GetContainerItemInfo then
        local ok, icon, anzahl, _, q, _, _, link, _, _, id = pcall(GetContainerItemInfo, beutel, fach)
        if ok then
            id = id or ItemIDAusLink(link)
            if not id and GetContainerItemID then
                id = GetContainerItemID(beutel, fach)
            end
            if id then
                ItemMerken(id, type(link) == "string" and string.match(link, "|h%[(.-)%]|h"), icon, q)
                return id, anzahl or 1
            end
        end
    end
    return nil
end

local function BeutelLesen(liste)
    local inhalt = {}
    for _, b in ipairs(liste) do
        for f = 1, FaecherZahl(b) do
            local id, n = FachInhalt(b, f)
            if id then
                inhalt[id] = (inhalt[id] or 0) + n
            end
        end
    end
    return inhalt
end

local function TaschenLesen()
    local c = Charakter()
    if not c then
        return
    end
    local liste = {}
    for b = 0, (NUM_BAG_SLOTS or 4) do
        table.insert(liste, b)
    end
    c.bags = BeutelLesen(liste)
    c.bagsAt = time()
end

local bankOffen = false
local function BankLesen()
    if not bankOffen then
        return
    end
    local c = Charakter()
    if not c then
        return
    end
    local liste = { BANK_CONTAINER or -1 }
    local erste = (NUM_BAG_SLOTS or 4) + 1
    for b = erste, erste + (NUM_BANKBAGSLOTS or 6) - 1 do
        table.insert(liste, b)
    end
    c.bank = BeutelLesen(liste)
    c.bankAt = time()
end

-- ---------------------------------------------------------------------------
-- Rezepte und Zutaten: nur lesbar, solange DU das Berufefenster offen hast.
-- ---------------------------------------------------------------------------
local function RezeptErgebnis(rezeptID)
    if not rezeptID or not C_TradeSkillUI then
        return nil
    end
    if C_TradeSkillUI.GetRecipeOutputItemData then
        local ok, daten = pcall(C_TradeSkillUI.GetRecipeOutputItemData, rezeptID)
        if ok and type(daten) == "table" then
            if daten.itemID then
                return daten.itemID
            end
            local id = ItemIDAusLink(daten.hyperlink)
            if id then
                return id
            end
        end
    end
    if C_TradeSkillUI.GetRecipeItemLink then
        local ok, link = pcall(C_TradeSkillUI.GetRecipeItemLink, rezeptID)
        if ok then
            return ItemIDAusLink(link)
        end
    end
    return nil
end

local function Zutaten(rezeptID)
    local T = C_TradeSkillUI
    if T.GetRecipeSchematic then
        local ok, s = pcall(T.GetRecipeSchematic, rezeptID, false)
        if ok and type(s) == "table" and type(s.reagentSlotSchematics) == "table" then
            local liste = {}
            for _, slot in ipairs(s.reagentSlotSchematics) do
                local r = slot.reagents and slot.reagents[1]
                local pflicht = slot.required ~= false and (slot.reagentType == nil or slot.reagentType == 1)
                if r and r.itemID and pflicht then
                    ItemName(r.itemID) -- Namen merken bzw. beim Spiel anfordern
                    table.insert(liste, { itemID = r.itemID, count = slot.quantityRequired or 1 })
                end
            end
            if #liste > 0 then
                return liste, "schematic", s.quantityMin
            end
        end
    end
    if T.GetRecipeNumReagents and T.GetRecipeReagentInfo then
        local ok, n = pcall(T.GetRecipeNumReagents, rezeptID)
        if ok and n and n > 0 then
            local liste = {}
            for i = 1, n do
                local ok2, name, icon, anzahl = pcall(T.GetRecipeReagentInfo, rezeptID, i)
                local id
                if T.GetRecipeReagentItemLink then
                    local ok3, link = pcall(T.GetRecipeReagentItemLink, rezeptID, i)
                    if ok3 then
                        id = ItemIDAusLink(link)
                    end
                end
                if ok2 and id then
                    ItemMerken(id, name, icon)
                    table.insert(liste, { itemID = id, count = anzahl or 1 })
                end
            end
            if #liste == n then
                return liste, "reagentinfo"
            end
            return nil, "unvollstaendig"
        end
    end
    return nil, "keinweg"
end

local function StueckJeHerstellung(rezeptID, ausSchema)
    if ausSchema and ausSchema > 0 then
        return ausSchema
    end
    if C_TradeSkillUI.GetRecipeNumItemsProduced then
        local ok, minimum = pcall(C_TradeSkillUI.GetRecipeNumItemsProduced, rezeptID)
        if ok and minimum and minimum > 0 then
            return minimum
        end
    end
    return 1
end

local nochmalLesen = false
local function RezepteLesen()
    if not C_TradeSkillUI or not C_TradeSkillUI.GetAllRecipeIDs then
        return false
    end
    local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
    if not ok or type(ids) ~= "table" or #ids == 0 then
        return false
    end
    local c = Charakter()
    if not c then
        return false
    end
    local d = Daten()
    local beruf, berufID, eltern
    if C_TradeSkillUI.GetTradeSkillLineForRecipe then
        local ok2, linie, name, oben = pcall(C_TradeSkillUI.GetTradeSkillLineForRecipe, ids[1])
        if ok2 then
            beruf = name
            berufID = linie
            eltern = oben
        end
    end
    if not beruf then
        return false
    end
    -- ab 1.1.8: nur das EIGENE Berufefenster lesen - nicht verlinkte Berufe anderer Spieler
    -- (Klick auf einen Berufe-Link im Chat), Gilden-Ansicht oder Handwerker-NPCs
    if Kat.FremdesFenster() then
        d.diagnostics.fremdesFenster = beruf .. " " .. date("%Y-%m-%d %H:%M")
        return false
    end
    local meine = Kat.MeineBerufe()
    if meine and meine.n > 0 and Kat.IstHaupt(beruf, berufID, eltern)
        and not (meine.namen[beruf] or meine.linien[berufID] or meine.linien[eltern]) then
        d.diagnostics.fremdesFenster = beruf .. " (nicht gelernt) " .. date("%Y-%m-%d %H:%M")
        return false
    end
    local bekannt, anzahl, offen, weg = {}, 0, 0, nil
    for _, id in ipairs(ids) do
        local ok3, info = pcall(C_TradeSkillUI.GetRecipeInfo, id)
        if ok3 and type(info) == "table" and info.learned then
            bekannt[id] = true
            anzahl = anzahl + 1
            local e = d.recipes[id] or {}
            e.name = info.name or e.name
            e.icon = info.icon or e.icon
            e.profession = beruf
            e.professionID = berufID or e.professionID
            e.itemID = RezeptErgebnis(id) or e.itemID
            if e.itemID then
                ItemName(e.itemID)
            end
            e.kategorie = Kat.SpielKategorie(info) or e.kategorie
            local liste, w, stueck = Zutaten(id)
            if liste then
                e.reagents = liste
                e.numMade = StueckJeHerstellung(id, stueck)
                e.at = time()
                weg = weg or w
            else
                offen = offen + 1
                d.diagnostics.zutatenFehler = (info.name or id) .. ": " .. tostring(w)
            end
            d.recipes[id] = e
        end
    end
    if anzahl == 0 then
        return false
    end
    Kat.AlteKategorien(bekannt)
    c.recipes[beruf] = bekannt
    d.diagnostics.zutatenWeg = weg
    d.diagnostics.letzterBeruf = beruf .. " (" .. anzahl .. " Rezepte, " .. offen .. " ohne Zutaten) " .. date("%Y-%m-%d %H:%M")
    if offen > 0 and not nochmalLesen then
        nochmalLesen = true
        O.Nach(3, function()
            RezepteLesen()
            nochmalLesen = false
        end)
    end
    return true, beruf, anzahl
end

-- ---------------------------------------------------------------------------
-- "Im Berufefenster öffnen": nur auf Klick des Spielers. Oeffnet das normale
-- Berufefenster, waehlt das Rezept an und traegt die Anzahl ein. Hergestellt wird
-- NICHT - das klickt der Spieler im Berufefenster selbst.
-- ---------------------------------------------------------------------------
local offenerAuftrag
local function BerufefensterVorwaehlen()
    local a = offenerAuftrag
    if not a then
        return false
    end
    if time() > a.bis then
        offenerAuftrag = nil
        return false
    end
    local weg
    if ProfessionsFrame and ProfessionsFrame.IsShown and ProfessionsFrame:IsShown()
        and C_TradeSkillUI and C_TradeSkillUI.OpenRecipe then
        pcall(C_TradeSkillUI.OpenRecipe, a.rezeptID)
        local seite = ProfessionsFrame.CraftingPage
        local box = seite and seite.CreateMultipleInputBox
        if box and box.SetValue then
            pcall(box.SetValue, box, a.anzahl)
        end
        weg = "ProfessionsFrame"
    elseif TradeSkillFrame and TradeSkillFrame.IsShown and TradeSkillFrame:IsShown()
        and GetNumTradeSkills and GetTradeSkillInfo then
        if ExpandTradeSkillSubClass then
            pcall(ExpandTradeSkillSubClass, 0)
        end
        for i = 1, (GetNumTradeSkills() or 0) do
            local name, art = GetTradeSkillInfo(i)
            if name == a.name and art ~= "header" then
                if TradeSkillFrame_SetSelection then
                    pcall(TradeSkillFrame_SetSelection, i)
                elseif SelectTradeSkill then
                    pcall(SelectTradeSkill, i)
                end
                if TradeSkillListScrollFrame and FauxScrollFrame_SetOffset then
                    local versatz = math.max(0, i - 4)
                    pcall(FauxScrollFrame_SetOffset, TradeSkillListScrollFrame, versatz)
                    local leiste = _G["TradeSkillListScrollFrameScrollBar"]
                    if leiste and leiste.SetValue and TRADE_SKILL_HEIGHT then
                        pcall(leiste.SetValue, leiste, versatz * TRADE_SKILL_HEIGHT)
                    end
                end
                if TradeSkillFrame_Update then
                    pcall(TradeSkillFrame_Update)
                end
                if TradeSkillInputBox and TradeSkillInputBox.SetNumber then
                    pcall(TradeSkillInputBox.SetNumber, TradeSkillInputBox, a.anzahl)
                end
                weg = "TradeSkillFrame"
                break
            end
        end
    end
    if weg then
        Daten().diagnostics.berufefenster = weg .. " " .. date("%Y-%m-%d %H:%M")
        offenerAuftrag = nil
        return true
    end
    return false
end

local function BerufefensterOeffnen(rezeptID, anzahl)
    local r = GuildERPData.recipes[rezeptID]
    if not r then
        return
    end
    offenerAuftrag = { rezeptID = rezeptID, name = r.name, anzahl = anzahl, bis = time() + 60 }
    if BerufefensterVorwaehlen() then
        return -- Fenster war schon offen
    end
    local geoeffnet = false
    if C_TradeSkillUI and C_TradeSkillUI.OpenRecipe then
        geoeffnet = pcall(C_TradeSkillUI.OpenRecipe, rezeptID)
    end
    if not geoeffnet and C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill and r.professionID then
        geoeffnet = pcall(C_TradeSkillUI.OpenTradeSkill, r.professionID)
    end
    O.Nach(0.6, function()
        if offenerAuftrag and not BerufefensterVorwaehlen() then
            Daten().diagnostics.berufefenster = "selbst oeffnen " .. date("%Y-%m-%d %H:%M")
            Melden("Öffne jetzt dein Berufefenster (" .. (r.profession or "") .. "). Guild ERP wählt dann "
                .. (r.name or "das Rezept") .. " aus und trägt " .. anzahl .. " ein.")
        end
    end)
end

local rezepteWarten = false
local function RezepteSpaeterLesen()
    if rezepteWarten then
        return
    end
    rezepteWarten = true
    O.Nach(1.5, function()
        rezepteWarten = false
        local ok, beruf, anzahl = RezepteLesen()
        if ok then
            local d = Daten()
            local schon = d.settings.gemeldet or {}
            d.settings.gemeldet = schon
            local _, s = Charakter()
            local merk = (s or "?") .. ":" .. beruf .. ":" .. anzahl
            if not schon[merk] then
                schon[merk] = true
                Melden(beruf .. ": " .. anzahl .. (anzahl == 1 and " Rezept" or " Rezepte") .. " mit Zutaten gemerkt.")
            end
            if FensterAktualisieren then
                FensterAktualisieren()
            end
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Haendler: merkt sich, wo es ZUTATEN zu kaufen gibt. Es wird nichts gekauft.
-- ---------------------------------------------------------------------------
local function HaendlerLesen()
    if not GetMerchantNumItems then
        return
    end
    local d = Daten()
    local zutaten = {}
    for _, r in pairs(d.recipes) do
        for _, z in ipairs(r.reagents or {}) do
            zutaten[z.itemID] = true
        end
    end
    local haendler = UnitName("npc") or "Händler"
    local zone, x, y = Ort()
    local fraktion = NpcFraktion()
    local anzahl = 0
    for i = 1, (GetMerchantNumItems() or 0) do
        local id = GetMerchantItemLink and ItemIDAusLink(GetMerchantItemLink(i))
        if id and zutaten[id] then
            local preis, stapel
            if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
                local ok, info = pcall(C_MerchantFrame.GetItemInfo, i)
                if ok and type(info) == "table" then
                    preis, stapel = info.price, info.stackCount
                    ItemMerken(id, info.name)
                end
            end
            if not preis and GetMerchantItemInfo then
                local name, _, p, q = GetMerchantItemInfo(i)
                preis, stapel = p, q
                ItemMerken(id, name)
            end
            local v = d.vendors[id] or {}
            v[haendler] = { zone = zone, x = x, y = y, price = preis, stack = stapel, faction = fraktion, at = time() }
            d.vendors[id] = v
            anzahl = anzahl + 1
        end
    end
    if anzahl > 0 then
        Melden(haendler .. ": " .. anzahl .. (anzahl == 1 and " Zutat" or " Zutaten") .. " zum Kaufen gemerkt.")
    end
end

-- ---------------------------------------------------------------------------
-- Bedarfsrechnung (wie eine Stuecklistenaufloesung im MRP)
-- ---------------------------------------------------------------------------
local function BestandSammeln(fraktion)
    local d = Daten()
    local eigen = CharakterSchluessel()
    local pool = {}
    local function dazu(id, quelle)
        pool[id] = pool[id] or {}
        table.insert(pool[id], quelle)
    end
    for s, c in pairs(d.characters) do
        if c.faction == fraktion then
            local ich = s == eigen
            for id, n in pairs(c.bags or {}) do
                dazu(id, { wer = c.name, wo = "Tasche", n = n, at = c.bagsAt, live = ich, rang = ich and 1 or 3 })
            end
            for id, n in pairs(c.bank or {}) do
                dazu(id, { wer = c.name, wo = "Bank", n = n, at = c.bankAt, rang = ich and 2 or 4 })
            end
        end
    end
    for _, liste in pairs(pool) do
        table.sort(liste, function(a, b)
            if a.rang ~= b.rang then
                return a.rang < b.rang
            end
            if a.n ~= b.n then
                return a.n > b.n
            end
            return (a.wer or "") < (b.wer or "")
        end)
    end
    return pool
end

-- hersteller[itemID] = { {rezeptID, wer = {Namen}} }, rezepte[rezeptID] = { wer = {Namen} },
-- berufe[Beruf] = { Namen }
local function HerstellerSammeln(fraktion)
    local d = Daten()
    local hersteller, rezepte, berufe = {}, {}, {}
    for _, c in pairs(d.characters) do
        if c.faction == fraktion then
            for beruf, ids in pairs(c.recipes or {}) do
                local anzahl = 0
                for id in pairs(ids) do
                    local r = d.recipes[id]
                    if r and r.reagents then
                        anzahl = anzahl + 1
                        rezepte[id] = rezepte[id] or { wer = {} }
                        table.insert(rezepte[id].wer, c.name)
                        if r.itemID then
                            hersteller[r.itemID] = hersteller[r.itemID] or {}
                            local eintrag
                            for _, h in ipairs(hersteller[r.itemID]) do
                                if h.rezeptID == id then
                                    eintrag = h
                                end
                            end
                            if not eintrag then
                                eintrag = { rezeptID = id, wer = {} }
                                table.insert(hersteller[r.itemID], eintrag)
                            end
                            table.insert(eintrag.wer, c.name)
                        end
                    end
                end
                if anzahl > 0 then
                    berufe[beruf] = berufe[beruf] or {}
                    table.insert(berufe[beruf], { name = c.name, n = anzahl })
                end
            end
        end
    end
    for _, r in pairs(rezepte) do
        table.sort(r.wer)
    end
    for _, liste in pairs(hersteller) do
        for _, h in ipairs(liste) do
            table.sort(h.wer)
        end
    end
    for _, liste in pairs(berufe) do
        table.sort(liste, function(a, b) return a.name < b.name end)
    end
    return hersteller, rezepte, berufe
end

-- Wer stellt her? Gewaehlt in dieser Sitzung, sonst der gerade gespielte Charakter, sonst der erste.
local function HerstellerVon(rezeptID, wer)
    local gewaehlt = wahlHersteller[rezeptID]
    local ich = UnitName("player")
    local istIch = false
    for _, n in ipairs(wer or {}) do
        if n == gewaehlt then
            return gewaehlt
        end
        if n == ich then
            istIch = true
        end
    end
    if istIch then
        return ich
    end
    return wer and wer[1]
end

local function Aufloesen(itemID, bedarf, pool, hersteller, tiefe, besucht)
    local zeile = { itemID = itemID, bedarf = bedarf, quellen = {} }
    local rest = bedarf
    for _, q in ipairs(pool[itemID] or {}) do
        if rest <= 0 then
            break
        end
        local frei = q.n - (q.genutzt or 0)
        if frei > 0 then
            local nimm = math.min(frei, rest)
            q.genutzt = (q.genutzt or 0) + nimm
            table.insert(zeile.quellen, { wer = q.wer, wo = q.wo, n = nimm, at = q.at, live = q.live })
            if q.live then
                zeile.inTasche = (zeile.inTasche or 0) + nimm
            end
            rest = rest - nimm
        end
    end
    zeile.da = bedarf - rest
    zeile.inTasche = zeile.inTasche or 0
    if rest <= 0 then
        zeile.rest = 0
        zeile.status = "gruen"
        zeile.tasche = zeile.inTasche >= bedarf
        return zeile
    end
    -- Planauftrag: zugesagte (noch nicht gelieferte) Mengen verringern den Bedarf
    local zu = pool.zu and pool.zu[itemID]
    if zu then
        zeile.zusagen = {}
        for _, s in ipairs(zu.liste) do
            local frei = s.n - (s.genutzt or 0)
            if frei > 0 and rest > 0 then
                local nimm = math.min(frei, rest)
                s.genutzt = (s.genutzt or 0) + nimm
                table.insert(zeile.zusagen, { wer = s.wer, n = nimm, weg = s.weg, mit = s.mit })
                zeile.zugesagt = (zeile.zugesagt or 0) + nimm
                rest = rest - nimm
            end
        end
        zeile.geliefert = zu.geliefert
        local offen = zu.bestellt - (zu.genutzt or 0)
        if offen > 0 and rest > 0 then
            zeile.bestellt = math.min(offen, rest)
            zu.genutzt = (zu.genutzt or 0) + zeile.bestellt
        end
    end
    zeile.rest = rest
    if rest <= 0 then
        zeile.status = "blau"
        return zeile
    end
    local h = hersteller[itemID] and hersteller[itemID][1]
    local r = h and GuildERPData.recipes[h.rezeptID]
    if r and tiefe < K.MAX_TIEFE and not besucht[itemID] then
        local laeufe = math.ceil(rest / (r.numMade or 1))
        zeile.rezeptID, zeile.wer, zeile.laeufe = h.rezeptID, h.wer, laeufe
        zeile.kinder = {}
        besucht[itemID] = true
        local alleOk = true
        for _, z in ipairs(r.reagents) do
            local kind = Aufloesen(z.itemID, z.count * laeufe, pool, hersteller, tiefe + 1, besucht)
            table.insert(zeile.kinder, kind)
            if kind.status == "rot" then
                alleOk = false
            end
        end
        besucht[itemID] = nil
        zeile.status = alleOk and "gelb" or "rot"
    else
        zeile.status = "rot"
    end
    return zeile
end

local function Stueckliste(rezeptID, menge, fraktion)
    local r = GuildERPData.recipes[rezeptID]
    if not r or not r.reagents then
        return nil
    end
    local pool = BestandSammeln(fraktion)
    pool.zu = P.Zusagen(rezeptID)
    local hersteller = HerstellerSammeln(fraktion)
    local laeufe = math.ceil(menge / (r.numMade or 1))
    local besucht = {}
    if r.itemID then
        besucht[r.itemID] = true
    end
    local liste = {}
    for _, z in ipairs(r.reagents) do
        table.insert(liste, Aufloesen(z.itemID, z.count * laeufe, pool, hersteller, 1, besucht))
    end
    return liste, laeufe
end

local function HaendlerFuer(itemID, fraktion)
    local liste = {}
    local hier = (GetRealZoneText and GetRealZoneText()) or ""
    for name, v in pairs(GuildERPData.vendors[itemID] or {}) do
        if not v.faction or v.faction == "Neutral" or v.faction == fraktion then
            table.insert(liste, { name = name, zone = v.zone, x = v.x, y = v.y, price = v.price, stack = v.stack, hier = v.zone == hier })
        end
    end
    table.sort(liste, function(a, b)
        if a.hier ~= b.hier then
            return a.hier
        end
        if (a.zone or "") ~= (b.zone or "") then
            return (a.zone or "") < (b.zone or "")
        end
        return a.name < b.name
    end)
    return liste
end

local function HaendlerText(h)
    local preis = h.price and h.price > 0 and Geld(math.floor(h.price / math.max(1, h.stack or 1))) or ""
    return h.name .. ", " .. (h.zone or "?") .. (h.x and (" (" .. h.x .. ", " .. h.y .. ")") or "")
        .. (preis ~= "" and ("  " .. preis .. " je Stück") or "")
end

-- ---------------------------------------------------------------------------
-- Reiseführer (falls installiert): zusaetzliche Quelle fuer noch nicht gelernte Rezepte.
-- Nur lesend. Fremde Fraktion wird ausgeblendet.
-- ---------------------------------------------------------------------------
local function Reisefuehrer()
    if type(ForeverDashboardData) == "table" then
        return ForeverDashboardData
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Eigene Quellen (ab 1.4): wo man noch nicht gelernte Rezepte bekommt. Guild ERP merkt sich
-- nur, was der Spieler selbst gesehen hat (Lehrer, Haendler, Beute), damit nichts vorweggenommen
-- wird. Nur lesen: nichts wird gelernt, gekauft oder aufgehoben, Filter im Lehrerfenster bleiben.
-- ---------------------------------------------------------------------------
K.LEHRER_ARTEN = { header = true, available = true, unavailable = true, used = true }

-- Der Lehrer bietet auch die naechste Berufsstufe an ("Kochgeselle"). Das ist kein Rezept, und das
-- Spiel gibt dafuer kein Merkmal her, darum am Namen erkennen (Ende des Namens, nur so ist
-- "Lagerfeuer des Gesellen" oder "Expertenlagerfeuer" nicht betroffen).
K.STUFEN_ENDEN = { "lehrling", "geselle", "gesellin", "experte", "expertin", "fachmann", "fachfrau", "handwerker",
    "handwerkerin", "meister", "meisterin" }

function Kat.IstStufe(name)
    local klein = string.lower(tostring(name or ""))
    for _, ende in ipairs(K.STUFEN_ENDEN) do
        if string.sub(klein, -#ende) == ende then
            return true
        end
    end
    return false
end

-- Faelschlich gemerkte Berufsstufen entfernen (einmal beim Start)
function Kat.QuellenAufraeumen()
    local quellen = Daten().quellen
    for name in pairs(quellen) do
        if Kat.IstStufe(name) then
            quellen[name] = nil
        end
    end
end

-- Neue Quelle anlegen oder bekannte auffrischen. Liefert true, wenn sie neu ist.
function Kat.QuelleMerken(rezept, q)
    local d = Daten()
    local liste = d.quellen[rezept] or {}
    d.quellen[rezept] = liste
    q.at = time()
    for i, alt in ipairs(liste) do
        if alt.art == q.art and alt.wer == q.wer and alt.zone == q.zone and alt.beruf == q.beruf then
            liste[i] = q
            return false
        end
    end
    table.insert(liste, q)
    return true
end

-- "Benötigt Schmiedekunst (50)" aus den Zeilen einer Beschreibung (Tooltip) lesen
function Kat.Berufswert(daten)
    for _, zeile in ipairs(type(daten) == "table" and daten.lines or {}) do
        local text = zeile.leftText
        if type(text) == "string" then
            local beruf, wert = string.match(text, "^Benötigt (.-) %((%d+)%)")
            if not beruf then
                beruf, wert = string.match(text, "^Requires (.-) %((%d+)%)")
            end
            if beruf then
                return beruf, tonumber(wert)
            end
        end
    end
    return nil
end

-- Beschreibung ueber die Schnittstelle "funktion(index)" holen, sonst ueber den Gegenstands-Link
function Kat.Beschreibung(funktion, index, link)
    if not C_TooltipInfo then
        return nil
    end
    if C_TooltipInfo[funktion] then
        local ok, daten = pcall(C_TooltipInfo[funktion], index)
        if ok and daten then
            return daten
        end
    end
    if link and C_TooltipInfo.GetHyperlink then
        local ok, daten = pcall(C_TooltipInfo.GetHyperlink, link)
        if ok then
            return daten
        end
    end
    return nil
end

-- Rezept-Gegenstand erkennen ("Pläne: Kupferkettengürtel"). Liefert Rezeptname, Beruf, Fertigkeit.
function Kat.RezeptGegenstand(name, link, daten)
    local rezept = type(name) == "string" and string.match(name, "^[^:]+:%s*(.+)$")
    if not rezept then
        return nil
    end
    local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if link and info then
        local klasse = select(6, info(link))
        if klasse and klasse ~= 9 then -- 9 = Rezept
            return nil
        end
    end
    local beruf, wert = Kat.Berufswert(daten)
    if not beruf then
        return nil
    end
    return rezept, beruf, wert
end

function Kat.LehrerLesen()
    if not GetNumTrainerServices or not GetTrainerServiceInfo then
        return
    end
    local lehrer = UnitName("npc") or UnitName("target")
    if not lehrer then
        return
    end
    local zone, x, y = Ort()
    local fraktion = NpcFraktion()
    local neu = 0
    for i = 1, (GetNumTrainerServices() or 0) do
        -- je nach Spielversion steht die Art ("header", "available" ...) an 2. oder 3. Stelle
        local name, a, b = GetTrainerServiceInfo(i)
        local art = K.LEHRER_ARTEN[a] and a or b
        if name and art ~= "header" then
            local beruf, wert
            if GetTrainerServiceSkillReq then
                beruf, wert = GetTrainerServiceSkillReq(i)
            end
            if not beruf or beruf == "" or not wert then
                beruf, wert = Kat.Berufswert(Kat.Beschreibung("GetTrainerService", i))
            end
            -- ohne Berufswert ist es eine Klassen- oder Waffenfaehigkeit: gehoert nicht hierher
            if beruf and beruf ~= "" and wert and not Kat.IstStufe(name) then
                local kosten = GetTrainerServiceCost and GetTrainerServiceCost(i) or nil
                if Kat.QuelleMerken(name, { art = "Lehrer", wer = lehrer, zone = zone, x = x, y = y,
                    kosten = kosten, skill = wert, beruf = beruf, fraktion = fraktion }) then
                    neu = neu + 1
                end
            end
        end
    end
    if neu > 0 then
        Melden(lehrer .. ": " .. neu .. (neu == 1 and " Rezept" or " Rezepte") .. " zum Lernen gemerkt.")
    end
end

function Kat.HaendlerRezepteLesen()
    if not GetMerchantNumItems or not GetMerchantItemLink then
        return
    end
    local haendler = UnitName("npc") or UnitName("target")
    if not haendler then
        return
    end
    local zone, x, y = Ort()
    local fraktion = NpcFraktion()
    local neu = 0
    for i = 1, (GetMerchantNumItems() or 0) do
        local name, preis
        if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
            local ok, info = pcall(C_MerchantFrame.GetItemInfo, i)
            if ok and type(info) == "table" then
                name, preis = info.name, info.price
            end
        end
        if not name and GetMerchantItemInfo then
            local n, _, p = GetMerchantItemInfo(i)
            name, preis = n, p
        end
        local link = GetMerchantItemLink(i)
        local rezept, beruf, wert = Kat.RezeptGegenstand(name, link, Kat.Beschreibung("GetMerchantItem", i, link))
        if rezept and Kat.QuelleMerken(rezept, { art = "Händler", wer = haendler, zone = zone, x = x, y = y,
            kosten = preis, skill = wert, beruf = beruf, fraktion = fraktion }) then
            neu = neu + 1
        end
    end
    if neu > 0 then
        Melden(haendler .. ": " .. neu .. (neu == 1 and " Rezept" or " Rezepte") .. " zum Kaufen gemerkt.")
    end
end

-- Von wem stammt die Beute in diesem Platz? Liest nur Name und Kennung.
function Kat.BeuteHerkunft(platz)
    local guid = GetLootSourceInfo and GetLootSourceInfo(platz)
    local art = type(guid) == "string" and string.match(guid, "^(%a+)") or nil
    if art == "GameObject" then
        return "Behälter"
    elseif art == "Item" then
        return "Gegenstand (geöffnet)"
    end
    for _, einheit in ipairs({ "target", "mouseover" }) do
        if guid and UnitGUID and UnitGUID(einheit) == guid then
            return UnitName(einheit)
        end
    end
    if UnitExists and UnitExists("target") and UnitIsDead and UnitIsDead("target") then
        return UnitName("target")
    end
    return "Unbekannter Gegner"
end

function Kat.BeuteLesen()
    if not GetNumLootItems or not GetLootSlotLink then
        return
    end
    local zone, x, y = Ort()
    for platz = 1, (GetNumLootItems() or 0) do
        local link = GetLootSlotLink(platz)
        if link then
            local _, name = GetLootSlotInfo(platz)
            name = name or string.match(link, "%[(.-)%]")
            local rezept, beruf, wert = Kat.RezeptGegenstand(name, link, Kat.Beschreibung("GetLootItem", platz, link))
            if rezept then
                local wer = Kat.BeuteHerkunft(platz)
                -- Beute gibt es fuer beide Seiten: darum ohne Fraktion
                if Kat.QuelleMerken(rezept, { art = "Beute", wer = wer, zone = zone, x = x, y = y,
                    skill = wert, beruf = beruf }) then
                    Melden("Rezept gefunden: " .. name .. " von " .. tostring(wer) .. ", gemerkt.")
                end
            end
        end
    end
end

-- Option "ungelernt": auch Berufe zeigen, in denen noch kein eigener Charakter etwas kann,
-- aber schon eine Quelle gesehen wurde. Solche Berufe bekommen eine leere Namensliste.
function Kat.BerufeErgaenzen(berufe, fraktion)
    if not O.Wert("ungelernt") then
        return
    end
    local function dazu(beruf, f)
        if beruf and (not f or f == "Neutral" or f == fraktion) then
            berufe[beruf] = berufe[beruf] or {}
        end
    end
    for _, quellen in pairs(Daten().quellen) do
        for _, q in ipairs(quellen) do
            dazu(q.beruf, q.fraktion)
        end
    end
    local fd = Reisefuehrer()
    local katalog = fd and fd.catalog and fd.catalog.recipes
    for _, e in pairs(type(katalog) == "table" and katalog or {}) do
        if type(e) == "table" then
            dazu(e.profession, e.npcFaction)
        end
    end
end

function Kat.QuellenZahl()
    local zahl = 0
    for _ in pairs(Daten().quellen) do
        zahl = zahl + 1
    end
    return zahl
end

-- Fuer die Ereignisse: Fehler beim Lesen stoeren nie das Spiel, sie landen in der Diagnose
function Kat.QuellenLesen(lesen)
    local ok, fehler = pcall(lesen)
    if not ok then
        B.Diagnose("fehler", "Quellen", fehler)
        O.Fehler("Quellen", fehler)
    end
    Kat.VielleichtTeilen()
end

-- Namen der gelernten Rezepte eines Berufs (Rezeptname UND Name des Ergebnisses,
-- weil der Lehrer z. B. "Bronzebarren" statt "Bronze verhütten" anzeigt)
local function GelernteNamen(beruf, rezepte)
    local namen = {}
    for id in pairs(rezepte) do
        local r = GuildERPData.recipes[id]
        if r and r.profession == beruf then
            if r.name then
                namen[r.name] = true
            end
            local n = r.itemID and ItemName(r.itemID)
            if n then
                namen[n] = true
            end
        end
    end
    return namen
end

local function GraueRezepte(beruf, fraktion, gelernt)
    local fd = Reisefuehrer() or {} -- der Reisefuehrer ist nur eine zusaetzliche Quelle
    local nachName, liste = {}, {}
    local function eintrag(name)
        local e = nachName[name]
        if not e then
            e = { name = name, quellen = {}, grau = true }
            nachName[name] = e
            table.insert(liste, e)
        end
        return e
    end
    -- dieselbe Quelle kann aus beiden Sammlungen kommen, sie zaehlt nur einmal
    local function quelleDazu(name, q)
        if Kat.IstStufe(name) then
            return -- auch aus dem Katalog des Reisefuehrers
        end
        local e = eintrag(name)
        for _, alt in ipairs(e.quellen) do
            if alt.art == q.art and alt.wer == q.wer and alt.zone == q.zone then
                return
            end
        end
        table.insert(e.quellen, q)
    end
    local function sichtbar(f)
        return not f or f == "Neutral" or f == fraktion
    end
    for name, quellen in pairs(Daten().quellen) do
        if not gelernt[name] then
            for _, q in ipairs(quellen) do
                if q.beruf == beruf and sichtbar(q.fraktion) then
                    quelleDazu(name, {
                        art = q.art, wer = q.wer, zone = q.zone, x = q.x, y = q.y,
                        cost = q.kosten, skill = q.skill, von = q.von,
                    })
                end
            end
        end
    end
    local katalog = fd.catalog and fd.catalog.recipes
    for _, e in pairs(type(katalog) == "table" and katalog or {}) do
        if type(e) == "table" and e.profession == beruf and e.name and not gelernt[e.name] then
            if sichtbar(e.npcFaction) then
                quelleDazu(e.name, {
                    art = e.sourceType, wer = e.sourceName, zone = e.zone, x = e.x, y = e.y,
                    cost = e.cost, skill = e.requiredSkill,
                })
            end
        end
    end
    for _, c in pairs(type(fd.characters) == "table" and fd.characters or {}) do
        if type(c) == "table" and c.faction == fraktion then
            for _, s in pairs(c.recipeCollections or {}) do
                if s.professionName == beruf then
                    for _, r in ipairs(s.missing or {}) do
                        if r.name and not gelernt[r.name] then
                            local e = eintrag(r.name)
                            e.itemID = e.itemID or r.itemID
                        end
                    end
                end
            end
        end
    end
    -- Der Lehrer nennt oft das Ergebnis ("Echtsilberbarren"), das Berufefenster das Rezept
    -- ("Echtsilber verhütten"): ueber den hergestellten Gegenstand zusammenfuehren
    local doppelt = {}
    for _, e in ipairs(liste) do
        local n = e.itemID and ItemName(e.itemID)
        local anderer = n and n ~= e.name and nachName[n]
        if anderer and not doppelt[anderer] then
            for _, q in ipairs(anderer.quellen) do
                table.insert(e.quellen, q)
            end
            doppelt[anderer] = true
        end
    end
    if next(doppelt) then
        local rest = {}
        for _, e in ipairs(liste) do
            if not doppelt[e] then
                table.insert(rest, e)
            end
        end
        liste = rest
    end
    for _, e in ipairs(liste) do
        table.sort(e.quellen, function(a, b)
            if (a.art or "") ~= (b.art or "") then
                return (a.art or "") > (b.art or "") -- Lehrer vor Haendler
            end
            return (a.zone or "") < (b.zone or "")
        end)
    end
    return liste
end

-- ---------------------------------------------------------------------------
-- Bausteine fuer das Fenster
-- ---------------------------------------------------------------------------
K.BACKDROP_RAHMEN = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
    tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
}
K.BACKDROP_DUENN = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}
K.BACKDROP_VORLAGE = BackdropTemplateMixin and "BackdropTemplate" or nil

local function Schrift(eltern, vorlage, links)
    local fs = eltern:CreateFontString(nil, "OVERLAY", vorlage)
    fs:SetJustifyH(links == false and "RIGHT" or "LEFT")
    if fs.SetWordWrap then
        fs:SetWordWrap(true)
    end
    return fs
end

-- Flaeche mit duenner Kante: hell = Hintergrundfarbe, kante = Randfarbe
local function Flaeche(f, hg, kante)
    if f.SetBackdrop then
        if not f.lookHg then
            O.flaechen = O.flaechen or {}
            table.insert(O.flaechen, f)
        end
        f.lookHg, f.lookKante = hg, kante
        f:SetBackdrop(K.BACKDROP_DUENN)
        f:SetBackdropColor(hg[1], hg[2], hg[3], (hg[4] or 1) * (O.FlaecheAlpha and O.FlaecheAlpha(f) or 1))
        f:SetBackdropBorderColor(kante[1], kante[2], kante[3], kante[4] or 1)
    end
end

-- kleine Raute (Ampel)
local function Raute(eltern, groesse)
    local t = eltern:CreateTexture(nil, "ARTWORK")
    t:SetSize(groesse, groesse)
    t:SetTexture(K.WEISS)
    if t.SetRotation then
        pcall(t.SetRotation, t, math.pi / 4)
    end
    return t
end

local function Faerben(t, status)
    local rgb = K.STATUS_RGB[status]
    t:SetVertexColor(rgb[1], rgb[2], rgb[3], 1)
end

local function IstZu(schluessel)
    local zu = GuildERPData.settings.zu
    return zu and zu[schluessel] == true or false
end

local function Umklappen(schluessel)
    local s = Daten().settings
    s.zu = s.zu or {}
    s.zu[schluessel] = not IstZu(schluessel) or nil
end

-- Knopf, der eine Auswahlliste oeffnet (Text + Pfeil)
local function WahlKnopf(eltern, breite)
    local b = O.Rahmen("Button", nil, eltern, K.BACKDROP_VORLAGE)
    b:SetSize(breite, 26)
    Flaeche(b, { 0.07, 0.07, 0.09, 1 }, { 0.23, 0.21, 0.16, 1 })
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    hl:SetColorTexture(1, 1, 1, 0.07)
    b.text = Schrift(b, "GameFontHighlight")
    b.text:SetPoint("LEFT", 9, 0)
    b.text:SetPoint("RIGHT", -22, 0)
    if b.text.SetWordWrap then
        b.text:SetWordWrap(false)
    end
    b.pfeil = b:CreateTexture(nil, "ARTWORK")
    b.pfeil:SetSize(14, 14)
    b.pfeil:SetPoint("RIGHT", -5, 0)
    b.pfeil:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    if b.pfeil.SetRotation then
        b.pfeil:SetRotation(-math.pi / 2)
    end
    O.Teil(function(spiel) O.WahlLook(b, spiel) end)
    return b
end

-- ---------------------------------------------------------------------------
-- Gemeinsame Auswahlliste (klappt unter einem Knopf auf).
-- eintraege: { {wert=, text=, rechts=, icon=, gewaehlt=}, {kopf=, rechts=}, ... }
-- ---------------------------------------------------------------------------
local popup
local function PopupZu()
    if popup then
        popup:Hide()
    end
end

local function PopupZeigen(anker, breite, eintraege, waehlen, fussText)
    if popup and popup:IsShown() and popup.anker == anker then
        popup:Hide()
        return
    end
    if not popup then
        popup = O.Rahmen("Frame", "GuildERPAuswahl", UIParent, K.BACKDROP_VORLAGE)
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetClampedToScreen(true)
        popup:EnableMouse(true)
        Flaeche(popup, { 0.05, 0.05, 0.06, 0.98 }, { K.GOLD[1], K.GOLD[2], K.GOLD[3], 1 })
        popup.zeilen = {}
        popup.fuss = Schrift(popup, "GameFontDisableSmall")
        popup:Hide()
    end
    local p = popup
    p.anker = anker
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", anker, "BOTTOMLEFT", 0, -2)
    p:SetWidth(breite)
    local y = 6
    for i, e in ipairs(eintraege) do
        local z = p.zeilen[i]
        if not z then
            z = O.Rahmen("Button", nil, p)
            z:SetHeight(22)
            z.text = Schrift(z, "GameFontHighlight")
            z.rechts = Schrift(z, "GameFontHighlightSmall", false)
            z.rechts:SetPoint("RIGHT", -8, 0)
            z.text:SetPoint("LEFT", 8, 0)
            z.text:SetPoint("RIGHT", z.rechts, "LEFT", -6, 0)
            if z.text.SetWordWrap then
                z.text:SetWordWrap(false)
            end
            z.hg = z:CreateTexture(nil, "BACKGROUND")
            z.hg:SetAllPoints()
            z.hl = z:CreateTexture(nil, "HIGHLIGHT")
            z.hl:SetAllPoints()
            z.hl:SetColorTexture(1, 1, 1, 0.08)
            p.zeilen[i] = z
        end
        z:ClearAllPoints()
        z:SetPoint("TOPLEFT", 4, -y)
        z:SetPoint("RIGHT", -4, 0)
        if e.kopf then
            z.text:SetText(Farbe("c9a54c", e.kopf))
            z.rechts:SetText(e.rechts and Farbe("77715f", e.rechts) or "")
            z.hg:SetColorTexture(0, 0, 0, 0)
            z:SetScript("OnClick", nil)
            z:EnableMouse(false)
        else
            z:EnableMouse(true)
            z.text:SetText(e.text or "")
            z.rechts:SetText(e.rechts and Farbe("9a9384", e.rechts) or "")
            if e.gewaehlt then
                z.hg:SetColorTexture(0.16, 0.14, 0.08, 1)
            else
                z.hg:SetColorTexture(0, 0, 0, 0)
            end
            z:SetScript("OnClick", function()
                p:Hide()
                waehlen(e.wert)
                FensterAktualisieren()
            end)
        end
        z:Show()
        y = y + 22
    end
    for j = #eintraege + 1, #p.zeilen do
        p.zeilen[j]:Hide()
    end
    if fussText then
        p.fuss:ClearAllPoints()
        p.fuss:SetPoint("TOPLEFT", 12, -(y + 4))
        p.fuss:SetPoint("RIGHT", -12, 0)
        p.fuss:SetText(fussText)
        p.fuss:Show()
        y = y + 8 + (p.fuss:GetStringHeight() or 14)
    else
        p.fuss:Hide()
    end
    p:SetHeight(y + 6)
    p:Show()
end

-- Auswahl "wer stellt her" fuer ein Rezept
local function HerstellerWahl(anker, rezeptID, wer)
    local ich = UnitName("player")
    local aktuell = HerstellerVon(rezeptID, wer)
    local liste = {}
    for _, n in ipairs(wer or {}) do
        table.insert(liste, {
            wert = n,
            text = n .. (n == ich and Farbe("9a9384", " (du)") or ""),
            rechts = n == ich and "gerade eingeloggt" or "kennt das Rezept",
            gewaehlt = n == aktuell,
        })
    end
    PopupZeigen(anker, 260, liste, function(wert)
        wahlHersteller[rezeptID] = wert
    end, "Hier stehen alle deine Charaktere, die das Rezept kennen.")
end

-- ---------------------------------------------------------------------------
-- Zeilen im Rezeptbuch (links)
-- ---------------------------------------------------------------------------
local function RezeptZeileBauen(eltern)
    local z = O.Rahmen("Button", nil, eltern)
    z.hg = z:CreateTexture(nil, "BACKGROUND")
    z.hg:SetAllPoints()
    z.markierung = z:CreateTexture(nil, "ARTWORK")
    z.markierung:SetPoint("TOPLEFT")
    z.markierung:SetPoint("BOTTOMLEFT")
    z.markierung:SetWidth(2)
    z.markierung:SetColorTexture(K.GOLD[1], K.GOLD[2], K.GOLD[3], 1)
    z.linie = z:CreateTexture(nil, "BACKGROUND")
    z.linie:SetHeight(1)
    z.linie:SetPoint("BOTTOMLEFT")
    z.linie:SetPoint("BOTTOMRIGHT")
    z.linie:SetColorTexture(1, 1, 1, 0.05)
    local hl = z:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)
    z.hl, z.hlAlpha = hl, 0.06
    O.Teil(function(spiel) O.ZeileLook(z, spiel) end)
    z.icon = z:CreateTexture(nil, "ARTWORK")
    z.icon:SetSize(24, 24)
    z.icon:SetPoint("LEFT", 8, 0)
    z.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    z.rechts = Schrift(z, "GameFontHighlightSmall", false)
    z.rechts:SetPoint("RIGHT", -8, 0)
    z.rechts:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    z.name = Schrift(z, "GameFontHighlight")
    z.name:SetPoint("LEFT", z.icon, "RIGHT", 10, 0)
    z.name:SetPoint("RIGHT", z.rechts, "LEFT", -6, 0)
    if z.name.SetWordWrap then
        z.name:SetWordWrap(false)
    end
    z.hinweis = Schrift(z, "GameFontDisableSmall")
    z.hinweis:SetPoint("TOPLEFT", z.name, "BOTTOMLEFT", 0, -2)
    z.hinweis:SetPoint("RIGHT", z.rechts, "LEFT", -6, 0)
    if z.hinweis.SetWordWrap then
        z.hinweis:SetWordWrap(false)
    end
    z:SetScript("OnEnter", function(self)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.itemID then
            GameTooltip:SetHyperlink("item:" .. self.itemID)
        else
            GameTooltip:SetText(self.titel or "", 1, 1, 1)
        end
        if self.tip then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(self.tip, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    z:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    return z
end

-- ---------------------------------------------------------------------------
-- Zeilen der Stueckliste (rechts)
-- ---------------------------------------------------------------------------
local function ZeileBauen(eltern)
    local z = O.Rahmen("Button", nil, eltern)
    z.hg = z:CreateTexture(nil, "BACKGROUND")
    z.hg:SetAllPoints()
    local hl = z:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.04)
    z.linie = z:CreateTexture(nil, "BACKGROUND")
    z.linie:SetHeight(1)
    z.linie:SetPoint("BOTTOMLEFT", 0, 0)
    z.linie:SetPoint("BOTTOMRIGHT", 0, 0)
    z.linie:SetColorTexture(1, 1, 1, 0.06)
    z.knopf = z:CreateTexture(nil, "ARTWORK")
    z.knopf:SetSize(12, 12)
    z.punktGlanz = Raute(z, 15)
    z.punktGlanz:SetDrawLayer("BORDER")
    z.punktGlanz:SetBlendMode("ADD")
    z.punktGlanz:SetVertexColor(K.STATUS_RGB.tasche[1], K.STATUS_RGB.tasche[2], K.STATUS_RGB.tasche[3], 0.35)
    z.punkt = Raute(z, 8)
    z.bestellen = O.Rahmen("Button", nil, z, "UIPanelButtonTemplate")
    z.bestellen:SetSize(82, 20)
    z.bestellen:SetText("Bestellen")
    z.bestellen:Hide()
    z.icon = z:CreateTexture(nil, "ARTWORK")
    z.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    -- Leucht-Rahmen aus dem Spielclient (wie bei Aktionsleisten)
    z.glanz = z:CreateTexture(nil, "OVERLAY")
    z.glanz:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    z.glanz:SetBlendMode("ADD")
    z.glanz:SetVertexColor(K.STATUS_RGB.tasche[1], K.STATUS_RGB.tasche[2], K.STATUS_RGB.tasche[3], 0.95)
    z.glanz:SetPoint("CENTER", z.icon, "CENTER", 0, 0)
    z.chip = O.Rahmen("Frame", nil, z, K.BACKDROP_VORLAGE)
    z.chip:SetHeight(16)
    Flaeche(z.chip, { 0.36, 0.77, 0.42, 0.16 }, { 0.50, 0.94, 0.56, 0.45 })
    z.chip.text = Schrift(z.chip, "GameFontHighlightSmall")
    z.chip.text:SetPoint("LEFT", 6, 0)
    z.chip.text:SetTextColor(0.62, 0.95, 0.67)
    z.zahl = Schrift(z, "GameFontHighlightLarge", false)
    z.name = Schrift(z, "GameFontHighlight")
    z.quelle = Schrift(z, "GameFontHighlightSmall")
    z.quelle:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    -- "Die fehlenden 8 stellt her: Barlor (4x)" - anklickbar, oeffnet die Auswahl
    z.herst = O.Rahmen("Button", nil, z)
    z.herst:SetHeight(16)
    z.herst.text = Schrift(z.herst, "GameFontHighlightSmall")
    z.herst.text:SetPoint("LEFT", 0, 0)
    z.herst.text:SetTextColor(K.STATUS_RGB.gelb[1], K.STATUS_RGB.gelb[2], K.STATUS_RGB.gelb[3])
    z.herst.pfeil = z.herst:CreateTexture(nil, "ARTWORK")
    z.herst.pfeil:SetSize(11, 11)
    z.herst.pfeil:SetPoint("LEFT", z.herst.text, "RIGHT", 3, -1)
    z.herst.pfeil:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    if z.herst.pfeil.SetRotation then
        z.herst.pfeil:SetRotation(-math.pi / 2)
    end
    local hh = z.herst:CreateTexture(nil, "HIGHLIGHT")
    hh:SetAllPoints()
    hh:SetColorTexture(1, 1, 1, 0.08)
    z:SetScript("OnClick", function(self)
        if self.schluessel then
            Umklappen(self.schluessel)
            FensterAktualisieren()
        end
    end)
    z:SetScript("OnEnter", function(self)
        if not GameTooltip or not self.itemID then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. self.itemID)
        if self.tip and #self.tip > 0 then
            GameTooltip:AddLine(" ")
            for _, t in ipairs(self.tip) do
                GameTooltip:AddLine(t, 1, 0.82, 0, true)
            end
        end
        GameTooltip:Show()
    end)
    z:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    return z
end

local function Frei(liste, eltern, bauen)
    for _, el in ipairs(liste) do
        if not el.benutzt then
            el.benutzt = true
            return el
        end
    end
    local el = bauen(eltern)
    el.benutzt = true
    table.insert(liste, el)
    return el
end

local function QuellenText(quellen)
    local teile = {}
    for _, q in ipairs(quellen) do
        table.insert(teile, q.wer .. ", " .. q.wo .. (#quellen > 1 and (": " .. q.n) or "")
            .. (q.live and "" or ("  (" .. Alter(q.at) .. ")")))
    end
    return table.concat(teile, "  ·  ")
end

local function ZeileZeigen(f, zeile, tiefe, schluessel, fraktion)
    local z = Frei(f.zeilen, f.inhalt, ZeileBauen)
    z:ClearAllPoints()
    z:SetPoint("TOPLEFT", f.inhalt, "TOPLEFT", 0, -f.y)
    z:SetPoint("RIGHT", f.inhalt, "RIGHT", 0, 0)
    local x = 4 + (tiefe - 1) * 20
    local iconGr = tiefe == 1 and 30 or 24
    local tasche = zeile.tasche and true or false
    local farbe = tasche and "tasche" or zeile.status
    z.hg:SetColorTexture(1, 1, 1, tiefe > 1 and 0.025 or 0)
    z.knopf:ClearAllPoints()
    z.knopf:SetPoint("TOPLEFT", x, -12)
    z.punkt:ClearAllPoints()
    z.punkt:SetPoint("TOPLEFT", x + 18, -14)
    z.punktGlanz:ClearAllPoints()
    z.punktGlanz:SetPoint("CENTER", z.punkt, "CENTER", 0, 0)
    z.punktGlanz:SetShown(tasche)
    z.icon:ClearAllPoints()
    z.icon:SetSize(iconGr, iconGr)
    z.icon:SetPoint("TOPLEFT", x + 32, -6)
    z.glanz:SetSize(iconGr * 1.8, iconGr * 1.8)
    z.glanz:SetShown(tasche)
    z.zahl:ClearAllPoints()
    z.zahl:SetPoint("TOPRIGHT", -6, -9)
    z.name:ClearAllPoints()
    z.name:SetPoint("TOPLEFT", x + 32 + iconGr + 9, -7)
    z.name:SetPoint("RIGHT", z.zahl, "LEFT", -8, 0)
    if zeile.status == "rot" and zeile.rest > (zeile.bestellt or 0) then
        local itemID, rest, da = zeile.itemID, zeile.rest - (zeile.bestellt or 0), zeile.da
        z.bestellen:ClearAllPoints()
        z.bestellen:SetPoint("TOPRIGHT", -72, -9)
        z.bestellen:SetScript("OnClick", function()
            B.ScheinOeffnen({ { itemID = itemID, n = rest, an = true,
                hinweis = da > 0 and (da .. " hast du schon, " .. rest .. (rest == 1 and " fehlt" or " fehlen")) or "Fehlt ganz" } }, B.fuerText)
        end)
        z.bestellen:Show()
        z.name:SetPoint("RIGHT", z.bestellen, "LEFT", -8, 0)
    else
        z.bestellen:Hide()
    end

    z.schluessel = schluessel
    if schluessel then
        z.knopf:SetTexture(IstZu(schluessel) and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        z.knopf:Show()
    else
        z.knopf:Hide()
    end
    Faerben(z.punkt, farbe)
    z.icon:SetTexture(ItemIcon(zeile.itemID) or K.ICON_UNBEKANNT)
    local name = ItemName(zeile.itemID)
    z.name:SetText(name or Farbe("9a9384", "Name wird geladen …"))
    z.zahl:SetText(Farbe(K.STATUS_HEX[farbe], zeile.da) .. Farbe("77715f", " / " .. zeile.bedarf))

    -- Schild "In deiner Tasche"
    local unter = z.name
    local hoeheText = 7 + (z.name:GetStringHeight() or 14)
    if zeile.inTasche > 0 then
        z.chip.text:SetText(tasche and "In deiner Tasche" or (zeile.inTasche .. " in deiner Tasche"))
        z.chip:SetWidth((z.chip.text:GetStringWidth() or 90) + 12)
        z.chip:ClearAllPoints()
        z.chip:SetPoint("TOPLEFT", z.name, "BOTTOMLEFT", 0, -3)
        z.chip:Show()
        unter = z.chip
        hoeheText = hoeheText + 19
    else
        z.chip:Hide()
    end

    -- Unterzeile: was woanders liegt bzw. Haendler
    local tip = {}
    local andere = {}
    for _, q in ipairs(zeile.quellen) do
        if not q.live then
            table.insert(andere, q)
        end
    end
    local quelle = #andere > 0 and QuellenText(andere) or ""
    if zeile.status == "rot" and not zeile.wer then
        local h = HaendlerFuer(zeile.itemID, fraktion)
        local fehlt
        if #h > 0 then
            fehlt = "Händler: " .. HaendlerText(h[1]) .. (#h > 1 and ("  +" .. (#h - 1) .. " weitere") or "")
            if #h > 1 then
                table.insert(tip, "Erhältlich bei:")
                for _, e in ipairs(h) do
                    table.insert(tip, "  " .. HaendlerText(e))
                end
            end
        else
            fehlt = "Kein Händler bekannt"
        end
        quelle = quelle ~= "" and (quelle .. "\n" .. fehlt) or fehlt
    end
    local plan = P.ZusageText(zeile)
    if plan ~= "" then
        quelle = quelle ~= "" and (quelle .. "\n" .. plan) or plan
    end
    local ah = A.Text(zeile.itemID)
    if ah then
        quelle = quelle ~= "" and (quelle .. "\n" .. ah) or ah
    end
    z.quelle:ClearAllPoints()
    z.quelle:SetPoint("TOPLEFT", unter, "BOTTOMLEFT", 0, -2)
    z.quelle:SetPoint("RIGHT", z, "RIGHT", -6, 0)
    z.quelle:SetText(quelle)
    z.quelle:SetShown(quelle ~= "")
    if quelle ~= "" then
        unter = z.quelle
        hoeheText = hoeheText + 2 + (z.quelle:GetStringHeight() or 12)
    end
    z.itemID, z.tip = zeile.itemID, tip

    -- Herstellen: wer (waehlbar)
    if zeile.wer then
        local r = GuildERPData.recipes[zeile.rezeptID]
        local verb = (r and r.profession == "Bergbau") and "verhüttet" or "stellt her"
        local wer = HerstellerVon(zeile.rezeptID, zeile.wer)
        z.herst.text:SetText("Noch " .. zeile.rest .. " nötig – " .. verb .. ": " .. (wer or "?") .. "  (" .. zeile.laeufe .. "×)")
        z.herst:SetWidth((z.herst.text:GetStringWidth() or 200) + 16)
        z.herst:ClearAllPoints()
        z.herst:SetPoint("TOPLEFT", unter, "BOTTOMLEFT", 0, -2)
        local rezeptID, alle = zeile.rezeptID, zeile.wer
        z.herst:SetScript("OnClick", function(self)
            HerstellerWahl(self, rezeptID, alle)
        end)
        z.herst:Show()
        hoeheText = hoeheText + 18
    else
        z.herst:Hide()
    end

    local hoehe = math.max(iconGr + 12, hoeheText + 8)
    z:SetHeight(hoehe)
    z:Show()
    f.y = f.y + hoehe
end

local function ZweigZeigen(f, zeile, tiefe, pfad, fraktion)
    local schluessel = zeile.kinder and (pfad .. ">" .. zeile.itemID) or nil
    ZeileZeigen(f, zeile, tiefe, schluessel, fraktion)
    if zeile.kinder and not IstZu(schluessel) then
        for _, kind in ipairs(zeile.kinder) do
            ZweigZeigen(f, kind, tiefe + 1, schluessel, fraktion)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Fenster
-- ---------------------------------------------------------------------------
local function Liste(eltern)
    -- moderne, schmale Scrollleiste (wie im Spiel), sonst die alte Vorlage
    local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, eltern, "ScrollFrameTemplate")
    if not ok or not scroll then
        scroll = O.Rahmen("ScrollFrame", nil, eltern, "UIPanelScrollFrameTemplate")
    end
    local inhalt = O.Rahmen("Frame", nil, scroll)
    inhalt:SetSize(10, 10)
    scroll:SetScrollChild(inhalt)
    scroll:SetScript("OnSizeChanged", function(self, w)
        if w and w > 0 then
            inhalt:SetWidth(w)
        end
    end)
    return scroll, inhalt
end

local function FensterBauen()
    local d = Daten()
    local f = O.Rahmen("Frame", "GuildERPFenster", UIParent, K.BACKDROP_VORLAGE)
    f:SetSize(900, 680)
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    if f.SetBackdrop then
        f:SetBackdrop(K.BACKDROP_RAHMEN)
    end
    -- deckender Hintergrund, damit nichts aus der Spielwelt (z. B. Namensplaketten) durchscheint
    f.deckel = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    f.deckel:SetPoint("TOPLEFT", 6, -6)
    f.deckel:SetPoint("BOTTOMRIGHT", -6, 6)
    f.deckel:SetColorTexture(0.06, 0.06, 0.07, 0.96)
    local pos = d.settings.window
    if pos then
        f:SetPoint(pos.punkt or "CENTER", UIParent, pos.relPunkt or "CENTER", pos.x or 0, pos.y or 0)
    else
        f:SetPoint("CENTER")
    end
    table.insert(UISpecialFrames, "GuildERPFenster")
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local punkt, _, relPunkt, x, y = f:GetPoint()
        Daten().settings.window = { punkt = punkt, relPunkt = relPunkt, x = x, y = y }
    end)

    -- Titelzeile
    f.titelIcon = f:CreateTexture(nil, "ARTWORK")
    f.titelIcon:SetSize(20, 20)
    f.titelIcon:SetPoint("TOPLEFT", 18, -15)
    f.titelIcon:SetTexture(K.ICON_TITEL)
    f.titelIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.titel = Schrift(f, "GameFontNormalLarge")
    f.titel:SetPoint("LEFT", f.titelIcon, "RIGHT", 8, 0)
    f.titel:SetText("Guild ERP")
    local function reiter(text, wert, vorher)
        local b = O.Rahmen("Button", nil, f)
        b:SetHeight(26)
        b.text = Schrift(b, "GameFontNormal")
        b.text:SetPoint("CENTER", 0, 1)
        b.text:SetText(text)
        b:SetWidth((b.text:GetStringWidth() or 80) + 28)
        if vorher then
            b:SetPoint("LEFT", vorher, "RIGHT", 4, 0)
        else
            b:SetPoint("LEFT", f.titel, "RIGHT", 22, -1)
        end
        b.linie = b:CreateTexture(nil, "ARTWORK")
        b.linie:SetHeight(2)
        b.linie:SetPoint("BOTTOMLEFT", 6, -2)
        b.linie:SetPoint("BOTTOMRIGHT", -6, -2)
        b.linie:SetColorTexture(K.GOLD[1], K.GOLD[2], K.GOLD[3], 1)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.06)
        b:SetScript("OnClick", function()
            Daten().settings.ansicht = wert
            PopupZu()
            FensterAktualisieren()
        end)
        return b
    end
    f.reiterWerk = reiter("Werkstatt", "werk")
    f.reiterPlan = reiter("Planaufträge", "plan", f.reiterWerk)
    f.reiterBest = reiter("Bestellungen", "best", f.reiterPlan)
    f.reiterKat = reiter("Katalog", "kat", f.reiterBest)
    local zu = O.Rahmen("Button", nil, f, "UIPanelCloseButton")
    zu:SetPoint("TOPRIGHT", -4, -4)
    zu:SetScript("OnClick", function() f:Hide() end)
    f.zu = zu
    f.zahnrad = O.Rahmen("Button", nil, f)
    f.zahnrad:SetSize(20, 20)
    f.zahnrad:SetPoint("RIGHT", zu, "LEFT", -4, 0)
    f.zahnrad:SetNormalTexture("Interface\\Icons\\INV_Misc_Gear_01")
    f.zahnrad:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    f.zahnrad:SetScript("OnClick", function() O.Zeigen() end)
    f.zahnrad:SetScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine("Optionen")
            GameTooltip:Show()
        end
    end)
    f.zahnrad:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    f:SetScale((O.Wert("groesse") or 100) / 100)
    f.version = Schrift(f, "GameFontDisableSmall", false)
    f.version:SetPoint("RIGHT", f.zahnrad, "LEFT", -8, 0)
    f.version:SetText("Version " .. K.VERSION .. " (Beta)")

    -- ===== Links: Rezeptbuch =====
    local L = O.Rahmen("Frame", nil, f)
    L:SetPoint("TOPLEFT", 18, -46)
    L:SetPoint("BOTTOMLEFT", 18, 16)
    L:SetWidth(400)
    f.links = L
    L.titel = Schrift(L, "GameFontNormalLarge")
    L.titel:SetPoint("TOPLEFT", 0, -4)
    L.titel:SetText("Rezeptbuch")
    L.handwerk = WahlKnopf(L, 400)
    L.handwerk:SetHeight(40)
    L.handwerk:SetPoint("TOPLEFT", 0, -30)
    if L.handwerk.text.SetFontObject then
        L.handwerk.text:SetFontObject("GameFontNormalLarge")
    end
    L.handwerk.rechts = Schrift(L.handwerk, "GameFontHighlightSmall", false)
    L.handwerk.rechts:SetPoint("RIGHT", -26, 0)
    L.handwerk.rechts:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    L.handwerk.text:ClearAllPoints()
    L.handwerk.text:SetPoint("LEFT", 12, 0)
    L.handwerk.text:SetPoint("RIGHT", L.handwerk.rechts, "LEFT", -8, 0)

    L.suche = O.Rahmen("EditBox", nil, L, K.BACKDROP_VORLAGE)
    L.suche:SetHeight(28)
    L.suche:SetPoint("TOPLEFT", 0, -80)
    L.suche:SetPoint("TOPRIGHT", 0, -80)
    L.suche:SetAutoFocus(false)
    L.suche:SetFontObject("GameFontHighlight")
    L.suche:SetTextInsets(26, 8, 0, 0)
    Flaeche(L.suche, { 0.12, 0.13, 0.15, 1 }, { 0.23, 0.21, 0.16, 1 })
    L.suche.lupe = L.suche:CreateTexture(nil, "ARTWORK")
    L.suche.lupe:SetSize(14, 14)
    L.suche.lupe:SetPoint("LEFT", 8, 0)
    L.suche.lupe:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    L.suche.platzhalter = Schrift(L.suche, "GameFontDisable")
    L.suche.platzhalter:SetPoint("LEFT", 26, 0)
    L.suche.platzhalter:SetText("Rezept suchen, z. B. Gürtel")
    L.suche:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    L.suche:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    L.suche:SetScript("OnTextChanged", function(self)
        L.suche.platzhalter:SetShown((self:GetText() or "") == "")
        FensterAktualisieren()
    end)
    O.SucheLook(L.suche)
    O.ListenHg(L)

    L.scroll, L.inhalt = Liste(L)
    L.scroll:SetPoint("TOPLEFT", 0, -118)
    L.scroll:SetPoint("BOTTOMRIGHT", -24, 22)
    L.zeilen = {}
    L.koepfe = {}
    L.leer = Schrift(L.inhalt, "GameFontHighlight")
    L.leer:SetPoint("TOPLEFT", 8, -10)
    L.leer:SetPoint("RIGHT", L.inhalt, "RIGHT", -8, 0)
    L.leer:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    L.fuss = Schrift(L, "GameFontDisableSmall")
    L.fuss:SetPoint("BOTTOMLEFT", 0, 2)
    L.fuss:SetPoint("BOTTOMRIGHT", 0, 2)

    -- Trennlinie
    f.trenner = f:CreateTexture(nil, "ARTWORK")
    f.trenner:SetWidth(1)
    f.trenner:SetPoint("TOPLEFT", 432, -48)
    f.trenner:SetPoint("BOTTOMLEFT", 432, 18)
    f.trenner:SetColorTexture(K.GOLD_DUNKEL[1], K.GOLD_DUNKEL[2], K.GOLD_DUNKEL[3], 0.7)

    -- ===== Rechts: Herstellauftrag =====
    local R = O.Rahmen("Frame", nil, f)
    R:SetPoint("TOPLEFT", 446, -46)
    R:SetPoint("BOTTOMRIGHT", -18, 16)
    f.rechts = R

    local karte = O.Rahmen("Frame", nil, R, K.BACKDROP_VORLAGE)
    karte:SetPoint("TOPLEFT", 0, 0)
    karte:SetPoint("TOPRIGHT", 0, 0)
    karte:SetHeight(64)
    Flaeche(karte, { 0.12, 0.13, 0.15, 1 }, { 0.23, 0.21, 0.16, 1 })
    R.karte = karte
    karte.rand = O.Rahmen("Frame", nil, karte, K.BACKDROP_VORLAGE)
    karte.rand:SetSize(48, 48)
    karte.rand:SetPoint("TOPLEFT", 10, -8)
    Flaeche(karte.rand, { 0.07, 0.07, 0.09, 1 }, { 0.3, 0.3, 0.3, 1 })
    karte.icon = karte.rand:CreateTexture(nil, "ARTWORK")
    karte.icon:SetPoint("TOPLEFT", 2, -2)
    karte.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    karte.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    karte.plan = O.Rahmen("Button", nil, karte, "UIPanelButtonTemplate")
    karte.plan:SetSize(100, 22)
    karte.plan:SetPoint("TOPRIGHT", -10, -8)
    karte.plan:SetText("Vormerken")
    karte.plan:SetScript("OnEnter", function(self)
        if GameTooltip and self.tip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.tip[1])
            GameTooltip:AddLine(self.tip[2], 1, 0.82, 0, true)
            GameTooltip:Show()
        end
    end)
    karte.plan:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    karte.plan:Hide()
    karte.schild = Schrift(karte, "GameFontHighlightSmall", false)
    karte.schild:SetPoint("TOPRIGHT", karte.plan, "BOTTOMRIGHT", 0, -5)
    karte.name = Schrift(karte, "GameFontNormalLarge")
    karte.name:SetPoint("TOPLEFT", karte.rand, "TOPRIGHT", 12, -6)
    karte.name:SetPoint("RIGHT", karte, "RIGHT", -120, 0)
    karte.unter = Schrift(karte, "GameFontHighlightSmall")
    karte.unter:SetPoint("TOPLEFT", karte.name, "BOTTOMLEFT", 0, -4)
    karte.unter:SetPoint("RIGHT", karte, "RIGHT", -150, 0)
    karte.unter:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    karte:EnableMouse(true)
    karte:SetScript("OnEnter", function(self)
        if self.itemID and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. self.itemID)
            GameTooltip:Show()
        end
    end)
    karte:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    -- Auftrag: wer stellt her, wie viele
    local auftrag = O.Rahmen("Frame", nil, karte)
    auftrag:SetPoint("TOPLEFT", 10, -64)
    auftrag:SetPoint("TOPRIGHT", -10, -64)
    auftrag:SetHeight(54)
    R.auftrag = auftrag
    auftrag.linie = auftrag:CreateTexture(nil, "ARTWORK")
    auftrag.linie:SetHeight(1)
    auftrag.linie:SetPoint("TOPLEFT", 0, 0)
    auftrag.linie:SetPoint("TOPRIGHT", 0, 0)
    auftrag.linie:SetColorTexture(1, 1, 1, 0.07)
    auftrag.werText = Schrift(auftrag, "GameFontDisableSmall")
    auftrag.werText:SetPoint("TOPLEFT", 0, -8)
    auftrag.werText:SetText("Wer stellt her?")
    auftrag.wer = WahlKnopf(auftrag, 210)
    auftrag.wer:SetPoint("TOPLEFT", 0, -22)
    local function mengeAendern(um)
        local s = Daten().settings
        s.menge = math.max(1, math.min(K.MENGE_MAX, (s.menge or 1) + um))
        FensterAktualisieren()
    end
    local function mengeKnopf(text, breite, um)
        local b = O.Rahmen("Button", nil, auftrag, "UIPanelButtonTemplate")
        b:SetSize(breite, 26)
        b:SetText(text)
        b:SetScript("OnClick", function() mengeAendern(um) end)
        return b
    end
    auftrag.plus5 = mengeKnopf("+5", 34, 5)
    auftrag.plus5:SetPoint("TOPRIGHT", 0, -22)
    auftrag.plus = mengeKnopf("+", 26, 1)
    auftrag.plus:SetPoint("RIGHT", auftrag.plus5, "LEFT", -3, 0)
    auftrag.menge = Schrift(auftrag, "GameFontHighlightLarge")
    auftrag.menge:SetJustifyH("CENTER")
    auftrag.menge:SetWidth(36)
    auftrag.menge:SetPoint("RIGHT", auftrag.plus, "LEFT", -2, 0)
    auftrag.minus = mengeKnopf("-", 26, -1)
    auftrag.minus:SetPoint("RIGHT", auftrag.menge, "LEFT", -2, 0)
    auftrag.minus5 = mengeKnopf("-5", 34, -5)
    auftrag.minus5:SetPoint("RIGHT", auftrag.minus, "LEFT", -3, 0)
    auftrag.wieText = Schrift(auftrag, "GameFontDisableSmall")
    auftrag.wieText:SetPoint("BOTTOM", auftrag.menge, "TOP", 0, 6)
    auftrag.wieText:SetText("Wie viele?")

    -- Bereitschaft: Text, Zaehler, Balken
    local bereit = O.Rahmen("Frame", nil, R)
    bereit:SetPoint("TOPLEFT", karte, "BOTTOMLEFT", 0, -12)
    bereit:SetPoint("TOPRIGHT", karte, "BOTTOMRIGHT", 0, -12)
    bereit:SetHeight(48)
    R.bereit = bereit
    bereit.text = Schrift(bereit, "GameFontNormal")
    bereit.text:SetPoint("TOPLEFT", 0, 0)
    bereit.zaehler = {}
    bereit.rauten = {}
    for _, st in ipairs(K.ZAEHLER) do
        local r = Raute(bereit, 7)
        Faerben(r, st)
        local t = Schrift(bereit, "GameFontHighlightSmall")
        t:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
        t:SetPoint("LEFT", r, "RIGHT", 5, 0)
        bereit.zaehler[st] = t
        bereit.rauten[st] = r
    end
    bereit.balken = {}

    local kopf = O.Rahmen("Frame", nil, R)
    kopf:SetPoint("TOPLEFT", bereit, "BOTTOMLEFT", 0, -6)
    kopf:SetPoint("TOPRIGHT", bereit, "BOTTOMRIGHT", 0, -6)
    kopf:SetHeight(18)
    R.kopf = kopf
    kopf.links = Schrift(kopf, "GameFontDisableSmall")
    kopf.links:SetPoint("LEFT", 2, 0)
    kopf.links:SetText("Zutat")
    kopf.rechts = Schrift(kopf, "GameFontDisableSmall", false)
    kopf.rechts:SetPoint("RIGHT", -28, 0)
    kopf.rechts:SetText("da / nötig")
    kopf.linie = kopf:CreateTexture(nil, "ARTWORK")
    kopf.linie:SetHeight(1)
    kopf.linie:SetPoint("BOTTOMLEFT")
    kopf.linie:SetPoint("BOTTOMRIGHT")
    kopf.linie:SetColorTexture(1, 1, 1, 0.1)

    R.scroll, R.inhalt = Liste(R)
    R.scroll:SetPoint("TOPLEFT", kopf, "BOTTOMLEFT", 0, -2)
    R.zeilen = {}

    -- Hinweis-Kasten (Bank)
    local hinweis = O.Rahmen("Frame", nil, R, K.BACKDROP_VORLAGE)
    hinweis:SetPoint("BOTTOMLEFT", 0, 0)
    hinweis:SetPoint("BOTTOMRIGHT", 0, 0)
    hinweis:SetHeight(42)
    Flaeche(hinweis, { 0.13, 0.11, 0.08, 1 }, { K.GOLD_DUNKEL[1], K.GOLD_DUNKEL[2], K.GOLD_DUNKEL[3], 1 })
    hinweis.icon = hinweis:CreateTexture(nil, "ARTWORK")
    hinweis.icon:SetSize(20, 20)
    hinweis.icon:SetPoint("LEFT", 10, 0)
    hinweis.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
    hinweis.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    hinweis.text = Schrift(hinweis, "GameFontHighlightSmall")
    hinweis.text:SetPoint("LEFT", hinweis.icon, "RIGHT", 10, 0)
    hinweis.text:SetPoint("RIGHT", -10, 0)
    hinweis.knopf = O.Rahmen("Button", nil, hinweis, "UIPanelButtonTemplate")
    hinweis.knopf:SetSize(172, 26)
    hinweis.knopf:SetPoint("RIGHT", -10, 0)
    hinweis.knopf:SetText("Im Berufefenster öffnen")
    hinweis.knopf:Hide()
    hinweis.text:SetTextColor(0.85, 0.80, 0.66)
    hinweis.glanz = hinweis:CreateTexture(nil, "BACKGROUND")
    hinweis.glanz:SetPoint("TOPLEFT", -4, 4)
    hinweis.glanz:SetPoint("BOTTOMRIGHT", 4, -4)
    hinweis.glanz:SetTexture(K.WEISS)
    hinweis.glanz:SetBlendMode("ADD")
    hinweis.glanz:SetVertexColor(K.STATUS_RGB.tasche[1], K.STATUS_RGB.tasche[2], K.STATUS_RGB.tasche[3], 0.25)
    hinweis.glanz:Hide()
    if hinweis.glanz.CreateAnimationGroup then
        local ag = hinweis.glanz:CreateAnimationGroup()
        local a = ag and ag:CreateAnimation("Alpha")
        if a and a.SetFromAlpha then
            a:SetFromAlpha(0.35)
            a:SetToAlpha(1)
            a:SetDuration(1.2)
            ag:SetLooping("BOUNCE")
            hinweis.puls = ag
        end
    end
    R.hinweis = hinweis

    -- Nicht gelerntes Rezept: wo man es lernt
    local lernen = O.Rahmen("Frame", nil, R, K.BACKDROP_VORLAGE)
    lernen:SetPoint("TOPLEFT", karte, "BOTTOMLEFT", 0, -12)
    lernen:SetPoint("TOPRIGHT", karte, "BOTTOMRIGHT", 0, -12)
    lernen:SetHeight(100)
    Flaeche(lernen, { 0.13, 0.11, 0.08, 1 }, { K.GOLD_DUNKEL[1], K.GOLD_DUNKEL[2], K.GOLD_DUNKEL[3], 1 })
    lernen.titel = Schrift(lernen, "GameFontNormal")
    lernen.titel:SetPoint("TOPLEFT", 14, -12)
    lernen.titel:SetText("Wo du das Rezept lernst")
    lernen.text = Schrift(lernen, "GameFontHighlight")
    lernen.text:SetPoint("TOPLEFT", lernen.titel, "BOTTOMLEFT", 0, -10)
    lernen.text:SetPoint("RIGHT", -14, 0)
    if lernen.text.SetSpacing then
        lernen.text:SetSpacing(3)
    end
    lernen.erklaerung = Schrift(R, "GameFontHighlight")
    lernen.erklaerung:SetPoint("TOPLEFT", lernen, "BOTTOMLEFT", 2, -14)
    lernen.erklaerung:SetPoint("RIGHT", R, "RIGHT", -2, 0)
    lernen.erklaerung:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    lernen.erklaerung:SetText("Die Zutaten zeigt das Spiel erst, wenn ein Charakter das Rezept kennt. "
        .. "Sobald einer es gelernt und sein Berufefenster geöffnet hat, erscheint hier die Stückliste.")
    R.lernen = lernen

    R.leer = Schrift(R, "GameFontHighlight")
    R.leer:SetPoint("TOPLEFT", karte, "BOTTOMLEFT", 2, -16)
    R.leer:SetPoint("RIGHT", R, "RIGHT", -2, 0)
    R.leer:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])

    B.AnsichtBauen(f)
    P.AnsichtBauen(f)
    Kat.AnsichtBauen(f)
    O.FensterLook(f)

    f:SetScript("OnShow", function()
        TaschenLesen()
        FensterAktualisieren()
    end)
    f:SetScript("OnHide", function() PopupZu() end)
    f:Hide()
    return f
end

-- ---------------------------------------------------------------------------
-- Fenster fuellen
-- ---------------------------------------------------------------------------
local function WerText(liste)
    if #liste == 0 then
        return "noch nicht gelernt"
    end
    if #liste == 1 then
        return liste[1].name .. ", " .. liste[1].n .. (liste[1].n == 1 and " Rezept" or " Rezepte")
    end
    local teile = {}
    for _, e in ipairs(liste) do
        table.insert(teile, e.name .. " " .. e.n)
    end
    return table.concat(teile, ", ")
end

local function HandwerkWahl(anker, berufe, gewaehlt)
    local haupt, neben = {}, {}
    for b in pairs(berufe) do
        table.insert(K.NEBENBERUFE[b] and neben or haupt, b)
    end
    table.sort(haupt)
    table.sort(neben)
    local liste = {}
    for _, gruppe in ipairs({ { "Hauptberufe", haupt }, { "Nebenberufe", neben } }) do
        if #gruppe[2] > 0 then
            table.insert(liste, { kopf = gruppe[1], rechts = tostring(#gruppe[2]) })
            for _, b in ipairs(gruppe[2]) do
                table.insert(liste, { wert = b, text = b, rechts = WerText(berufe[b]), gewaehlt = b == gewaehlt })
            end
        end
    end
    PopupZeigen(anker, 400, liste, function(wert)
        Daten().settings.beruf = wert
        local L = Fenster.links
        L.suche:SetText("")
        if L.scroll.SetVerticalScroll then
            L.scroll:SetVerticalScroll(0)
        end
    end)
end

-- Gruppen-Ueberschrift in der Rezeptliste (auf-/zuklappbar)
local function KopfZeileBauen(eltern)
    local k = O.Rahmen("Button", nil, eltern)
    k:SetHeight(28)
    k.pfeil = k:CreateTexture(nil, "ARTWORK")
    k.pfeil:SetSize(13, 13)
    k.pfeil:SetPoint("LEFT", 4, 0)
    k.pfeil:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    k.text = Schrift(k, "GameFontNormal")
    k.text:SetPoint("LEFT", k.pfeil, "RIGHT", 6, 0)
    k.rechts = Schrift(k, "GameFontDisableSmall", false)
    k.rechts:SetPoint("RIGHT", -8, 0)
    k.linie = k:CreateTexture(nil, "ARTWORK")
    k.linie:SetHeight(1)
    k.linie:SetPoint("BOTTOMLEFT")
    k.linie:SetPoint("BOTTOMRIGHT")
    k.linie:SetColorTexture(K.GOLD_DUNKEL[1], K.GOLD_DUNKEL[2], K.GOLD_DUNKEL[3], 0.9)
    local hl = k:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.05)
    k.rechtsText, k.pfeilGr, k.altPfeil = k.rechts, 13, true
    k.anker = function()
        k.pfeil:ClearAllPoints()
        k.pfeil:SetPoint("LEFT", 4, 0)
        k.text:ClearAllPoints()
        k.text:SetPoint("LEFT", k.pfeil, "RIGHT", 6, 0)
        k.rechts:ClearAllPoints()
        k.rechts:SetPoint("RIGHT", -8, 0)
    end
    O.Teil(function(spiel) O.KopfLook(k, spiel) end)
    return k
end

local function GrauHinweis(e)
    local q = e.quellen[1]
    if not q then
        return "Ort noch unbekannt"
    end
    return (q.art or "Lehrer") .. ": " .. (q.wer or "?") .. ", " .. (q.zone or "?")
        .. (#e.quellen > 1 and ("  +" .. (#e.quellen - 1) .. " weitere") or "")
end

local function QuelleZeile(q)
    local teile = { (q.art or "Lehrer") .. ": " .. (q.wer or "?") }
    local ort = (q.zone or "?") .. (q.x and (" (" .. q.x .. ", " .. q.y .. ")") or "")
    table.insert(teile, ort)
    if q.cost and q.cost > 0 then
        table.insert(teile, Geld(q.cost))
    end
    if q.skill then
        table.insert(teile, "ab Fertigkeit " .. q.skill)
    end
    if q.von then
        table.insert(teile, "gemeldet von " .. B.Anzeige(q.von))
    end
    return table.concat(teile, ", ")
end

local function RezeptbuchZeigen(f, fraktion, rezepte, berufe)
    local d = Daten()
    local L = f.links
    -- gewaehltes Handwerk
    local beruf = d.settings.beruf
    if not (beruf and berufe[beruf]) then
        local w = type(d.settings.wunsch) == "number" and d.recipes[d.settings.wunsch]
        beruf = w and berufe[w.profession] and w.profession or nil
        if not beruf then
            -- gelernte Berufe gehen vor solchen, von denen nur Quellen bekannt sind
            for b, liste in pairs(berufe) do
                local gelernterVorrang = beruf and (#liste > 0) ~= (#berufe[beruf] > 0)
                if not beruf or (gelernterVorrang and #liste > 0) or (not gelernterVorrang and b < beruf) then
                    beruf = b
                end
            end
        end
    end
    if beruf then
        L.handwerk.text:SetText(beruf)
        L.handwerk.rechts:SetText(WerText(berufe[beruf]))
    else
        L.handwerk.text:SetText(Farbe("9a9384", "Noch kein Handwerk bekannt"))
        L.handwerk.rechts:SetText("")
    end
    L.handwerk:SetScript("OnClick", function(self)
        if beruf then
            HandwerkWahl(self, berufe, beruf)
        end
    end)
    L.suche.platzhalter:SetText(beruf and ("In " .. beruf .. " suchen") or "Rezept suchen")

    for _, z in ipairs(L.zeilen) do
        z:Hide()
        z.benutzt = false
    end
    for _, k in ipairs(L.koepfe) do
        k:Hide()
        k.benutzt = false
    end
    L.gkoepfe = L.gkoepfe or {}
    for _, k in ipairs(L.gkoepfe) do
        k:Hide()
        k.benutzt = false
    end
    L.leer:Hide()
    L.fuss:SetText("Ein Klick auf ein Rezept zeigt rechts, was du dafür brauchst.")
    if not beruf then
        L.leer:SetText("Öffne bei jedem deiner Charaktere einmal sein Berufefenster (z. B. Schmiedekunst, Bergbau). "
            .. "Guild ERP merkt sich dann, welche Rezepte er kennt und welche Zutaten sie brauchen.")
        L.leer:Show()
        L.inhalt:SetHeight(80)
        L.fuss:SetText("")
        return
    end

    -- Eintraege: gelernte (eigene Charaktere dieser Fraktion), dann graue mit bekannter Quelle
    local suche = string.lower(L.suche:GetText() or "")
    local function passt(name)
        return suche == "" or string.find(string.lower(name or ""), suche, 1, true) ~= nil
    end
    local gelernt, grau = {}, {}
    for id, info in pairs(rezepte) do
        local r = d.recipes[id]
        if r.profession == beruf and passt(r.name) then
            table.insert(gelernt, { id = id, r = r, wer = info.wer })
        end
    end
    table.sort(gelernt, function(a, b) return (a.r.name or "") < (b.r.name or "") end)
    for _, e in ipairs(GraueRezepte(beruf, fraktion, GelernteNamen(beruf, rezepte))) do
        -- ab 1.1.5 nur, wo bekannt ist, wo man es lernt (Lehrer, Händler, Beute) - nichts vorwegnehmen
        if passt(e.name) and #e.quellen > 0 then
            table.insert(grau, e)
        end
    end
    table.sort(grau, function(a, b) return a.name < b.name end)

    local yy = 0
    local function kopf(text, rechts, offen, hell, umschalten)
        local k = Frei(L.koepfe, L.inhalt, KopfZeileBauen)
        if yy > 0 then
            yy = yy + 8
        end
        k:ClearAllPoints()
        k:SetPoint("TOPLEFT", 0, -yy)
        k:SetPoint("RIGHT", L.inhalt, "RIGHT", 0, 0)
        k.text:SetText(hell and Farbe("c9a54c", text) or Farbe("8f897a", text))
        k.rechts:SetText(rechts)
        O.KopfIcon(k, offen)
        k:SetScript("OnClick", function()
            umschalten()
            FensterAktualisieren()
        end)
        k:Show()
        yy = yy + 30
    end
    local function zeile(daten)
        local z = Frei(L.zeilen, L.inhalt, RezeptZeileBauen)
        z:ClearAllPoints()
        z:SetPoint("TOPLEFT", daten.einzug or 0, -yy)
        z:SetPoint("RIGHT", L.inhalt, "RIGHT", 0, 0)
        local h = daten.hinweis and 40 or 32
        z:SetHeight(h)
        z.icon:SetTexture(daten.icon or K.ICON_UNBEKANNT)
        if z.icon.SetDesaturated then
            z.icon:SetDesaturated(daten.grau and true or false)
        end
        z.icon:SetAlpha(daten.grau and 0.45 or 1)
        z.name:ClearAllPoints()
        if daten.hinweis then
            z.name:SetPoint("TOPLEFT", z.icon, "TOPRIGHT", 10, 2)
        else
            z.name:SetPoint("LEFT", z.icon, "RIGHT", 10, 0)
        end
        z.name:SetPoint("RIGHT", z.rechts, "LEFT", -6, 0)
        z.name:SetText(daten.text)
        z.hinweis:SetText(daten.hinweis or "")
        z.hinweis:SetShown(daten.hinweis ~= nil)
        z.rechts:SetText(daten.rechts or "")
        O.Gewaehlt(z, daten.gewaehlt and true or false)
        z.itemID, z.titel, z.tip = daten.itemID, daten.titel, daten.tip
        z:SetScript("OnClick", function()
            local s = Daten().settings
            if s.wunsch ~= daten.wert then
                -- anderes Rezept: Menge zuruecksetzen (bei Planauftrag: dessen Menge)
                local plan = type(daten.wert) == "number" and P.Plan(daten.wert)
                s.menge = plan and plan.menge or 1
            end
            s.wunsch = daten.wert
            PopupZu()
            FensterAktualisieren()
        end)
        z:Show()
        yy = yy + h
    end

    local wunsch = d.settings.wunsch
    -- Gruppen (ab 1.1.3, wie im Katalog): Verzauberungen nach Namensanfang, sonst nach Art des Gegenstands
    local function gruppiert(liste, teil, info, machen)
        local gruppen, gNamen = {}, {}
        for _, e in ipairs(liste) do
            local rid, itemID, name, wert = info(e)
            local g = Kat.Gruppe(rid, itemID, name)
            if not gruppen[g] then
                gruppen[g] = { gewaehlt = false }
                table.insert(gNamen, g)
            end
            table.insert(gruppen[g], e)
            if wert == wunsch then
                gruppen[g].gewaehlt = true
            end
        end
        table.sort(gNamen, function(x, y)
            if x == "Sonstiges" or y == "Sonstiges" then
                return y == "Sonstiges" and x ~= "Sonstiges"
            end
            return x < y
        end)
        for _, g in ipairs(gNamen) do
            local schluessel = "w:" .. beruf .. ":" .. teil .. ">" .. g
            local offen = Kat.auf[schluessel]
            if offen == nil then
                offen = suche ~= "" or gruppen[g].gewaehlt or #gNamen == 1
            end
            local k = Frei(L.gkoepfe, L.inhalt, Kat.KopfBauen)
            k:ClearAllPoints()
            k:SetPoint("TOPLEFT", 6, -yy)
            k:SetPoint("RIGHT", L.inhalt, "RIGHT", 0, 0)
            k.text:SetText(g)
            k.zahl:SetText(#gruppen[g])
            O.KopfIcon(k, offen)
            k:SetScript("OnClick", function()
                Kat.auf[schluessel] = not offen
                FensterAktualisieren()
            end)
            k:Show()
            yy = yy + 30
            if offen then
                for _, e in ipairs(gruppen[g]) do
                    machen(e)
                end
            end
        end
    end
    local gelerntOffen = not IstZu("gruppe:gelernt")
    if #berufe[beruf] > 0 then
        kopf("Gelernt", tostring(#gelernt), gelerntOffen, true, function() Umklappen("gruppe:gelernt") end)
    end
    if gelerntOffen then
        gruppiert(gelernt, "gelernt", function(e)
            return e.id, e.r.itemID, e.r.name, e.id
        end, function(e)
            local q = ItemQualitaet(e.r.itemID)
            local hex = (q and q ~= 1) and K.QUALITAET_HEX[q] or "eee3c6"
            local wer = {}
            for _, w in ipairs(e.wer) do
                table.insert(wer, w)
            end
            zeile({
                wert = e.id, text = Farbe(hex, e.r.name or "?"),
                icon = ItemIcon(e.r.itemID) or e.r.icon, itemID = e.r.itemID,
                rechts = wer[1] .. (#wer > 1 and (" +" .. (#wer - 1)) or ""),
                gewaehlt = wunsch == e.id, einzug = 22,
            })
        end)
    end
    if #grau > 0 then
        local grauOffen = d.settings.grauOffen == true or suche ~= "" or #berufe[beruf] == 0
        kopf("Noch nicht gelernt", #grau .. ", Quelle bekannt", grauOffen, false, function()
            local s = Daten().settings
            s.grauOffen = not (s.grauOffen == true)
        end)
        if grauOffen then
            gruppiert(grau, "grau", function(e)
                return nil, e.itemID, e.name, "g:" .. beruf .. ":" .. e.name
            end, function(e)
                local wert = "g:" .. beruf .. ":" .. e.name
                zeile({
                    wert = wert, text = Farbe("6f6a5c", e.name), grau = true,
                    icon = (e.itemID and ItemIcon(e.itemID)) or K.ICON_REZEPT,
                    hinweis = GrauHinweis(e), titel = e.name, tip = "Noch nicht gelernt.",
                    gewaehlt = wunsch == wert, einzug = 22,
                })
            end)
        end
    end
    if #gelernt + #grau == 0 and suche ~= "" then
        L.leer:ClearAllPoints()
        L.leer:SetPoint("TOPLEFT", 8, -(yy + 10))
        L.leer:SetPoint("RIGHT", L.inhalt, "RIGHT", -8, 0)
        L.leer:SetText("Kein Rezept passt zu deiner Suche.")
        L.leer:Show()
        yy = yy + 40
    end
    L.inhalt:SetHeight(math.max(10, yy))
end

local function KarteSetzen(karte, icon, name, hex, unter, q, itemID)
    karte.icon:SetTexture(icon or K.ICON_UNBEKANNT)
    local rgb = q and K.QUALITAET_RGB[q] or { 0.3, 0.3, 0.3 }
    if karte.rand.SetBackdropBorderColor then
        karte.rand:SetBackdropBorderColor(rgb[1], rgb[2], rgb[3], 1)
    end
    karte.name:SetText(Farbe(hex, name))
    karte.unter:SetText(unter or "")
    karte.itemID = itemID
end

local function AuftragZeigen(f, fraktion, rezepte)
    local d = Daten()
    local R = f.rechts
    local wunsch = d.settings.wunsch
    local menge = d.settings.menge or 1
    for _, z in ipairs(R.zeilen) do
        z:Hide()
        z.benutzt = false
    end
    f.y = 0
    f.zeilen, f.inhalt = R.zeilen, R.inhalt
    R.lernen:Hide()
    R.lernen.erklaerung:Hide()
    R.leer:Hide()
    local zeigeListe = false
    local stueckliste, hersteller, allesTasche, anzahlLaeufe, fehlend
    B.planID = nil

    if type(wunsch) == "string" and string.sub(wunsch, 1, 2) == "g:" then
        -- graues Rezept: nur zeigen, wo man es lernt
        local beruf, name = string.match(wunsch, "^g:([^:]+):(.+)$")
        local eintrag
        for _, e in ipairs(GraueRezepte(beruf or "", fraktion, GelernteNamen(beruf or "", rezepte))) do
            if e.name == name then
                eintrag = e
            end
        end
        KarteSetzen(R.karte, eintrag and eintrag.itemID and ItemIcon(eintrag.itemID) or K.ICON_REZEPT,
            name or "?", "8f897a", (beruf or "") .. ". Noch nicht gelernt.", nil, eintrag and eintrag.itemID)
        if R.karte.icon.SetDesaturated then
            R.karte.icon:SetDesaturated(true)
        end
        R.auftrag:Hide()
        P.KarteZeigen(R.karte)
        R.karte:SetHeight(64)
        local zeilen = {}
        for _, q in ipairs(eintrag and eintrag.quellen or {}) do
            table.insert(zeilen, QuelleZeile(q))
        end
        if #zeilen == 0 then
            table.insert(zeilen, "Noch unbekannt. Guild ERP merkt sich den Ort, sobald du den Lehrer oder Händler ansprichst.")
        end
        R.lernen.text:SetText(table.concat(zeilen, "\n"))
        R.lernen:SetHeight(12 + 16 + 10 + (R.lernen.text:GetStringHeight() or 20) + 14)
        R.lernen:Show()
        R.lernen.erklaerung:Show()
    else
        if R.karte.icon.SetDesaturated then
            R.karte.icon:SetDesaturated(false)
        end
        local info = type(wunsch) == "number" and rezepte[wunsch]
        local r = info and d.recipes[wunsch]
        if not r then
            KarteSetzen(R.karte, K.ICON_UNBEKANNT, "Noch kein Wunschrezept", "9a9384", "Wähle links im Rezeptbuch, was du herstellen willst.")
            P.KarteZeigen(R.karte)
            R.auftrag:Hide()
            R.karte:SetHeight(64)
        else
            B.fuerText = (r.name or "?") .. ", " .. menge .. "×"
            local q = ItemQualitaet(r.itemID)
            KarteSetzen(R.karte, ItemIcon(r.itemID) or r.icon, r.name, K.QUALITAET_HEX[q or 1] or "ffffff",
                (r.profession or "") .. ((r.numMade or 1) > 1 and (".  " .. r.numMade .. " Stück je Herstellung") or ""), q, r.itemID)
            R.karte:SetHeight(124)
            R.auftrag:Show()
            local ich = UnitName("player")
            local wer = HerstellerVon(wunsch, info.wer)
            R.auftrag.wer.text:SetText((wer or "?") .. (wer == ich and Farbe("9a9384", " (du)") or ""))
            R.auftrag.wer:SetScript("OnClick", function(self)
                HerstellerWahl(self, wunsch, info.wer)
            end)
            R.auftrag.menge:SetText(menge)
            local plan = P.Plan(wunsch)
            if plan then
                plan.menge, plan.wer = menge, wer
            end
            P.KarteZeigen(R.karte, wunsch, plan, menge, wer)
            B.planID = plan and plan.id or nil
            zeigeListe = true
            local liste, laeufe = Stueckliste(wunsch, menge, fraktion)
            liste = liste or {}
            stueckliste = liste
            anzahlLaeufe = laeufe
            hersteller = wer
            local zahl = { tasche = 0, gruen = 0, blau = 0, gelb = 0, rot = 0 }
            for _, z in ipairs(liste) do
                local st = z.tasche and "tasche" or z.status
                zahl[st] = zahl[st] + 1
                ZweigZeigen(f, z, 1, tostring(wunsch), fraktion)
            end
            R.inhalt:SetHeight(math.max(10, f.y))
            -- Bereitschaft
            local b = R.bereit
            allesTasche = #liste > 0 and zahl.tasche == #liste
            if allesTasche then
                b.text:SetText(Farbe(K.STATUS_HEX.tasche, #liste == 1 and "Die Zutat liegt in deiner Tasche"
                    or ("Alle " .. #liste .. " Zutaten in deiner Tasche")))
            else
                b.text:SetText((zahl.tasche + zahl.gruen) .. " von " .. #liste .. " Zutaten da"
                    .. (zahl.blau > 0 and (", " .. zahl.blau .. (zahl.blau == 1 and " kommt noch" or " kommen noch")) or ""))
            end
            b.zaehler.tasche:SetText(zahl.tasche .. " in der Tasche")
            b.zaehler.gruen:SetText(zahl.gruen .. " woanders")
            b.zaehler.blau:SetText(zahl.blau .. " zugesagt")
            b.zaehler.gelb:SetText(zahl.gelb .. " herstellbar")
            b.zaehler.rot:SetText(zahl.rot .. (zahl.rot == 1 and " fehlt" or " fehlen"))
            local vorher
            for _, st in ipairs(K.ZAEHLER) do
                local zeigen = st ~= "blau" or zahl.blau > 0 or plan ~= nil
                b.rauten[st]:SetShown(zeigen)
                b.zaehler[st]:SetShown(zeigen)
                if zeigen then
                    b.rauten[st]:ClearAllPoints()
                    if vorher then
                        b.rauten[st]:SetPoint("LEFT", vorher, "RIGHT", 14, 0)
                    else
                        b.rauten[st]:SetPoint("TOPLEFT", 3, -25)
                    end
                    vorher = b.zaehler[st]
                end
            end
            local breite = (b:GetWidth() or 436)
            if breite <= 0 then
                breite = 436
            end
            local n = math.max(1, #liste)
            local seg = (breite - (n - 1) * 3) / n
            for i, z in ipairs(liste) do
                local t = b.balken[i]
                if not t then
                    t = b:CreateTexture(nil, "ARTWORK")
                    t:SetHeight(7)
                    t:SetTexture(K.WEISS)
                    b.balken[i] = t
                end
                t:ClearAllPoints()
                t:SetPoint("BOTTOMLEFT", (i - 1) * (seg + 3), 0)
                t:SetWidth(seg)
                Faerben(t, z.tasche and "tasche" or z.status)
                t:Show()
            end
            for j = #liste + 1, #b.balken do
                b.balken[j]:Hide()
            end
        end
    end
    R.bereit:SetShown(zeigeListe)
    R.kopf:SetShown(zeigeListe)
    R.scroll:SetShown(zeigeListe)
    if not zeigeListe and not R.lernen:IsShown() and not (type(wunsch) == "number" and rezepte[wunsch]) then
        R.leer:SetText(next(rezepte) and "Links siehst du alle Rezepte deiner Charaktere. Ein Klick auf eines zeigt hier, was du dafür brauchst und ob es da ist."
            or "Öffne bei jedem deiner Charaktere einmal sein Berufefenster. Deine Taschen werden von selbst erfasst, die Bank, sobald du sie öffnest.")
        R.leer:Show()
    end

    -- Hinweis-Kasten unten: alles in der Tasche / was zu holen ist / Bank unbekannt
    local ich = UnitName("player")
    local zeilen = {}
    local gruen = false
    if allesTasche then
        gruen = true
        table.insert(zeilen, Farbe(K.STATUS_HEX.tasche, "Alles in deiner Tasche."))
        if hersteller and hersteller ~= ich then
            table.insert(zeilen, "Herstellen soll " .. hersteller .. ". Gib die Zutaten an " .. hersteller .. " weiter.")
        else
            table.insert(zeilen, "Herstellen klickst du im Berufefenster selbst.")
        end
    elseif stueckliste then
        -- Fehlendes fuer den Bestellschein: Grundzutaten angehakt, Zwischenprodukte als Moeglichkeit
        local nachID, reihe = {}, {}
        local zugesagt, bestellt = {}, {}
        local function fehl(z)
            if (z.zugesagt or 0) > 0 then
                table.insert(zugesagt, (ItemName(z.itemID) or "?") .. " (" .. z.zugesagt .. ")")
            end
            if (z.bestellt or 0) > 0 then
                table.insert(bestellt, ItemName(z.itemID) or "?")
            end
            local offen = (z.rest or 0) - (z.bestellt or 0)
            if offen <= 0 and not z.kinder then
                return
            end
            if (z.rest or 0) <= 0 then
                return
            end
            if z.kinder then
                if z.status == "rot" then
                    table.insert(reihe, { itemID = z.itemID, n = z.rest, an = false, zwischen = true,
                        hinweis = "Statt selbst herzustellen: fertig bestellen" })
                end
                for _, k in ipairs(z.kinder) do
                    fehl(k)
                end
            elseif nachID[z.itemID] then
                nachID[z.itemID].n = nachID[z.itemID].n + offen
            else
                local e = { itemID = z.itemID, n = offen, an = true,
                    hinweis = z.da > 0 and (z.da .. " hast du schon, " .. offen .. (offen == 1 and " fehlt" or " fehlen"))
                        or ((z.zugesagt or 0) > 0 and (z.zugesagt .. " zugesagt, " .. offen .. (offen == 1 and " fehlt" or " fehlen")))
                        or "Fehlt ganz" }
                nachID[z.itemID] = e
                table.insert(reihe, e)
            end
        end
        for _, z in ipairs(stueckliste) do
            fehl(z)
        end
        local grund, zwischen = {}, {}
        for _, e in ipairs(reihe) do
            table.insert(e.zwischen and zwischen or grund, e)
        end
        fehlend = {}
        for _, e in ipairs(grund) do
            table.insert(fehlend, e)
        end
        for _, e in ipairs(zwischen) do
            table.insert(fehlend, e)
        end
        if #grund > 0 then
            local keiner = B.planID and ", die keiner zugesagt hat." or "."
            table.insert(zeilen, #grund == 1 and ("Es fehlt noch 1 Zutat" .. keiner)
                or ("Es fehlen noch " .. #grund .. " Zutaten" .. keiner))
        end
        local kosten = A.KostenText(A.Fehlendes(stueckliste))
        if kosten then
            table.insert(zeilen, "Im Auktionshaus kostet das Fehlende " .. kosten .. ".")
        end
        if #zugesagt > 0 then
            table.insert(zeilen, Farbe(K.STATUS_HEX.blau, "Zugesagt: " .. table.concat(zugesagt, ", ") .. "."))
        end
        if #bestellt > 0 then
            table.insert(zeilen, (#grund == 0 and "Alles Fehlende ist bestellt: " or "Schon bestellt: ")
                .. table.concat(bestellt, ", ") .. ".")
        end
        local bank, bei, gesehen = {}, {}, {}
        local reihenfolge = {}
        local function sammeln(z)
            for _, q in ipairs(z.quellen) do
                if not q.live then
                    local n = ItemName(z.itemID) or "?"
                    local key = q.wer .. ":" .. q.wo .. ":" .. n
                    if not gesehen[key] then
                        gesehen[key] = true
                        if q.wer == ich then
                            table.insert(bank, n)
                        else
                            if not bei[q.wer] then
                                bei[q.wer] = {}
                                table.insert(reihenfolge, q.wer)
                            end
                            table.insert(bei[q.wer], n .. " (" .. q.wo .. ")")
                        end
                    end
                end
            end
            for _, k in ipairs(z.kinder or {}) do
                sammeln(k)
            end
        end
        for _, z in ipairs(stueckliste) do
            sammeln(z)
        end
        if #bank > 0 then
            table.insert(zeilen, "Aus deiner Bank holen: " .. table.concat(bank, ", ") .. ".")
        end
        for _, w in ipairs(reihenfolge) do
            table.insert(zeilen, "Bei " .. w .. ": " .. table.concat(bei[w], ", ") .. ".")
        end
    end
    if #zeilen == 0 then
        local ohneBank = {}
        for _, c in pairs(d.characters) do
            if c.faction == fraktion and not c.bankAt then
                table.insert(ohneBank, c.name)
            end
        end
        table.sort(ohneBank)
        if #ohneBank > 0 then
            local wer = #ohneBank == 1 and (ohneBank[1] .. (string.sub(ohneBank[1], -1) == "s" and "’" or "s") .. " Bank ist")
                or ("Die Banken von " .. table.concat(ohneBank, ", ") .. " sind")
            table.insert(zeilen, wer .. " noch nicht erfasst. Öffne sie einmal, dann zählt ihr Inhalt mit.")
        end
    end
    local h = R.hinweis
    local mitKnopf = allesTasche and (not hersteller or hersteller == ich) and type(wunsch) == "number"
    h.text:ClearAllPoints()
    h.text:SetPoint("LEFT", h.icon, "RIGHT", 10, 0)
    local bestellbar = not mitKnopf and fehlend and #fehlend > 0 and fehlend[1].an
    if mitKnopf then
        h.text:SetPoint("RIGHT", h.knopf, "LEFT", -10, 0)
        local id, anzahl = wunsch, anzahlLaeufe or 1
        h.knopf:SetText("Im Berufefenster öffnen")
        h.knopf:SetScript("OnClick", function()
            BerufefensterOeffnen(id, anzahl)
        end)
        h.knopf:Show()
    elseif bestellbar then
        h.text:SetPoint("RIGHT", h.knopf, "LEFT", -10, 0)
        local kopie = {}
        for _, e in ipairs(fehlend) do
            table.insert(kopie, { itemID = e.itemID, n = e.n, an = e.an, hinweis = e.hinweis })
        end
        h.knopf:SetText(B.planID and "Rest bestellen" or "Fehlendes bestellen")
        h.knopf:SetScript("OnClick", function()
            B.ScheinOeffnen(kopie, B.fuerText)
        end)
        h.knopf:Show()
    else
        h.text:SetPoint("RIGHT", -10, 0)
        h.knopf:Hide()
    end
    if #zeilen > 0 then
        h.text:SetText(table.concat(zeilen, "\n"))
        if gruen then
            Flaeche(h, { 0.08, 0.15, 0.10, 1 }, { K.STATUS_RGB.tasche[1], K.STATUS_RGB.tasche[2], K.STATUS_RGB.tasche[3], 1 })
            h.text:SetTextColor(0.75, 0.85, 0.76)
            h.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
            h.glanz:Show()
            if h.puls and not h.puls:IsPlaying() then
                h.puls:Play()
            end
        else
            Flaeche(h, { 0.13, 0.11, 0.08, 1 }, { K.GOLD_DUNKEL[1], K.GOLD_DUNKEL[2], K.GOLD_DUNKEL[3], 1 })
            h.text:SetTextColor(0.85, 0.80, 0.66)
            h.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
            h.glanz:Hide()
            if h.puls then
                h.puls:Stop()
            end
        end
        local hoehe = math.max(42, (h.text:GetStringHeight() or 14) + 20)
        h:SetHeight(hoehe)
        h:Show()
        R.scroll:SetPoint("BOTTOMRIGHT", R, "BOTTOMRIGHT", -24, hoehe + 10)
    else
        h:Hide()
        R.scroll:SetPoint("BOTTOMRIGHT", R, "BOTTOMRIGHT", -24, 0)
    end
end

-- ---------------------------------------------------------------------------
-- Bestellungen in der Gruppe (Version 0.5)
-- Eine Bestellung ist nur ein VERMERK: wer braucht was, wer liefert wieviel und wie.
-- Uebergeben (Handel, Post, Gildenbank) macht jeder Spieler selbst.
-- Abgleich ueber Add-on-Nachrichten in der Gruppe (PARTY/RAID), gedrosselt:
-- hoechstens eine Nachricht je 1,2 Sekunden, bei Drosselung 10 Sekunden Pause.
-- Fremde Daten werden geprueft und gekuerzt, bevor sie gespeichert werden.
-- ---------------------------------------------------------------------------
K.PREFIX = "GERP1"
K.LIEFERWEGE = { "Direkt handeln", "Per Post", "In die Gildenbank", "Beim Handeln verzaubern" }
K.PERGAMENT = { 0.91, 0.86, 0.74 }
K.TINTE = { 0.16, 0.13, 0.09 }
K.TINTE2 = { 0.42, 0.35, 0.25 }
K.STATUS_TEXT = {
    offen = { "offen", "7a4a10" }, teilweise = { "teilweise zugesagt", "7a4a10" },
    zugesagt = { "zugesagt", "2f5a1a" }, geliefert = { "geliefert", "2a2116" },
}

function B.Liste()
    local d = Daten()
    d.orders = d.orders or {}
    return d.orders
end

-- eigene Charaktere: eigene[name] ist wahr, wenn der Name zu einem eigenen Charakter passt
-- (voller Name oder - bei aelteren Daten - Vorname)
function B.EigeneNamen()
    local liste = {}
    for _, c in pairs(Daten().characters) do
        if c.name then
            table.insert(liste, c.voll or c.name)
        end
    end
    table.insert(liste, B.Ich())
    return setmetatable({}, { __index = function(_, n)
        if type(n) ~= "string" then
            return nil
        end
        for _, e in ipairs(liste) do
            if B.Gleich(e, n) then
                return true
            end
        end
        return nil
    end })
end

-- meine Zusage in einer Zeile (auch unter altem Vornamen gespeichert)
function B.MeineZusage(z)
    local ich = B.Ich()
    for wer, s in pairs(z.zusagen or {}) do
        if B.Gleich(wer, ich) then
            return s, wer
        end
    end
end

-- Stand einer Zeile: zugesagt, geliefert, Status-Schluessel
function B.ZeilenStand(z)
    local zu, gel = 0, 0
    for _, s in pairs(z.zusagen or {}) do
        zu = zu + (s.n or 0)
        if s.g then
            gel = gel + (s.n or 0)
        end
    end
    local st = "offen"
    if gel >= z.n then
        st = "geliefert"
    elseif zu >= z.n then
        st = "zugesagt"
    elseif zu > 0 then
        st = "teilweise"
    end
    return zu, gel, st
end

-- ----- Text verpacken (Trennzeichen und Umlaute maskieren, damit nichts zerbricht)
function B.M(wert)
    return (string.gsub(tostring(wert == nil and "" or wert), "[%%~^;:,=/|\r\n\128-\255]", function(z)
        return string.format("%%%02X", string.byte(z))
    end))
end

function B.D(text)
    return (string.gsub(text or "", "%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end))
end

function B.Kurz(text, max)
    text = tostring(text or "")
    if #text > max then
        text = string.sub(text, 1, max)
    end
    return text
end

function B.Zahl(text, max)
    local n = tonumber(text) or 0
    return math.max(0, math.min(max or 100000, math.floor(n)))
end

function B.AlsText(o)
    local zeilen = {}
    for _, z in ipairs(o.zeilen or {}) do
        local zus = {}
        for wer, s in pairs(z.zusagen or {}) do
            table.insert(zus, table.concat({ B.M(wer), s.n or 0, s.weg or 1, s.g and 1 or 0, s.at or 0 }, "/"))
        end
        local kopf = z.rezeptID and ("r" .. z.rezeptID .. "." .. (z.itemID or 0)) or z.itemID
        table.insert(zeilen, table.concat({ kopf, z.n, table.concat(zus, ";") }, ":"))
    end
    return table.concat({
        "i=" .. B.M(o.id), "v=" .. B.M(o.von), "a=" .. B.M(o.an), "f=" .. B.M(o.fuer),
        "n=" .. B.M(o.notiz), "t=" .. (o.at or 0), "s=" .. B.M(o.status), "k=" .. (o.kopfRev or 0),
        "p=" .. B.M(o.plan), "m=" .. B.M(o.mats), "z=" .. table.concat(zeilen, ","),
    }, "^")
end

function B.AusText(text)
    local f = {}
    for teil in string.gmatch(text, "[^%^]+") do
        local k, v = string.match(teil, "^(%a)=(.*)$")
        if k then
            f[k] = v
        end
    end
    if not f.i or not f.v then
        return nil
    end
    local o = {
        id = B.Kurz(B.D(f.i), 48), von = B.Kurz(B.D(f.v), 40), an = B.Kurz(B.D(f.a), 40),
        fuer = B.Kurz(B.D(f.f), 80), notiz = B.Kurz(B.D(f.n), 120),
        at = B.Zahl(f.t, 4000000000), kopfRev = B.Zahl(f.k, 4000000000), zeilen = {},
    }
    local plan = B.Kurz(B.D(f.p), 48)
    o.plan = plan ~= "" and plan or nil
    local mats = B.D(f.m)
    o.mats = (mats == "b" or mats == "h") and mats or nil
    local st = B.D(f.s)
    o.status = (st == "abgeschlossen" or st == "zurueckgezogen") and st or "offen"
    for zeile in string.gmatch(f.z or "", "[^,]+") do
        if #o.zeilen >= 20 then
            break
        end
        local rid, rItem, rn, rzus = string.match(zeile, "^r(%d+)%.(%d+):(%d+):?(.*)$")
        local id, n, zus = string.match(zeile, "^(%d+):(%d+):?(.*)$")
        if rid then
            id, n, zus = rItem, rn, rzus
        end
        if id then
            local z = { itemID = B.Zahl(id), n = math.max(1, B.Zahl(n, 10000)), zusagen = {},
                rezeptID = rid and B.Zahl(rid) or nil }
            local anzahl = 0
            for s in string.gmatch(zus or "", "[^;]+") do
                local wer, sn, weg, g, at = string.match(s, "^([^/]+)/(%d+)/(%d+)/(%d)/(%d+)$")
                if wer and anzahl < 20 then
                    anzahl = anzahl + 1
                    z.zusagen[B.Kurz(B.D(wer), 40)] = {
                        n = B.Zahl(sn, 10000), weg = math.max(1, math.min(#K.LIEFERWEGE, B.Zahl(weg))),
                        g = g == "1", at = B.Zahl(at, 4000000000),
                    }
                end
            end
            if z.itemID > 0 or z.rezeptID then
                table.insert(o.zeilen, z)
            end
        end
    end
    if #o.zeilen == 0 then
        return nil
    end
    return o
end

-- Eine empfangene Bestellung mit der eigenen zusammenfuehren. Rueckgabe: neu?, Aenderungen (Texte)
function B.Einmischen(neu)
    local liste = B.Liste()
    local alt = liste[neu.id]
    if not alt then
        liste[neu.id] = neu
        return true, {}
    end
    local meldungen = {}
    if (neu.kopfRev or 0) > (alt.kopfRev or 0) then
        alt.von, alt.an, alt.fuer, alt.notiz, alt.at, alt.plan = neu.von, neu.an, neu.fuer, neu.notiz, neu.at, neu.plan
        alt.mats = neu.mats
        if neu.status ~= alt.status then
            table.insert(meldungen, neu.status)
        end
        alt.status, alt.kopfRev = neu.status, neu.kopfRev
        -- Zeilen vom Besteller uebernehmen, Zusagen behalten
        local alteZeilen = {}
        for _, z in ipairs(alt.zeilen) do
            alteZeilen[B.ZKey(z)] = z
        end
        local zeilen = {}
        for _, z in ipairs(neu.zeilen) do
            local a = alteZeilen[B.ZKey(z)]
            table.insert(zeilen, { itemID = z.itemID, rezeptID = z.rezeptID, n = z.n, zusagen = a and a.zusagen or {} })
        end
        alt.zeilen = zeilen
    end
    -- Zusagen: je Person gilt die neueste
    for _, z in ipairs(neu.zeilen) do
        for _, az in ipairs(alt.zeilen) do
            if B.ZKey(az) == B.ZKey(z) then
                az.zusagen = az.zusagen or {}
                for wer, s in pairs(z.zusagen or {}) do
                    local a = az.zusagen[wer]
                    if not a or (s.at or 0) > (a.at or 0) then
                        local hatte = a and (a.n or 0) > 0
                        az.zusagen[wer] = s
                        table.insert(meldungen, { wer = wer, name = B.ZName(z), s = s, zurueck = hatte and (s.n or 0) == 0 })
                    end
                end
            end
        end
    end
    return false, meldungen
end

-- ----- Senden (gedrosselt) -----
B.schlange = {}
B.laeuft = false
B.pauseBis = 0
B.nr = 0

function B.InGruppe()
    if O.GildeModus() then
        -- Guild-Found (ab 1.3): Abgleich nur mit der Gilde, ueber den Gildenkanal
        return IsInGuild and IsInGuild() and true or false
    end
    if IsInGroup then
        return IsInGroup() and true or false
    end
    return (GetNumGroupMembers and GetNumGroupMembers() or 0) > 0
end

function B.Kanal()
    if O.GildeModus() then
        return "GUILD"
    end
    if IsInRaid and IsInRaid() then
        return "RAID"
    end
    return "PARTY"
end

function B.Takt()
    if #B.schlange == 0 or not B.InGruppe() then
        B.laeuft = false
        if not B.InGruppe() then
            B.schlange = {}
        end
        return
    end
    B.laeuft = true
    if (GetTime and GetTime() < B.pauseBis) or (InCombatLockdown and InCombatLockdown()) then
        O.Nach(1.2, B.Takt)
        return
    end
    local text = table.remove(B.schlange, 1)
    -- vor dem Senden merken (fuer das Echo, aus dem der eigene volle Name gelernt wird)
    if string.sub(text, 1, 1) ~= "H" and #text > 6 then
        B.gesendeteTexte[text] = true
        B.gesendeteZahl = (B.gesendeteZahl or 0) + 1
        if B.gesendeteZahl > 200 then
            B.gesendeteTexte, B.gesendeteZahl = { [text] = true }, 1
        end
    end
    local ok, ergebnis
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        ok, ergebnis = pcall(C_ChatInfo.SendAddonMessage, K.PREFIX, text, B.Kanal())
    elseif SendAddonMessage then
        ok, ergebnis = pcall(SendAddonMessage, K.PREFIX, text, B.Kanal())
    end
    -- Ergebnis: 0 oder true = gesendet; 3, 8, 11 = gedrosselt bzw. gerade gesperrt (spaeter nochmal);
    -- andere Zahlen = Fehler (Nachricht verwerfen, damit nichts haengen bleibt)
    local art = string.sub(text, 1, 1)
    if not ok then
        B.Diagnose("fehler", art, tostring(ergebnis))
    elseif type(ergebnis) == "number" and ergebnis ~= 0 then
        if ergebnis == 3 or ergebnis == 8 or ergebnis == 11 then
            table.insert(B.schlange, 1, text)
            B.pauseBis = (GetTime and GetTime() or 0) + 10
            B.Diagnose("gedrosselt", art, ergebnis)
        else
            B.Diagnose("fehler", art, "Ergebnis " .. ergebnis)
        end
    else
        B.Diagnose("gesendet", art)
    end
    O.Nach(1.2, B.Takt)
end

-- Zaehler fuer den Abgleich (stehen nach /reload in den gespeicherten Daten)
function B.Diagnose(was, art, info)
    local d = Daten()
    d.diagnostics = d.diagnostics or {}
    local g = d.diagnostics.abgleich or {}
    d.diagnostics.abgleich = g
    g[was] = g[was] or {}
    g[was][art or "?"] = (g[was][art or "?"] or 0) + 1
    if info then
        g.letzte = date("%H:%M:%S") .. " " .. was .. " " .. (art or "?") .. ": " .. tostring(info)
    end
end

function B.Einreihen(text)
    if not B.InGruppe() then
        return
    end
    table.insert(B.schlange, text)
    if not B.laeuft then
        B.laeuft = true
        O.Nach(0.1, B.Takt)
    end
end

-- Bestellung verteilen (in Teilen zu hoechstens 200 Zeichen)
function B.Verteilen(o)
    if not B.InGruppe() then
        return false
    end
    B.Paket("B", B.AlsText(o))
    return true
end

-- langen Text in Teilen zu hoechstens 200 Zeichen senden: "X~nr~teil~gesamt~inhalt"
function B.Paket(art, text)
    B.nr = (B.nr % 999) + 1
    local teile = {}
    for i = 1, math.max(1, #text), 200 do
        table.insert(teile, string.sub(text, i, i + 199))
    end
    for i, t in ipairs(teile) do
        B.Einreihen(art .. "~" .. B.nr .. "~" .. i .. "~" .. #teile .. "~" .. t)
    end
end

-- Alles Wichtige teilen (beim Gruppenbeitritt oder wenn ein anderer "Hallo" sagt)
function B.AllesSenden()
    if B.wartetAlles then
        return
    end
    B.wartetAlles = true
    O.Nach(2, function()
        B.wartetAlles = false
        local grenze = time() - 7 * 86400
        for _, o in pairs(B.Liste()) do
            if o.status == "offen" or (o.kopfRev or 0) > grenze then
                B.Verteilen(o)
            end
        end
    end)
end

B.puffer = {}
B.bestaetigt = {}

-- Teile einer Nachricht sammeln ("nr~teil~gesamt~inhalt"); liefert den ganzen Text, wenn vollstaendig
function B.Teil(art, rest, absender, maxTeile)
    local nr, teil, gesamt, inhalt = string.match(rest, "^(%d+)~(%d+)~(%d+)~(.*)$")
    teil, gesamt = tonumber(teil), tonumber(gesamt)
    if not nr or not teil or not gesamt or gesamt > maxTeile or teil < 1 or teil > gesamt then
        return nil
    end
    local schluessel = absender .. "#" .. art .. "#" .. nr
    local p = B.puffer[schluessel] or { teile = {}, anzahl = 0, at = time() }
    B.puffer[schluessel] = p
    if not p.teile[teil] then
        p.teile[teil] = inhalt
        p.anzahl = p.anzahl + 1
    end
    if p.anzahl < gesamt then
        return nil
    end
    B.puffer[schluessel] = nil
    return table.concat(p.teile)
end

-- Funktion geschuetzt ausfuehren; Fehler werden fuer die Diagnose gemerkt
function B.Sicher(name, fn, ...)
    local ok, fehler = pcall(fn, ...)
    if not ok then
        B.Diagnose("fehler", name, fehler)
        O.Fehler(name, fehler)
    end
end

-- Stand einer Bestellung: hoechster Zeitstempel aus Kopf und Zusagen
function B.Ver(o)
    local v = o.kopfRev or 0
    for _, z in ipairs(o.zeilen or {}) do
        for _, s in pairs(z.zusagen or {}) do
            v = math.max(v, s.at or 0)
        end
    end
    return v
end

function B.Relevant(o)
    return o.status == "offen" or (o.kopfRev or 0) > time() - 7 * 86400
end

-- Stand-Abgleich (ab 0.9): erst nur sagen, was man hat; geschickt wird nur, was dem anderen fehlt
function B.StandSenden(sofort)
    if B.wartetStand or (not sofort and time() - (B.standAt or 0) < 10) then
        return
    end
    B.wartetStand = true
    O.Nach(2, function()
        B.wartetStand = false
        if not B.InGruppe() then
            return
        end
        B.standAt = time()
        B.Sicher("StandSenden", function()
            local teile = {}
            for id, o in pairs(B.Liste()) do
                if B.Relevant(o) then
                    table.insert(teile, B.M(id) .. "=" .. B.Ver(o))
                end
            end
            B.Paket("I", table.concat(teile, ","))
            B.Einreihen("S~" .. Kat.Eigener())
            Kat.TeilenStandSenden()
        end)
    end)
end

-- Index eines anderen: alles schicken, was er nicht oder aelter hat
function B.IndexEmpfangen(text)
    local seine = {}
    for teil in string.gmatch(text or "", "[^,]+") do
        local id, ver = string.match(teil, "^(.-)=(%d+)$")
        if id then
            seine[B.D(id)] = tonumber(ver)
        end
    end
    for id, o in pairs(B.Liste()) do
        if B.Relevant(o) and (not seine[id] or seine[id] < B.Ver(o)) then
            B.Verteilen(o)
        end
    end
end

-- Namen (ab 1.0): In WoW Forever hat jeder Vor- und Nachnamen; eindeutig ist nur beides zusammen.
-- UnitName liefert nur den Vornamen, Add-on-Nachrichten kommen mit vollem Namen ("Barlor Rostbart").
-- Den eigenen vollen Namen lernt Guild ERP aus dem Echo der eigenen Nachrichten.
-- Vergleiche laufen ueber B.Gleich: volle Namen muessen gleich sein; ist einer nur ein Vorname
-- (aeltere Daten), reicht der gleiche Vorname.
function B.Name(n)
    if not n or n == "" then
        return nil
    end
    if Ambiguate then
        local ok, a = pcall(Ambiguate, n, "none")
        if ok and a then
            n = a
        end
    end
    n = string.match(n, "^([^%-]+)") or n
    return (string.gsub(n, "^%s*(.-)%s*$", "%1"))
end

function B.Vorname(n)
    return n and string.match(n, "^%s*(%S+)") or n
end

function B.Gleich(a, b)
    if not a or not b then
        return false
    end
    if a == b then
        return true
    end
    if string.find(a, " ", 1, true) and string.find(b, " ", 1, true) then
        return false
    end
    return B.Vorname(a) == B.Vorname(b)
end

function B.Ich()
    local c = Charakter()
    return (c and c.voll) or B.Name(UnitName("player")) or "?"
end

-- bekannte volle Namen anderer (Vorname -> voller Name), aus ihren Nachrichten
B.bekannt = {}
function B.Merken(voll)
    if voll and string.find(voll, " ", 1, true) then
        B.bekannt[B.Vorname(voll)] = voll
    end
end

-- Anzeige: kurz (Vorname); nur wenn zwei bekannte Namen denselben Vornamen haben, voll
function B.Anzeige(n)
    if not n or not string.find(n, " ", 1, true) then
        return n or "?"
    end
    local vor = B.Vorname(n)
    local function anders(x)
        return x and x ~= n and string.find(x, " ", 1, true) and B.Vorname(x) == vor
    end
    for _, v in pairs(B.bekannt) do
        if anders(v) then
            return n
        end
    end
    for name in pairs((Daten().fremd) or {}) do
        if anders(name) then
            return n
        end
    end
    for _, c in pairs(Daten().characters) do
        if anders(c.voll) then
            return n
        end
    end
    return vor
end

-- Echo eigener Nachrichten: daraus den eigenen vollen Namen lernen
B.gesendeteTexte = {}
function B.EchoPruefen(text, absender)
    local voll = B.Name(absender)
    if not voll or not B.gesendeteTexte[text] or not string.find(voll, " ", 1, true) then
        return
    end
    if B.Vorname(voll) ~= B.Vorname(UnitName("player")) then
        return
    end
    local c = Charakter()
    if c and c.voll ~= voll then
        c.voll = voll
        Kat.gemeldet = nil
    end
end

function B.Empfangen(text, absender)
    absender = B.Name(absender)
    if not absender or B.Gleich(absender, B.Ich()) then
        return
    end
    B.Merken(absender)
    B.Diagnose("empfangen", string.sub(text, 1, 1))
    local art, rest = string.match(text, "^(%a)~?(.*)$")
    if art == "H" then
        -- "H~2": neuer Stand-Abgleich (ab 0.9); nur "H": aeltere Version, die alles braucht
        if rest == "2" then
            B.StandSenden()
        else
            B.AllesSenden()
        end
    elseif art == "S" then
        B.Sicher("Stand", Kat.StandEmpfangen, rest, absender)
    elseif art == "Q" then
        if B.Gleich(B.Name(B.D(rest)), B.Ich()) then
            Kat.Senden(true)
        end
    elseif art == "T" then
        B.Sicher("Teilen", Kat.TeilenStandEmpfangen, rest, absender)
    elseif art == "R" then
        if B.Gleich(B.Name(B.D(rest)), B.Ich()) then
            B.Sicher("Teilen", Kat.TeilenSenden)
        end
    elseif art == "Z" or art == "W" then
        local inhalt = B.Teil(art, rest, absender, 40)
        if inhalt then
            B.Sicher("Teilen", art == "Z" and Kat.QuellenEmpfangen or Kat.PreiseEmpfangen, inhalt, absender)
        end
    elseif art == "I" or art == "K" then
        local inhalt = B.Teil(art, rest, absender, art == "K" and 80 or 30)
        if inhalt then
            if art == "I" then
                B.Sicher("Index", B.IndexEmpfangen, inhalt)
            else
                B.Sicher("Katalog", Kat.Empfangen, inhalt, absender)
            end
        end
    elseif art == "A" then
        local id = B.D(rest)
        local o = B.Liste()[id]
        if o and B.EigeneNamen()[o.von] then
            o.gesehen = o.gesehen or {}
            if not o.gesehen[absender] then
                o.gesehen[absender] = true
                if FensterAktualisieren then
                    FensterAktualisieren()
                end
            end
        end
    elseif art == "B" then
        local ganz = B.Teil("B", rest, absender, 30)
        if not ganz then
            return
        end
        local o = B.AusText(ganz)
        if not o then
            return
        end
        local eigene = B.EigeneNamen()
        local neu, meldungen = B.Einmischen(o)
        local fuerMich = not eigene[o.von] and (o.an == "" or eigene[o.an])
        for _, z in ipairs(o.zeilen) do
            if z.itemID and z.itemID > 0 then
                ItemName(z.itemID) -- Namen beim Spiel anfordern
            end
        end
        if neu and fuerMich and o.status == "offen" then
            -- nur melden, wenn ich etwas davon liefern kann (Rezepte: nur wenn ich sie kenne)
            local kann = false
            for _, z in ipairs(o.zeilen) do
                if not z.rezeptID or B.KenneRezept(z.rezeptID) then
                    kann = true
                end
            end
            if kann then
                O.Nach(1.5, function()
                    local teile, rezept = {}, false
                    for _, z in ipairs(o.zeilen) do
                        table.insert(teile, z.n .. "× " .. B.ZName(z))
                        rezept = rezept or z.rezeptID ~= nil
                    end
                    local text = B.Anzeige(o.von) .. " bestellt bei " .. (o.an == "" and ("eurer " .. O.Wir()) or "dir") .. ": "
                        .. table.concat(teile, ", ")
                    local unter = {}
                    if rezept then
                        table.insert(unter, o.mats == "b" and ("Zutaten bringt " .. B.Anzeige(o.von) .. " mit.")
                            or "Die Zutaten besorgt der Hersteller.")
                    end
                    if o.notiz and o.notiz ~= "" then
                        table.insert(unter, "„" .. o.notiz .. "“")
                    end
                    O.Chat(text .. ". Mit /gerp siehst du es unter Bestellungen.")
                    B.Hinweis("NEUE BESTELLUNG", text, table.concat(unter, " "), o)
                end)
            end
        end
        for _, m in ipairs(meldungen) do
            if type(m) == "table" and eigene[o.von] and not eigene[m.wer] then
                if m.zurueck then
                    local t = B.Anzeige(m.wer) .. " hat die Zusage für " .. m.name .. " zurückgenommen."
                    O.Chat(t)
                    B.Hinweis("ZUSAGE ZURÜCKGENOMMEN", t, "Deine Bestellung ist dafür wieder offen.", o)
                elseif (m.s.n or 0) > 0 then
                    O.Merken(m.s.g and "GELIEFERT" or "ZUSAGE", B.Anzeige(m.wer) .. (m.s.g and " hat geliefert: " or " liefert ")
                        .. m.s.n .. "× " .. m.name)
                    O.KnopfZeigen()
                    O.Chat(B.Anzeige(m.wer) .. (m.s.g and " hat geliefert: " or " liefert ") .. m.s.n .. "× "
                        .. m.name .. " (" .. (K.LIEFERWEGE[m.s.weg] or "?") .. ").")
                end
            elseif m == "zurueckgezogen" and not eigene[o.von] then
                local meine = false
                for _, z in ipairs(o.zeilen) do
                    local s = B.MeineZusage(z)
                    if s and (s.n or 0) > 0 and not s.g then
                        meine = true
                    end
                end
                local t = B.Anzeige(o.von) .. " hat die Bestellung für " .. ((o.fuer ~= "" and o.fuer) or "?") .. " storniert."
                O.Chat(t)
                if meine then
                    B.Hinweis("BESTELLUNG STORNIERT", t, "Deine Zusage ist damit hinfällig.", o)
                end
            end
        end
        -- Empfang bestaetigen (einmal je Stand)
        if fuerMich then
            local k = o.id .. "#" .. (o.kopfRev or 0)
            if not B.bestaetigt[k] then
                B.bestaetigt[k] = true
                B.Einreihen("A~" .. B.M(o.id))
            end
        end
        if FensterAktualisieren then
            FensterAktualisieren()
        end
    end
end

function B.GruppeGeaendert()
    local mitglieder = {}
    local anzahl = GetNumGroupMembers and GetNumGroupMembers() or 0
    local neuDabei = false
    for i = 1, anzahl do
        local einheit = (IsInRaid and IsInRaid()) and ("raid" .. i) or ("party" .. i)
        local name = UnitName(einheit)
        if name then
            mitglieder[name] = true
            if not (B.mitglieder or {})[name] then
                neuDabei = true
            end
        end
    end
    B.mitglieder = mitglieder
    if neuDabei and B.InGruppe() and not O.GildeModus() then
        B.Einreihen("H~2")
        B.StandSenden()
    end
end

function B.Mitglieder()
    if O.GildeModus() then
        return O.GildeOnline()
    end
    local namen = {}
    for n in pairs(B.mitglieder or {}) do
        if n ~= UnitName("player") then
            table.insert(namen, B.bekannt[B.Vorname(n)] or n)
        end
    end
    table.sort(namen)
    return namen
end

-- ----- Eine Bestellung anlegen -----
function B.Anlegen(zeilen, an, fuer, notiz, plan, mats)
    local d = Daten()
    d.settings.orderNr = (d.settings.orderNr or 0) + 1
    local ich = B.Ich()
    local o = {
        id = B.Vorname(ich) .. "-" .. time() .. "-" .. d.settings.orderNr, von = ich, an = an or "", fuer = fuer or "",
        notiz = B.Kurz(notiz or "", 120), at = time(), kopfRev = time(), status = "offen", zeilen = {},
        plan = plan, mats = mats,
    }
    for _, z in ipairs(zeilen) do
        table.insert(o.zeilen, { itemID = z.itemID or 0, rezeptID = z.rezeptID, n = z.n, zusagen = {} })
    end
    B.Liste()[o.id] = o
    local gesendet = B.Verteilen(o)
    Melden(gesendet and "Bestellung gesendet." or
        "Bestellung gespeichert. Sie wird gesendet, sobald ihr zusammen in einer Gruppe seid.")
    return o
end

function B.Status(o, status)
    o.status = status
    o.kopfRev = math.max(time(), (o.kopfRev or 0) + 1)
    B.Verteilen(o)
end

function B.Zusagen(o, schluessel, n, weg, geliefert, still)
    local ich = B.Ich()
    for _, z in ipairs(o.zeilen) do
        if B.ZKey(z) == schluessel then
            z.zusagen = z.zusagen or {}
            local alt, altName = B.MeineZusage(z)
            if altName and altName ~= ich then
                z.zusagen[altName] = nil -- alter Eintrag unter dem Vornamen
            end
            if n <= 0 then
                z.zusagen[ich] = { n = 0, weg = weg or 1, g = false, at = math.max(time(), (alt and alt.at or 0) + 1) }
            else
                z.zusagen[ich] = { n = n, weg = weg or 1, g = geliefert and true or false,
                    at = math.max(time(), (alt and alt.at or 0) + 1) }
            end
        end
    end
    local gesendet = B.Verteilen(o)
    if not still then
        Melden((geliefert and "Als geliefert vermerkt." or (n <= 0 and "Zusage zurückgenommen." or "Zusage gesendet."))
            .. (gesendet and "" or " Das wird übertragen, sobald ihr zusammen in einer Gruppe seid."))
    end
end

-- Tooltip fuer eine Bestellzeile: der Gegenstand bzw. die Verzauberung, wie im Spiel
function B.ZeilenTooltip(zeile)
    if not GameTooltip then
        return
    end
    if zeile.rid then
        Kat.Tooltip(zeile, zeile.rid, zeile.itemID)
    elseif zeile.itemID and zeile.itemID > 0 then
        GameTooltip:SetOwner(zeile, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. zeile.itemID)
        GameTooltip:Show()
    end
end

-- Zeilen: Gegenstand (itemID) oder Rezept (rezeptID, z. B. eine Verzauberung; itemID = Ergebnis oder 0)
function B.ZKey(z)
    return z.rezeptID and ("r" .. z.rezeptID) or z.itemID
end

function B.ZName(z)
    if z.rezeptID then
        return Kat.Name(z.rezeptID, z.itemID) or ("Rezept " .. z.rezeptID)
    end
    return ItemName(z.itemID) or "?"
end

-- kennt einer meiner Charaktere das Rezept? Rueckgabe: Name des Charakters
function B.KenneRezept(rid)
    local beste
    local fraktion = SpielerFraktion()
    for _, c in pairs(Daten().characters) do
        for _, ids in pairs((not c.faction or c.faction == fraktion) and c.recipes or {}) do
            if type(ids) == "table" and ids[rid] then
                if c.name == UnitName("player") then
                    return c.voll or c.name
                end
                beste = beste or (c.voll or c.name)
            end
        end
    end
    return beste
end

-- offene Bestellungen an mich (fuer die Zahl am Reiter)
function B.OffenFuerMich()
    local eigene = B.EigeneNamen()
    local anzahl = 0
    for _, o in pairs(B.Liste()) do
        if o.status == "offen" and not eigene[o.von] and (o.an == "" or eigene[o.an]) then
            for _, z in ipairs(o.zeilen) do
                local _, _, st = B.ZeilenStand(z)
                local meine = B.MeineZusage(z)
                local kann = not z.rezeptID or B.KenneRezept(z.rezeptID)
                if kann and st ~= "geliefert" and st ~= "zugesagt" and not (meine and meine.n > 0) then
                    anzahl = anzahl + 1
                    break
                end
            end
        end
    end
    return anzahl
end

-- ---------------------------------------------------------------------------
-- Pergament-Bausteine
-- ---------------------------------------------------------------------------
function B.Pergament(f)
    Flaeche(f, { K.PERGAMENT[1], K.PERGAMENT[2], K.PERGAMENT[3], 1 }, { 0.55, 0.46, 0.30, 1 })
end

function B.Tinte(fs, zweit)
    local c = zweit and K.TINTE2 or K.TINTE
    fs:SetTextColor(c[1], c[2], c[3])
end

function B.Knopf(eltern, text, breite)
    local b = O.Rahmen("Button", nil, eltern, "UIPanelButtonTemplate")
    b:SetSize(breite or 110, 24)
    b:SetText(text)
    return b
end

-- ---------------------------------------------------------------------------
-- Bestellschein (Fenster ueber der Werkstatt)
-- eintraege: { {itemID, n, an = true/false, hinweis = "..."} }
-- ---------------------------------------------------------------------------
function B.ScheinBauen()
    local s = O.Rahmen("Frame", "GuildERPBestellschein", Fenster, K.BACKDROP_VORLAGE)
    s.deckend = true
    s:SetSize(480, 420)
    s:SetPoint("TOPRIGHT", Fenster, "TOPRIGHT", -24, -58)
    s:SetFrameStrata("DIALOG")
    s:EnableMouse(true)
    B.Pergament(s)
    s.titel = Schrift(s, "GameFontNormalLarge")
    s.titel:SetPoint("TOPLEFT", 22, -18)
    s.titel:SetText("Bestellung")
    B.Tinte(s.titel)
    s.fuer = Schrift(s, "GameFontHighlight", false)
    s.fuer:SetPoint("TOPRIGHT", -22, -20)
    B.Tinte(s.fuer, true)
    s.linie = s:CreateTexture(nil, "ARTWORK")
    s.linie:SetHeight(2)
    s.linie:SetPoint("TOPLEFT", 22, -44)
    s.linie:SetPoint("TOPRIGHT", -22, -44)
    s.linie:SetColorTexture(K.TINTE[1], K.TINTE[2], K.TINTE[3], 1)
    s.zeilen = {}
    s.anText = Schrift(s, "GameFontHighlightSmall")
    B.Tinte(s.anText, true)
    s.anText:SetText("An wen?")
    s.an = WahlKnopf(s, 210)
    s.notizText = Schrift(s, "GameFontHighlightSmall")
    B.Tinte(s.notizText, true)
    s.notizText:SetText("Notiz, wenn du magst")
    s.notiz = O.Rahmen("EditBox", nil, s, K.BACKDROP_VORLAGE)
    s.notiz:SetSize(206, 26)
    s.notiz:SetAutoFocus(false)
    s.notiz:SetFontObject("GameFontHighlight")
    s.notiz:SetTextInsets(8, 8, 0, 0)
    s.notiz:SetMaxLetters(120)
    s.notiz:SetTextColor(K.TINTE[1], K.TINTE[2], K.TINTE[3])
    Flaeche(s.notiz, { 0.95, 0.91, 0.81, 1 }, { 0.66, 0.58, 0.42, 1 })
    s.notiz:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    s.notiz:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    s.zaehler = Schrift(s, "GameFontHighlightSmall")
    B.Tinte(s.zaehler, true)
    s.senden = B.Knopf(s, "Bestellung senden", 150)
    s.senden:SetPoint("BOTTOMRIGHT", -18, 16)
    s.abbrechen = B.Knopf(s, "Abbrechen", 100)
    s.abbrechen:SetPoint("RIGHT", s.senden, "LEFT", -8, 0)
    s.abbrechen:SetScript("OnClick", function() s:Hide() end)
    s.zaehler:SetPoint("LEFT", 22, 0)
    s.zaehler:SetPoint("TOP", s.senden, "TOP", 0, -6)
    s:SetScript("OnHide", function() PopupZu() end)
    s:Hide()
    B.schein = s
    return s
end

function B.ScheinZeile(s, i)
    local z = s.zeilen[i]
    if z then
        return z
    end
    z = O.Rahmen("Frame", nil, s)
    z:SetHeight(38)
    z:EnableMouse(true)
    z:SetScript("OnEnter", function(self) B.ZeilenTooltip(self) end)
    z:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    z.haken = O.Rahmen("CheckButton", nil, z, "UICheckButtonTemplate")
    z.haken:SetSize(24, 24)
    z.haken:SetPoint("LEFT", -4, 0)
    z.name = Schrift(z, "GameFontHighlight")
    z.name:SetPoint("TOPLEFT", 26, -4)
    z.hinweis = Schrift(z, "GameFontHighlightSmall")
    z.hinweis:SetPoint("TOPLEFT", z.name, "BOTTOMLEFT", 0, -2)
    B.Tinte(z.hinweis, true)
    z.plus = B.Knopf(z, "+", 24)
    z.plus:SetPoint("RIGHT", 0, 0)
    z.menge = Schrift(z, "GameFontHighlightLarge")
    z.menge:SetJustifyH("CENTER")
    z.menge:SetWidth(36)
    z.menge:SetPoint("RIGHT", z.plus, "LEFT", -2, 0)
    B.Tinte(z.menge)
    z.minus = B.Knopf(z, "-", 24)
    z.minus:SetPoint("RIGHT", z.menge, "LEFT", -2, 0)
    z.name:SetPoint("RIGHT", z.minus, "LEFT", -8, 0)
    z.hinweis:SetPoint("RIGHT", z.minus, "LEFT", -8, 0)
    z.linie = z:CreateTexture(nil, "ARTWORK")
    z.linie:SetHeight(1)
    z.linie:SetPoint("BOTTOMLEFT")
    z.linie:SetPoint("BOTTOMRIGHT")
    z.linie:SetColorTexture(0.66, 0.58, 0.42, 0.7)
    s.zeilen[i] = z
    return z
end

function B.ScheinZeigen()
    local s = B.schein
    local gewaehlt, gesamt = 0, #s.daten
    local y = 52
    for i, e in ipairs(s.daten) do
        local z = B.ScheinZeile(s, i)
        z:ClearAllPoints()
        z:SetPoint("TOPLEFT", 22, -y)
        z:SetPoint("RIGHT", s, "RIGHT", -22, 0)
        z.haken:SetChecked(e.an)
        z.name:SetText(ItemName(e.itemID) or "?")
        z.itemID, z.rid = e.itemID, nil
        if e.an then
            B.Tinte(z.name)
            B.Tinte(z.menge)
            gewaehlt = gewaehlt + 1
        else
            z.name:SetTextColor(0.6, 0.54, 0.42)
            z.menge:SetTextColor(0.6, 0.54, 0.42)
        end
        z.hinweis:SetText(e.hinweis or "")
        z.menge:SetText(e.n)
        z.haken:SetScript("OnClick", function(self)
            e.an = self:GetChecked() and true or false
            B.ScheinZeigen()
        end)
        z.minus:SetScript("OnClick", function()
            e.n = math.max(1, e.n - 1)
            B.ScheinZeigen()
        end)
        z.plus:SetScript("OnClick", function()
            e.n = math.min(10000, e.n + 1)
            B.ScheinZeigen()
        end)
        z:Show()
        y = y + 40
    end
    for j = gesamt + 1, #s.zeilen do
        s.zeilen[j]:Hide()
    end
    y = y + 14
    s.anText:ClearAllPoints()
    s.anText:SetPoint("TOPLEFT", 22, -y)
    s.notizText:ClearAllPoints()
    s.notizText:SetPoint("TOPLEFT", 246, -y)
    s.an:ClearAllPoints()
    s.an:SetPoint("TOPLEFT", 22, -(y + 16))
    s.notiz:ClearAllPoints()
    s.notiz:SetPoint("TOPLEFT", 246, -(y + 16))
    s.an.text:SetText(s.wahlAn == "" and ("Alle in deiner " .. O.Wir()) or s.wahlAn)
    s.an:SetScript("OnClick", function(self)
        local liste = { { wert = "", text = "Alle in deiner " .. O.Wir(), gewaehlt = s.wahlAn == "" } }
        local mitglieder = B.Mitglieder()
        if #mitglieder > 0 then
            table.insert(liste, { kopf = "Nur an", rechts = tostring(#mitglieder) })
        end
        for _, n in ipairs(mitglieder) do
            table.insert(liste, { wert = n, text = n, gewaehlt = s.wahlAn == n })
        end
        PopupZeigen(self, 230, liste, function(wert)
            s.wahlAn = wert
            B.ScheinZeigen()
        end, B.InGruppe() and nil or (O.GildeModus() and "Du bist in keiner Gilde. Mit Guild-Found geht Guild ERP nur innerhalb der Gilde." or "Du bist gerade in keiner Gruppe. Die Bestellung wird gesendet, sobald ihr zusammen in einer Gruppe seid."))
    end)
    s.zaehler:SetText(gewaehlt .. " von " .. gesamt .. (gesamt == 1 and " Zeile" or " Zeilen") .. " gewählt")
    s.senden:SetScript("OnClick", function()
        local zeilen = {}
        for _, e in ipairs(s.daten) do
            if e.an and e.n > 0 then
                table.insert(zeilen, { itemID = e.itemID, n = e.n })
            end
        end
        if #zeilen == 0 then
            Melden("Wähle mindestens eine Zeile aus.")
            return
        end
        B.Anlegen(zeilen, s.wahlAn, s.fuerText, s.notiz:GetText(), s.plan)
        s:Hide()
        Daten().settings.ansicht = "best"
        FensterAktualisieren()
    end)
    s:SetHeight(y + 16 + 26 + 60)
    s:Show()
end

function B.ScheinOeffnen(eintraege, fuerText)
    local s = B.schein or B.ScheinBauen()
    s.daten = eintraege
    s.fuerText = fuerText or ""
    s.fuer:SetText(fuerText and fuerText ~= "" and ("für " .. fuerText) or "")
    s.wahlAn = ""
    s.plan = B.planID
    s.notiz:SetText("")
    PopupZu()
    B.ScheinZeigen()
end

-- ---------------------------------------------------------------------------
-- Zusage-Fenster ("Ich liefere")
-- ---------------------------------------------------------------------------
function B.ZusageOeffnen(anker, o, z)
    local e = B.zusage
    if not e then
        e = O.Rahmen("Frame", "GuildERPZusage", Fenster, K.BACKDROP_VORLAGE)
        e.deckend = true
        e:SetSize(330, 132)
        e:SetFrameStrata("DIALOG")
        e:EnableMouse(true)
        B.Pergament(e)
        e.frage = Schrift(e, "GameFontHighlight")
        e.frage:SetPoint("TOPLEFT", 14, -12)
        e.frage:SetPoint("RIGHT", -14, 0)
        B.Tinte(e.frage)
        e.minus = B.Knopf(e, "-", 24)
        e.minus:SetPoint("TOPLEFT", 14, -40)
        e.menge = Schrift(e, "GameFontHighlightLarge")
        e.menge:SetJustifyH("CENTER")
        e.menge:SetWidth(40)
        e.menge:SetPoint("LEFT", e.minus, "RIGHT", 2, 0)
        B.Tinte(e.menge)
        e.plus = B.Knopf(e, "+", 24)
        e.plus:SetPoint("LEFT", e.menge, "RIGHT", 2, 0)
        e.von = Schrift(e, "GameFontHighlightSmall")
        e.von:SetPoint("LEFT", e.plus, "RIGHT", 6, 0)
        B.Tinte(e.von, true)
        e.weg = WahlKnopf(e, 170)
        e.weg:SetPoint("TOPRIGHT", -14, -38)
        e.plan = O.Rahmen("CheckButton", nil, e, "UICheckButtonTemplate")
        e.plan:SetSize(22, 22)
        e.plan:SetPoint("TOPLEFT", 12, -70)
        e.planText = Schrift(e, "GameFontHighlight")
        e.planText:SetPoint("TOPLEFT", e.plan, "TOPRIGHT", 4, -3)
        e.planText:SetPoint("RIGHT", -14, 0)
        B.Tinte(e.planText)
        e.planText:SetText("Als Planauftrag übernehmen")
        e.planUnter = Schrift(e, "GameFontHighlightSmall")
        e.planUnter:SetPoint("TOPLEFT", e.planText, "BOTTOMLEFT", 0, -2)
        e.planUnter:SetPoint("RIGHT", -14, 0)
        B.Tinte(e.planUnter, true)
        e.senden = B.Knopf(e, "Zusage senden", 130)
        e.senden:SetPoint("BOTTOMRIGHT", -12, 12)
        e.abbrechen = B.Knopf(e, "Abbrechen", 90)
        e.abbrechen:SetPoint("RIGHT", e.senden, "LEFT", -6, 0)
        e.abbrechen:SetScript("OnClick", function() e:Hide() end)
        e:SetScript("OnHide", function() PopupZu() end)
        B.zusage = e
    end
    local eigen, eigenName = B.MeineZusage(z)
    local zu = 0
    for wer, s in pairs(z.zusagen or {}) do
        if wer ~= eigenName then
            zu = zu + (s.n or 0)
        end
    end
    local verzaubern = z.rezeptID and (not z.itemID or z.itemID == 0)
    e.n = eigen and eigen.n > 0 and eigen.n or math.max(1, z.n - zu)
    e.wegNr = eigen and eigen.weg or (verzaubern and 4 or 1)
    local name = B.ZName(z)
    e.frage:SetText("Wie viele " .. name .. " lieferst du, und wie?")
    -- Rezept-Bestellung: als Planauftrag uebernehmen (vorgewaehlt)
    local kenne = z.rezeptID and B.KenneRezept(z.rezeptID)
    e.plan:SetShown(kenne and true or false)
    e.planText:SetShown(kenne and true or false)
    e.planUnter:SetShown(kenne and true or false)
    if kenne then
        e.plan:SetChecked(true)
        e.planUnter:SetText(o.mats == "b" and ("Erscheint unter Planaufträge. Die Zutaten von " .. B.Anzeige(o.von)
            .. " zählen dort blau als „bringt mit“.") or "Erscheint unter Planaufträge, mit allem, was du dafür brauchst.")
        e:SetHeight(176)
    else
        e:SetHeight(132)
    end
    local function zeigen()
        e.menge:SetText(e.n)
        e.von:SetText("von " .. z.n)
        e.weg.text:SetText(K.LIEFERWEGE[e.wegNr])
    end
    e.minus:SetScript("OnClick", function() e.n = math.max(1, e.n - 1); zeigen() end)
    e.plus:SetScript("OnClick", function() e.n = math.min(10000, e.n + 1); zeigen() end)
    e.weg:SetScript("OnClick", function(self)
        local liste = {}
        for i, w in ipairs(K.LIEFERWEGE) do
            table.insert(liste, { wert = i, text = w, gewaehlt = i == e.wegNr })
        end
        PopupZeigen(self, 170, liste, function(wert)
            e.wegNr = wert
            zeigen()
        end)
    end)
    e.senden:SetScript("OnClick", function()
        B.Zusagen(o, B.ZKey(z), e.n, e.wegNr, false)
        if kenne and e.plan:GetChecked() then
            P.Uebernehmen(o, z, e.n)
        end
        e:Hide()
        FensterAktualisieren()
    end)
    zeigen()
    e:ClearAllPoints()
    e:SetPoint("TOPRIGHT", anker, "BOTTOMRIGHT", 0, -4)
    e:Show()
end

-- ---------------------------------------------------------------------------
-- Hinweis-Fenster oben in der Mitte (neue Bestellung, Storno, zurueckgenommene Zusage)
-- ---------------------------------------------------------------------------
function B.Hinweis(titel, text, unter, o)
    O.Merken(titel, text)
    if O.Wert("ton") and PlaySound and SOUNDKIT and SOUNDKIT.TELL_MESSAGE then
        pcall(PlaySound, SOUNDKIT.TELL_MESSAGE)
    end
    O.KnopfZeigen()
    -- Fenster in der Mitte nur, wenn so eingestellt (oder der Minimap-Knopf ausgeschaltet ist)
    local modus = O.Wert("hinweis")
    if modus == "chat" or (modus == "knopf" and O.Wert("minimap") and O.knopf) then
        return
    end
    local h = B.hinweisFenster
    if not h then
        h = O.Rahmen("Frame", "GuildERPHinweis", UIParent, K.BACKDROP_VORLAGE)
        h:SetSize(440, 110)
        h:SetPoint("TOP", 0, -120)
        h:SetFrameStrata("DIALOG")
        h:SetClampedToScreen(true)
        h:EnableMouse(true)
        if h.SetBackdrop then
            h:SetBackdrop(K.BACKDROP_RAHMEN)
        end
        h.icon = h:CreateTexture(nil, "ARTWORK")
        h.icon:SetSize(36, 36)
        h.icon:SetPoint("TOPLEFT", 16, -16)
        h.icon:SetTexture(K.ICON_TITEL)
        h.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        h.titel = Schrift(h, "GameFontNormalSmall")
        h.titel:SetPoint("TOPLEFT", h.icon, "TOPRIGHT", 12, 0)
        h.text = Schrift(h, "GameFontHighlight")
        h.text:SetPoint("TOPLEFT", h.titel, "BOTTOMLEFT", 0, -4)
        h.text:SetPoint("RIGHT", -16, 0)
        h.unter = Schrift(h, "GameFontHighlightSmall")
        h.unter:SetPoint("TOPLEFT", h.text, "BOTTOMLEFT", 0, -3)
        h.unter:SetPoint("RIGHT", -16, 0)
        h.unter:SetTextColor(0.72, 0.67, 0.55)
        h.ansehen = O.Rahmen("Button", nil, h, "UIPanelButtonTemplate")
        h.ansehen:SetSize(100, 24)
        h.spaeter = O.Rahmen("Button", nil, h, "UIPanelButtonTemplate")
        h.spaeter:SetSize(90, 24)
        h.spaeter:SetText("Später")
        h.spaeter:SetScript("OnClick", function() h:Hide() end)
        h.ansehen:SetText("Ansehen")
        h.ansehen:SetScript("OnClick", function()
            h:Hide()
            Daten().settings.ansicht = "best"
            if not (Fenster and Fenster:IsShown()) then
                SlashCmdList.GUILDERP("")
            end
            FensterAktualisieren()
        end)
        B.hinweisFenster = h
    end
    h.titel:SetText("GUILD ERP · " .. titel)
    h.text:SetText(text)
    h.unter:SetText(unter or "")
    local hoehe = 16 + 14 + (h.text:GetStringHeight() or 14) + 3 + (h.unter:GetStringHeight() or 12) + 12 + 24 + 14
    h:SetHeight(math.max(96, hoehe))
    h.ansehen:ClearAllPoints()
    h.ansehen:SetPoint("TOPLEFT", h.unter, "BOTTOMLEFT", 0, -8)
    h.spaeter:ClearAllPoints()
    h.spaeter:SetPoint("LEFT", h.ansehen, "RIGHT", 6, 0)
    h:Show()
end

-- ---------------------------------------------------------------------------
-- Ansicht "Bestellungen"
-- ---------------------------------------------------------------------------
function B.AnsichtBauen(f)
    local a = O.Rahmen("Frame", nil, f)
    a:SetPoint("TOPLEFT", 18, -52)
    a:SetPoint("BOTTOMRIGHT", -18, 16)
    a:Hide()
    a.spalten = {}
    for i, titel in ipairs({ "Bei dir bestellt", "Deine Bestellungen" }) do
        local sp = O.Rahmen("Frame", nil, a)
        sp:SetPoint("TOP", 0, 0)
        sp:SetPoint("BOTTOM", 0, 0)
        if i == 1 then
            sp:SetPoint("LEFT", 0, 0)
            sp:SetPoint("RIGHT", a, "CENTER", -11, 0)
        else
            sp:SetPoint("LEFT", a, "CENTER", 11, 0)
            sp:SetPoint("RIGHT", 0, 0)
        end
        sp.titel = Schrift(sp, "GameFontNormalLarge")
        sp.titel:SetPoint("TOPLEFT", 2, -2)
        sp.titel:SetText(titel)
        sp.zahl = Schrift(sp, "GameFontDisableSmall", false)
        sp.zahl:SetPoint("TOPRIGHT", -26, -6)
        sp.scroll, sp.inhalt = Liste(sp)
        sp.scroll:SetPoint("TOPLEFT", 0, -28)
        sp.scroll:SetPoint("BOTTOMRIGHT", -24, 22)
        sp.leer = Schrift(sp.inhalt, "GameFontHighlight")
        sp.leer:SetPoint("TOPLEFT", 4, -6)
        sp.leer:SetPoint("RIGHT", sp.inhalt, "RIGHT", -4, 0)
        sp.leer:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
        sp.fuss = Schrift(sp, "GameFontDisableSmall")
        sp.fuss:SetPoint("BOTTOMLEFT", 2, 2)
        sp.fuss:SetPoint("BOTTOMRIGHT", -2, 2)
        sp.scheine = {}
        a.spalten[i] = sp
    end
    a.trenner = a:CreateTexture(nil, "ARTWORK")
    a.trenner:SetWidth(1)
    a.trenner:SetPoint("TOP", 0, 0)
    a.trenner:SetPoint("BOTTOM", 0, 0)
    a.trenner:SetColorTexture(K.GOLD_DUNKEL[1], K.GOLD_DUNKEL[2], K.GOLD_DUNKEL[3], 0.7)
    a.spalten[1].fuss:SetText("Hast du geliefert, vermerke es mit „Geliefert“.")
    a.spalten[2].fuss:SetText("Hast du alles bekommen, schließe die Bestellung ab.")
    f.best = a
    return a
end

function B.SchnZeile(sch, i)
    local z = sch.zeilen[i]
    if z then
        return z
    end
    z = O.Rahmen("Frame", nil, sch)
    z:EnableMouse(true)
    z:SetScript("OnEnter", function(self) B.ZeilenTooltip(self) end)
    z:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    z.text = Schrift(z, "GameFontHighlight")
    z.text:SetPoint("TOPLEFT", 0, -5)
    B.Tinte(z.text)
    z.zusatz = Schrift(z, "GameFontHighlightSmall")
    z.zusatz:SetPoint("TOPLEFT", z.text, "BOTTOMLEFT", 0, -2)
    B.Tinte(z.zusatz, true)
    z.chip = Schrift(z, "GameFontHighlightSmall", false)
    z.k1 = B.Knopf(z, "Ich liefere", 96)
    z.k1:SetHeight(20)
    z.k2 = B.Knopf(z, "Geliefert", 80)
    z.k2:SetHeight(20)
    z.linie = z:CreateTexture(nil, "ARTWORK")
    z.linie:SetHeight(1)
    z.linie:SetPoint("BOTTOMLEFT")
    z.linie:SetPoint("BOTTOMRIGHT")
    z.linie:SetColorTexture(0.66, 0.58, 0.42, 0.7)
    sch.zeilen[i] = z
    return z
end

function B.SchnBauen(eltern)
    local s = O.Rahmen("Frame", nil, eltern, K.BACKDROP_VORLAGE)
    B.Pergament(s)
    s.titel = Schrift(s, "GameFontNormalLarge")
    s.titel:SetPoint("TOPLEFT", 14, -10)
    B.Tinte(s.titel)
    s.titel:SetPoint("RIGHT", -14, 0)
    if s.titel.SetWordWrap then
        s.titel:SetWordWrap(false)
    end
    -- Untertitel ("fuer ..., Uhrzeit") in eigener Zeile unter dem Titel, damit nichts ueberlappt
    s.unter = Schrift(s, "GameFontHighlightSmall")
    s.unter:SetPoint("TOPLEFT", s.titel, "BOTTOMLEFT", 0, -3)
    s.unter:SetPoint("RIGHT", -14, 0)
    if s.unter.SetWordWrap then
        s.unter:SetWordWrap(false)
    end
    B.Tinte(s.unter, true)
    s.linie = s:CreateTexture(nil, "ARTWORK")
    s.linie:SetHeight(2)
    s.linie:SetColorTexture(K.TINTE[1], K.TINTE[2], K.TINTE[3], 1)
    s.zeilen = {}
    s.fuss = Schrift(s, "GameFontHighlightSmall")
    B.Tinte(s.fuss, true)
    s.wert = Schrift(s, "GameFontHighlight")
    B.Tinte(s.wert)
    s.k1 = B.Knopf(s, "Abschließen", 100)
    s.k1:SetHeight(20)
    s.k2 = B.Knopf(s, "Stornieren", 100)
    s.k2:SetHeight(20)
    return s
end

function B.ChipText(st, zusatzZahl)
    local t = K.STATUS_TEXT[st]
    return Farbe(t[2], t[1])
end

function B.AnsichtZeigen(f)
    local a = f.best
    local eigene = B.EigeneNamen()
    local ich = UnitName("player")
    local ein, aus = {}, {}
    for _, o in pairs(B.Liste()) do
        if P.AndereFraktion(o.von) or P.AndereFraktion(o.an) then
            -- ab 1.2.1: Bestellungen meiner Charaktere der anderen Fraktion nicht zeigen
        elseif o.status == "offen" then
            if eigene[o.von] then
                table.insert(aus, o)
            elseif o.an == "" or eigene[o.an] then
                table.insert(ein, o)
            end
        elseif o.status == "zurueckgezogen" and not eigene[o.von] and not o.ausgeblendet then
            -- storniert: nur zeigen, wenn ich etwas zugesagt (und noch nicht geliefert) hatte
            for _, z in ipairs(o.zeilen) do
                local m = B.MeineZusage(z)
                if m and (m.n or 0) > 0 and not m.g then
                    table.insert(ein, o)
                    break
                end
            end
        end
    end
    table.sort(ein, function(x, y) return (x.at or 0) > (y.at or 0) end)
    table.sort(aus, function(x, y) return (x.at or 0) > (y.at or 0) end)
    local pool, bestand = BestandSammeln(SpielerFraktion()), nil
    local function vorrat(itemID)
        local n, tasche = 0, 0
        for _, q in ipairs(pool[itemID] or {}) do
            n = n + q.n
            if q.live then
                tasche = tasche + q.n
            end
        end
        return n, tasche
    end

    for i, liste in ipairs({ ein, aus }) do
        local sp = a.spalten[i]
        for _, s in ipairs(sp.scheine) do
            s:Hide()
            s.benutzt = false
        end
        sp.zahl:SetText(#liste > 0 and (#liste .. (i == 1 and " offen" or " laufend")) or "")
        local y = 0
        for _, o in ipairs(liste) do
            local s = Frei(sp.scheine, sp.inhalt, B.SchnBauen)
            s:ClearAllPoints()
            s:SetPoint("TOPLEFT", 0, -y)
            s:SetPoint("RIGHT", sp.inhalt, "RIGHT", 0, 0)
            local storniert = o.status == "zurueckgezogen"
            s.titel:SetText((i == 1 and ("Von " .. B.Anzeige(o.von)) or (o.an == "" and "An deine Gruppe" or ("An " .. B.Anzeige(o.an))))
                .. (storniert and Farbe("7a2a18", "  (storniert)") or ""))
            s.unter:SetText((o.fuer ~= "" and ("für " .. o.fuer .. ", ") or "") .. date("%H:%M", o.at or 0))
            local kopfH = 10 + (s.titel:GetStringHeight() or 18) + 3 + (s.unter:GetStringHeight() or 12) + 6
            s.linie:ClearAllPoints()
            s.linie:SetPoint("TOPLEFT", 14, -kopfH)
            s.linie:SetPoint("TOPRIGHT", -14, -kopfH)
            local zy = kopfH + 6
            for zi, z in ipairs(o.zeilen) do
                local r = B.SchnZeile(s, zi)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 14, -zy)
                r:SetPoint("RIGHT", s, "RIGHT", -14, 0)
                local name = B.ZName(z)
                r.itemID, r.rid = z.itemID, z.rezeptID
                local zu, gel, st = B.ZeilenStand(z)
                r.text:SetText(z.n .. "× " .. name)
                local eigen = B.MeineZusage(z)
                local kenne = z.rezeptID and B.KenneRezept(z.rezeptID)
                local zusatz
                r.k1:ClearAllPoints()
                r.k2:ClearAllPoints()
                r.k1:Hide()
                r.k2:Hide()
                r.chip:ClearAllPoints()
                r.chip:SetPoint("TOPRIGHT", 0, -6)
                if i == 1 and storniert then
                    zusatz = (eigen and (eigen.n or 0) > 0) and ("Deine Zusage (" .. eigen.n .. ", "
                        .. P.Weg(eigen.weg) .. ") ist damit hinfällig.") or ""
                elseif i == 1 and z.rezeptID and not kenne then
                    local wer = {}
                    for _, e in pairs(Kat.Daten().fremd) do
                        for _, ids in pairs(e.berufe or {}) do
                            if ids[z.rezeptID] then
                                wer[#wer + 1] = e.anzeige or nil
                            end
                        end
                    end
                    zusatz = "Dieses Rezept kennst du nicht."
                elseif i == 1 then
                    if eigen and eigen.n > 0 then
                        zusatz = eigen.g and ("Du hast " .. eigen.n .. " geliefert (" .. K.LIEFERWEGE[eigen.weg] .. ").")
                            or ("Du lieferst " .. eigen.n .. " (" .. K.LIEFERWEGE[eigen.weg] .. ").")
                        if not eigen.g then
                            r.k2:SetPoint("TOPRIGHT", 0, -4)
                            r.k2:SetScript("OnClick", function()
                                B.Zusagen(o, B.ZKey(z), eigen.n, eigen.weg, true)
                                FensterAktualisieren()
                            end)
                            r.k2:Show()
                            r.k1:SetText("Ändern")
                            r.k1:SetWidth(70)
                            r.k1:SetPoint("RIGHT", r.k2, "LEFT", -4, 0)
                            r.k1:Show()
                        end
                    elseif z.rezeptID then
                        zusatz = "Du kannst es (" .. B.Anzeige(kenne) .. ")."
                            .. (o.mats == "b" and (" Zutaten bringt " .. B.Anzeige(o.von) .. " mit.") or " Zutaten besorgst du.")
                        if st ~= "zugesagt" and st ~= "geliefert" then
                            r.k1:SetText("Ich liefere")
                            r.k1:SetWidth(96)
                            r.k1:SetPoint("TOPRIGHT", 0, -4)
                            r.k1:Show()
                        end
                    else
                        local n, tasche = vorrat(z.itemID)
                        zusatz = n == 0 and "Du hast keine." or (tasche > 0 and ("Du hast " .. tasche .. " in der Tasche.")
                            or ("Du hast " .. n .. " (Bank oder anderer Charakter)."))
                        if st ~= "zugesagt" and st ~= "geliefert" then
                            r.k1:SetText("Ich liefere")
                            r.k1:SetWidth(96)
                            r.k1:SetPoint("TOPRIGHT", 0, -4)
                            r.k1:Show()
                        end
                    end
                    if r.k1:IsShown() then
                        r.k1:SetScript("OnClick", function(self)
                            B.ZusageOeffnen(self, o, z)
                        end)
                        r.chip:SetPoint("TOPRIGHT", r.k1, "TOPLEFT", -8, -2)
                    end
                else
                    local teile = {}
                    for wer, sz in pairs(z.zusagen or {}) do
                        if (sz.n or 0) > 0 then
                            table.insert(teile, B.Anzeige(wer) .. (sz.g and " hat " .. sz.n .. " geliefert" or " liefert " .. sz.n)
                                .. " (" .. (K.LIEFERWEGE[sz.weg] or "?") .. ")")
                        end
                    end
                    table.sort(teile)
                    zusatz = #teile > 0 and table.concat(teile, ", ") or "Noch keine Zusage."
                    if zu > 0 and zu < z.n then
                        zusatz = zusatz .. ". Noch " .. (z.n - zu) .. " offen."
                    elseif #teile > 0 then
                        zusatz = zusatz .. "."
                    end
                    if z.rezeptID then
                        zusatz = zusatz .. (o.mats == "b" and " Du bringst die Zutaten mit." or " Der Hersteller besorgt die Zutaten.")
                    end
                end
                r.chip:SetText(storniert and Farbe("7a2a18", "storniert") or B.ChipText(st))
                r.text:SetPoint("RIGHT", r.chip, "LEFT", -6, 0)
                local ah = z.itemID and z.itemID > 0 and A.Text(z.itemID, false, true)
                if ah then
                    zusatz = (zusatz and zusatz ~= "") and (zusatz .. "\n" .. ah) or ah
                end
                r.zusatz:SetText(zusatz or "")
                r.zusatz:SetPoint("RIGHT", r, "RIGHT", 0, 0)
                local h = 5 + (r.text:GetStringHeight() or 14) + 2 + (r.zusatz:GetStringHeight() or 12) + 7
                r:SetHeight(h)
                r:Show()
                zy = zy + h
            end
            for zj = #o.zeilen + 1, #s.zeilen do
                s.zeilen[zj]:Hide()
            end
            -- Wert im Auktionshaus
            local werte = {}
            for _, z in ipairs(o.zeilen) do
                if z.itemID and z.itemID > 0 then
                    table.insert(werte, { itemID = z.itemID, n = z.n })
                end
            end
            local wert = A.KostenText(werte, true)
            s.wert:ClearAllPoints()
            s.wert:SetPoint("TOPLEFT", 14, -(zy + 7))
            s.wert:SetPoint("RIGHT", s, "RIGHT", -14, 0)
            s.wert:SetText(wert and ("Wert im Auktionshaus " .. wert) or "")
            s.wert:SetShown(wert ~= nil)
            if wert then
                zy = zy + 7 + (s.wert:GetStringHeight() or 14)
            end
            -- Fuss
            s.k1:Hide()
            s.k2:Hide()
            s.fuss:ClearAllPoints()
            s.fuss:SetPoint("TOPLEFT", 14, -(zy + 8))
            local fh = 0
            if i == 1 and storniert then
                s.k1:SetText("Ausblenden")
                s.k1:SetPoint("TOPRIGHT", -12, -(zy + 6))
                s.k1:SetScript("OnClick", function()
                    o.ausgeblendet = true
                    FensterAktualisieren()
                end)
                s.k1:Show()
                s.fuss:SetPoint("RIGHT", s.k1, "LEFT", -8, 0)
                s.fuss:SetText(B.Anzeige(o.von) .. " hat storniert.")
                fh = 30
            elseif i == 1 then
                s.fuss:SetPoint("RIGHT", s, "RIGHT", -14, 0)
                s.fuss:SetText(o.notiz ~= "" and ("„" .. o.notiz .. "“") or "")
                fh = o.notiz ~= "" and ((s.fuss:GetStringHeight() or 12) + 8) or 0
            else
                s.k1:SetText("Abschließen")
                s.k2:SetText("Stornieren")
                s.k2:SetPoint("TOPRIGHT", -12, -(zy + 6))
                s.k2:SetScript("OnClick", function()
                    P.StornoOeffnen("best", o)
                end)
                s.k2:Show()
                s.k1:SetPoint("RIGHT", s.k2, "LEFT", -4, 0)
                s.k1:SetScript("OnClick", function()
                    B.Status(o, "abgeschlossen")
                    FensterAktualisieren()
                end)
                s.k1:Show()
                s.fuss:SetPoint("RIGHT", s.k1, "LEFT", -8, 0)
                local gesehen = {}
                for n in pairs(o.gesehen or {}) do
                    table.insert(gesehen, B.Anzeige(n))
                end
                table.sort(gesehen)
                s.fuss:SetText(#gesehen > 0 and ("Gesehen von " .. table.concat(gesehen, ", ") .. ".")
                    or (B.InGruppe() and "Gesendet. Noch keine Antwort."
                        or "Wartet: wird gesendet, sobald ihr zusammen in einer Gruppe seid."))
                fh = math.max(26, (s.fuss:GetStringHeight() or 12) + 8)
            end
            local hoehe = zy + fh + 12
            s:SetHeight(hoehe)
            s:Show()
            y = y + hoehe + 10
        end
        sp.leer:SetShown(#liste == 0)
        sp.leer:SetText(i == 1 and "Gerade hat niemand bei dir bestellt."
            or "Du hast nichts bestellt. In der Werkstatt kannst du fehlende Zutaten bestellen.")
        sp.inhalt:SetHeight(math.max(10, y))
    end
end

-- ---------------------------------------------------------------------------
-- Planauftraege (Version 0.6)
-- Ein Planauftrag ist eine vorgemerkte Herstellung (nur ein Vermerk).
-- Bestellungen, die waehrenddessen gesendet werden, gehoeren dazu. Was die Gruppe
-- dafuer zugesagt (aber noch nicht geliefert) hat, verringert den offenen Bedarf.
-- ---------------------------------------------------------------------------
P.auf = {} -- nur fuer diese Sitzung: aufgeklappte Planauftraege
P.zuKlapp = {} -- nur fuer diese Sitzung: zugeklappte Unter-Zutaten im Planauftrag

function P.Liste()
    local d = Daten()
    d.plans = d.plans or {}
    return d.plans
end

-- Ist der Name einer meiner Charaktere der ANDEREN Fraktion? (ab 1.2.1)
function P.AndereFraktion(name)
    if not name or name == "" then
        return false
    end
    local fraktion = SpielerFraktion()
    for _, c in pairs(Daten().characters) do
        if c.faction and c.faction ~= fraktion and c.name
            and (name == c.name or name == c.voll or (B.Gleich and B.Gleich(name, c.voll or c.name))) then
            return true
        end
    end
    return false
end

-- Gehoert der Planauftrag zum gerade gespielten Charakter? (ab 1.2)
function P.VomSpieler(plan)
    local ich = UnitName("player")
    if not plan.wer or plan.wer == "" or plan.wer == ich then
        return true
    end
    return B.Gleich and B.Gleich(plan.wer, ich) and true or false
end

function P.Plan(rezeptID)
    return rezeptID and P.Liste()[rezeptID] or nil
end

function P.Zeit(at)
    at = at or 0
    if date("%Y%m%d", at) == date("%Y%m%d") then
        return "heute " .. date("%H:%M", at)
    end
    return date("%d.%m. %H:%M", at)
end

-- eigene offene Bestellungen, die zu einem Planauftrag gehoeren
function P.Bestellungen(plan)
    local liste = {}
    if not plan then
        return liste
    end
    local eigene = B.EigeneNamen()
    for _, o in pairs(B.Liste()) do
        if o.plan == plan.id and o.status == "offen" and eigene[o.von] then
            table.insert(liste, o)
        end
    end
    table.sort(liste, function(x, y) return (x.at or 0) < (y.at or 0) end)
    return liste
end

-- Zusagen je Gegenstand: { [itemID] = { liste = {{wer, n, weg}}, bestellt = noch ohne Zusage } }
function P.Zusagen(rezeptID)
    local plan = P.Plan(rezeptID)
    if not plan then
        return nil
    end
    local zu = {}
    for _, o in ipairs(P.Bestellungen(plan)) do
        for _, z in ipairs(o.zeilen or {}) do
            local e = zu[z.itemID] or { liste = {}, bestellt = 0 }
            zu[z.itemID] = e
            local summe = 0
            for wer, s in pairs(z.zusagen or {}) do
                if (s.n or 0) > 0 then
                    summe = summe + s.n
                    -- Geliefertes liegt danach im Bestand und zaehlt dort
                    if not s.g then
                        table.insert(e.liste, { wer = wer, n = s.n, weg = s.weg })
                    else
                        e.geliefert = e.geliefert or {}
                        table.insert(e.geliefert, { wer = wer, n = s.n, weg = s.weg })
                    end
                end
            end
            e.bestellt = e.bestellt + math.max(0, (z.n or 0) - summe)
        end
    end
    -- Planauftrag fuer jemanden, der die Zutaten mitbringt: die zaehlen wie zugesagt
    local r = GuildERPData.recipes[rezeptID]
    for oid, f in pairs(plan.fuer or {}) do
        local o = B.Liste()[oid]
        if f.mats == "b" and o and o.status == "offen" and r and r.reagents then
            local laeufe = math.ceil((f.n or 1) / (r.numMade or 1))
            for _, rg in ipairs(r.reagents) do
                local e = zu[rg.itemID] or { liste = {}, bestellt = 0 }
                zu[rg.itemID] = e
                table.insert(e.liste, 1, { wer = f.von or "?", n = rg.count * laeufe, mit = true })
            end
        end
    end
    for _, e in pairs(zu) do
        table.sort(e.liste, function(x, y)
            if (x.mit and true or false) ~= (y.mit and true or false) then
                return x.mit and true or false
            end
            return x.wer < y.wer
        end)
    end
    return zu
end

-- Zusage auf eine Rezept-Bestellung als Planauftrag uebernehmen (oder Menge anpassen)
function P.Uebernehmen(o, z, n)
    local rid = z.rezeptID
    if not rid or not GuildERPData.recipes[rid] then
        return
    end
    local plan = P.Plan(rid)
    if not plan then
        plan = { id = B.Vorname(B.Ich()) .. "-P" .. time(), rezeptID = rid, menge = 0,
            wer = B.Vorname(B.KenneRezept(rid) or UnitName("player")), at = time(), fuer = {} }
        P.Liste()[rid] = plan
    end
    plan.fuer = plan.fuer or {}
    local alt = plan.fuer[o.id] and plan.fuer[o.id].n or 0
    if n <= 0 then
        plan.fuer[o.id] = nil
    else
        plan.fuer[o.id] = { n = n, von = o.von, mats = o.mats }
    end
    plan.menge = math.max(1, (plan.menge or 0) + n - alt)
    Melden("Als Planauftrag übernommen: " .. plan.menge .. "× " .. B.ZName(z) .. ". Du findest ihn unter „Planaufträge“.")
end

-- blaue Zeilen unter einer Zutat: "+2 zugesagt: Zwerg Pudel, direkt handeln"
function P.Weg(nr)
    local w = K.LIEFERWEGE[nr] or "?"
    return string.lower(string.sub(w, 1, 1)) .. string.sub(w, 2)
end

function P.ZusageText(zeile)
    local teile = {}
    for _, s in ipairs(zeile.zusagen or {}) do
        if s.mit then
            table.insert(teile, Farbe(K.STATUS_HEX.blau, "+" .. s.n .. " bringt " .. B.Anzeige(s.wer) .. " mit"))
        else
            table.insert(teile, Farbe(K.STATUS_HEX.blau, "+" .. s.n .. " zugesagt: " .. B.Anzeige(s.wer) .. ", " .. P.Weg(s.weg)))
        end
    end
    if (zeile.bestellt or 0) > 0 then
        local mehr = zeile.zusagen and #zeile.zusagen > 0
        table.insert(teile, Farbe("b9b2a0", (mehr and ("Die übrigen " .. zeile.bestellt .. " sind bestellt")
            or (zeile.bestellt == zeile.rest and "Bestellt" or (zeile.bestellt .. " bestellt"))) .. ", noch keine Zusage"))
    end
    for _, s in ipairs(zeile.geliefert or {}) do
        table.insert(teile, Farbe("b9b2a0", s.wer .. " hat " .. s.n .. " geliefert (" .. P.Weg(s.weg)
            .. "). Es zählt, sobald es in deiner Tasche oder Bank liegt."))
    end
    return table.concat(teile, "\n")
end

function P.Vormerken(rezeptID, menge, wer)
    local r = GuildERPData.recipes[rezeptID]
    local ich = UnitName("player") or "?"
    local plan = { id = ich .. "-P" .. time(), rezeptID = rezeptID, menge = menge or 1, wer = wer, at = time() }
    P.Liste()[rezeptID] = plan
    -- schon gesendete Bestellungen fuer dieses Rezept dazunehmen
    local eigene = B.EigeneNamen()
    local name = r and r.name
    for _, o in pairs(B.Liste()) do
        if name and not o.plan and o.status == "offen" and eigene[o.von]
            and string.sub(o.fuer or "", 1, #name + 1) == name .. "," then
            o.plan = plan.id
        end
    end
    Melden("Als Planauftrag vorgemerkt. Du findest ihn oben unter „Planaufträge“.")
end

function P.Erledigt(rezeptID)
    local plan = P.Plan(rezeptID)
    if not plan then
        return
    end
    P.Liste()[rezeptID] = nil
    local offen = #P.Bestellungen(plan)
    Melden("Planauftrag erledigt." .. (offen > 0 and " Deine Bestellungen dazu bleiben unter „Bestellungen“, bis du sie abschließt." or ""))
end

-- Knopf und Schild auf der Rezept-Karte in der Werkstatt
function P.KarteZeigen(karte, rezeptID, plan, menge, wer)
    if not rezeptID then
        karte.plan:Hide()
        karte.schild:SetText("")
        return
    end
    if plan then
        karte.plan:SetText("Erledigt")
        karte.plan:SetWidth(84)
        karte.plan.tip = { "Planauftrag erledigt", "Nimmt den Planauftrag aus der Liste. Deine Bestellungen bleiben unter „Bestellungen“." }
        karte.plan:SetScript("OnClick", function()
            P.Erledigt(rezeptID)
            FensterAktualisieren()
        end)
        karte.schild:SetText(Farbe(K.STATUS_HEX.blau, "Planauftrag seit " .. P.Zeit(plan.at)))
    else
        karte.plan:SetText("Vormerken")
        karte.plan:SetWidth(100)
        karte.plan.tip = { "Als Planauftrag vormerken", "Merkt dir diese Herstellung vor. Was du danach bestellst, gehört dazu: "
            .. "Sagt jemand aus deiner Gruppe eine Lieferung zu, sinkt hier der Bedarf (blau)." }
        karte.plan:SetScript("OnClick", function()
            P.Vormerken(rezeptID, menge, wer)
            FensterAktualisieren()
        end)
        karte.schild:SetText("")
    end
    karte.plan:Show()
end

-- ----- Ansicht "Planauftraege" -----
function P.AnsichtBauen(f)
    local a = O.Rahmen("Frame", nil, f)
    a:SetPoint("TOPLEFT", 18, -52)
    a:SetPoint("BOTTOMRIGHT", -18, 16)
    a:Hide()
    a.titel = Schrift(a, "GameFontNormalLarge")
    a.titel:SetPoint("TOPLEFT", 2, -2)
    a.titel:SetText("Vorgemerkt")
    a.zahl = Schrift(a, "GameFontDisableSmall", false)
    a.zahl:SetPoint("TOPRIGHT", -26, -6)
    a.scroll, a.inhalt = Liste(a)
    a.scroll:SetPoint("TOPLEFT", 0, -28)
    a.scroll:SetPoint("BOTTOMRIGHT", -24, 24)
    a.leer = Schrift(a.inhalt, "GameFontHighlight")
    a.leer:SetPoint("TOPLEFT", 4, -6)
    a.leer:SetPoint("RIGHT", a.inhalt, "RIGHT", -4, 0)
    a.leer:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    a.leer:SetText("Noch nichts vorgemerkt. Wähle in der Werkstatt ein Rezept und klicke oben auf der Karte „Vormerken“.")
    a.fuss = Schrift(a, "GameFontDisableSmall")
    a.fuss:SetPoint("BOTTOMLEFT", 2, 2)
    a.fuss:SetPoint("BOTTOMRIGHT", -2, 2)
    a.fuss:SetText("Was deine Gruppe für einen Planauftrag zusagt, zählt hier und in der Werkstatt blau mit, bis es geliefert ist.")
    a.karten = {}
    f.plan = a
    return a
end

function P.KarteBauen(eltern)
    local k = O.Rahmen("Frame", nil, eltern, K.BACKDROP_VORLAGE)
    Flaeche(k, { 0.11, 0.10, 0.08, 1 }, { K.GOLD_DUNKEL[1], K.GOLD_DUNKEL[2], K.GOLD_DUNKEL[3], 1 })
    k.kopf = O.Rahmen("Button", nil, k)
    k.kopf:SetPoint("TOPLEFT", 0, 0)
    k.kopf:SetPoint("TOPRIGHT", 0, 0)
    k.kopf:SetHeight(84)
    local hl = k.kopf:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.03)
    k.knopf = k.kopf:CreateTexture(nil, "ARTWORK")
    k.knopf:SetSize(12, 12)
    k.knopf:SetPoint("TOPLEFT", 12, -20)
    k.icon = k.kopf:CreateTexture(nil, "ARTWORK")
    k.icon:SetSize(36, 36)
    k.icon:SetPoint("TOPLEFT", 32, -10)
    k.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    -- Aktionszeile unten (ab 1.0.1): Hauptknopf, Auftragsnetz, Stornieren leise rechts
    k.aktionen = O.Rahmen("Frame", nil, k)
    k.aktionen:SetHeight(38)
    k.aktionen.linie = k.aktionen:CreateTexture(nil, "ARTWORK")
    k.aktionen.linie:SetHeight(1)
    k.aktionen.linie:SetPoint("TOPLEFT", 1, 0)
    k.aktionen.linie:SetPoint("TOPRIGHT", -1, 0)
    k.aktionen.linie:SetColorTexture(1, 1, 1, 0.07)
    k.werkstatt = O.Rahmen("Button", nil, k.aktionen, "UIPanelButtonTemplate")
    k.werkstatt:SetHeight(24)
    k.werkstatt:SetPoint("LEFT", 80, -1)
    k.netz = O.Rahmen("Button", nil, k.aktionen, "UIPanelButtonTemplate")
    k.netz:SetHeight(24)
    k.netz:SetPoint("LEFT", k.werkstatt, "RIGHT", 8, 0)
    k.netz:SetText("Auftragsnetz")
    k.storno = O.Rahmen("Button", nil, k.aktionen)
    k.storno:SetHeight(22)
    k.storno:SetPoint("RIGHT", -14, -1)
    k.storno.text = Schrift(k.storno, "GameFontNormal", false)
    k.storno.text:SetPoint("CENTER", 0, 1)
    k.storno.text:SetText("Stornieren")
    k.storno.text:SetTextColor(0.82, 0.44, 0.36)
    k.storno.strich = k.storno:CreateTexture(nil, "ARTWORK")
    k.storno.strich:SetHeight(1)
    k.storno.strich:SetPoint("TOPLEFT", k.storno.text, "BOTTOMLEFT", 0, -1)
    k.storno.strich:SetPoint("TOPRIGHT", k.storno.text, "BOTTOMRIGHT", 0, -1)
    k.storno.strich:SetColorTexture(0.82, 0.44, 0.36, 0.5)
    k.storno:SetScript("OnEnter", function(self)
        self.text:SetTextColor(0.95, 0.58, 0.48)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("Planauftrag stornieren")
            GameTooltip:AddLine("Du siehst vorher, was daran hängt, und wählst selbst aus.", 1, 0.82, 0, true)
            GameTooltip:Show()
        end
    end)
    k.storno:SetScript("OnLeave", function(self)
        self.text:SetTextColor(0.82, 0.44, 0.36)
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    -- roter Hinweis: der Besteller hat storniert
    k.banner = O.Rahmen("Frame", nil, k, K.BACKDROP_VORLAGE)
    k.banner:SetPoint("TOPLEFT", 1, -1)
    k.banner:SetPoint("TOPRIGHT", -1, -1)
    k.banner:SetHeight(34)
    Flaeche(k.banner, { 0.23, 0.09, 0.07, 1 }, { 0.88, 0.38, 0.29, 1 })
    k.banner.behalten = O.Rahmen("Button", nil, k.banner, "UIPanelButtonTemplate")
    k.banner.behalten:SetSize(90, 22)
    k.banner.behalten:SetPoint("RIGHT", -8, 0)
    k.banner.behalten:SetText("Behalten")
    k.banner.auch = O.Rahmen("Button", nil, k.banner, "UIPanelButtonTemplate")
    k.banner.auch:SetSize(120, 22)
    k.banner.auch:SetPoint("RIGHT", k.banner.behalten, "LEFT", -6, 0)
    k.banner.auch:SetText("Auch stornieren")
    k.banner.text = Schrift(k.banner, "GameFontHighlightSmall")
    k.banner.text:SetPoint("LEFT", 12, 0)
    k.banner.text:SetPoint("RIGHT", k.banner.auch, "LEFT", -8, 0)
    k.banner.text:SetTextColor(0.95, 0.82, 0.78)
    k.banner:Hide()
    k.werkstatt:SetText("In der Werkstatt öffnen")
    -- Name in einer Zeile (zu lang: gekuerzt, voller Name im Tooltip), Menge direkt dahinter
    k.name = Schrift(k.kopf, "GameFontNormalLarge")
    k.name:SetPoint("TOPLEFT", 80, -10)
    if k.name.SetWordWrap then
        k.name:SetWordWrap(false)
    end
    if k.name.SetNonSpaceWrap then
        k.name:SetNonSpaceWrap(false)
    end
    k.menge = Schrift(k.kopf, "GameFontHighlight", false)
    k.menge:SetPoint("LEFT", k.name, "RIGHT", 8, 0)
    k.menge:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    k.unter = Schrift(k.kopf, "GameFontHighlightSmall")
    k.unter:SetPoint("TOPLEFT", k.name, "BOTTOMLEFT", 0, -4)
    k.unter:SetPoint("RIGHT", k.kopf, "RIGHT", -14, 0)
    k.unter:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    k.balken = {}
    k.satz = Schrift(k.kopf, "GameFontHighlightSmall")
    k.satz:SetPoint("RIGHT", k.kopf, "RIGHT", -14, 0)
    k.satz:SetTextColor(0.85, 0.80, 0.66)
    k.kopf:SetScript("OnEnter", function(self)
        if GameTooltip and self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. self.itemID)
            GameTooltip:Show()
        end
    end)
    k.kopf:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    k.zeilen = {}
    return k
end

function P.ZeileBauen(k, i)
    local z = k.zeilen[i]
    if z then
        return z
    end
    z = O.Rahmen("Button", nil, k)
    z.hg = z:CreateTexture(nil, "BACKGROUND")
    z.hg:SetAllPoints()
    z.linie = z:CreateTexture(nil, "ARTWORK")
    z.linie:SetHeight(1)
    z.linie:SetPoint("TOPLEFT")
    z.linie:SetPoint("TOPRIGHT")
    z.linie:SetColorTexture(1, 1, 1, 0.06)
    z.knopf = z:CreateTexture(nil, "ARTWORK")
    z.knopf:SetSize(12, 12)
    -- Leitlinie zur uebergeordneten Zutat
    z.leit = z:CreateTexture(nil, "ARTWORK")
    z.leit:SetWidth(1)
    z.leit:SetColorTexture(K.GOLD_DUNKEL[1], K.GOLD_DUNKEL[2], K.GOLD_DUNKEL[3], 1)
    z.leitQuer = z:CreateTexture(nil, "ARTWORK")
    z.leitQuer:SetHeight(1)
    z.leitQuer:SetWidth(10)
    z.leitQuer:SetColorTexture(K.GOLD_DUNKEL[1], K.GOLD_DUNKEL[2], K.GOLD_DUNKEL[3], 1)
    z:SetScript("OnClick", function(self)
        if self.schluessel then
            P.zuKlapp[self.schluessel] = not P.zuKlapp[self.schluessel]
            FensterAktualisieren()
        end
    end)
    z:SetScript("OnEnter", function(self)
        if GameTooltip and self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. self.itemID)
            GameTooltip:Show()
        end
    end)
    z:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    z.punkt = Raute(z, 8)
    z.zahl = Schrift(z, "GameFontHighlight", false)
    z.zahl:SetPoint("TOPRIGHT", -4, -7)
    z.name = Schrift(z, "GameFontHighlight")
    z.info = Schrift(z, "GameFontHighlightSmall")
    z.info:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    k.zeilen[i] = z
    return z
end

-- Wo liegt es, wer stellt her, wer hat zugesagt
function P.InfoText(zeile, fraktion)
    local teile = {}
    for _, q in ipairs(zeile.quellen or {}) do
        table.insert(teile, q.wer .. ", " .. q.wo .. ": " .. q.n .. (q.live and "" or ("  (" .. Alter(q.at) .. ")")))
    end
    local zeilen = {}
    if #teile > 0 then
        table.insert(zeilen, table.concat(teile, "  ·  "))
    end
    if zeile.wer and zeile.rezeptID then
        local r = GuildERPData.recipes[zeile.rezeptID]
        local verb = (r and r.profession == "Bergbau") and "verhüttet" or "stellt her"
        table.insert(zeilen, Farbe(K.STATUS_HEX.gelb, "Noch " .. zeile.rest .. " nötig – " .. verb .. ": "
            .. (HerstellerVon(zeile.rezeptID, zeile.wer) or "?") .. " (" .. zeile.laeufe .. "×)"))
    end
    local zu = P.ZusageText(zeile)
    if zu ~= "" then
        table.insert(zeilen, zu)
    end
    local ah = A.Text(zeile.itemID)
    if ah then
        table.insert(zeilen, ah)
    end
    if zeile.status == "rot" and not zeile.wer and (zeile.bestellt or 0) < zeile.rest then
        local h = HaendlerFuer(zeile.itemID, fraktion)
        table.insert(zeilen, Farbe(K.STATUS_HEX.rot, "Fehlt") .. (#h > 0 and (". Händler: " .. HaendlerText(h[1])) or ""))
    end
    return table.concat(zeilen, "\n")
end

function P.AnsichtZeigen(f)
    local a = f.plan
    local fraktion = SpielerFraktion()
    local ich = UnitName("player")
    -- ab 1.2: zuerst die Planauftraege des gespielten Charakters, die der anderen in einem
    -- eigenen Bereich darunter (auf-/zuklappbar, startet zugeklappt)
    local eigene, andere = {}, {}
    for _, plan in pairs(P.Liste()) do
        if not P.AndereFraktion(plan.wer) then
            table.insert(P.VomSpieler(plan) and eigene or andere, plan)
        end
    end
    local function nachZeit(x, y2) return (x.at or 0) < (y2.at or 0) end
    table.sort(eigene, nachZeit)
    table.sort(andere, nachZeit)
    local plaene = {}
    for _, plan in ipairs(eigene) do
        table.insert(plaene, plan)
    end
    if #andere > 0 then
        table.insert(plaene, { kopf = true })
        if P.andereAuf then
            for _, plan in ipairs(andere) do
                table.insert(plaene, plan)
            end
        end
    end
    for _, k in ipairs(a.karten) do
        k:Hide()
        k.benutzt = false
    end
    a.koepfe = a.koepfe or {}
    for _, k in ipairs(a.koepfe) do
        k:Hide()
        k.benutzt = false
    end
    local stand = A.Stand()
    local gesamt = #eigene + #andere
    a.zahl:SetText(gesamt > 0 and (#eigene .. " für " .. (ich or "dich") .. (#andere > 0 and ("  ·  " .. #andere .. " bei anderen") or "")
        .. (stand and ("  ·  Preise von " .. P.Zeit(stand)) or "")) or "")
    a.leer:ClearAllPoints()
    a.leer:SetPoint("TOPLEFT", 4, -6)
    a.leer:SetPoint("RIGHT", a.inhalt, "RIGHT", -4, 0)
    if gesamt == 0 then
        a.leer:SetText("Noch nichts vorgemerkt. Wähle in der Werkstatt ein Rezept und klicke oben auf der Karte „Vormerken“.")
    else
        a.leer:SetText("Für " .. (ich or "dich") .. " ist nichts vorgemerkt.")
    end
    a.leer:SetShown(#eigene == 0)
    local y = #eigene == 0 and 34 or 0
    for _, plan in ipairs(plaene) do
      if plan.kopf then
        local k = Frei(a.koepfe, a.inhalt, Kat.KopfBauen)
        k:ClearAllPoints()
        k:SetPoint("TOPLEFT", 0, -y)
        k:SetPoint("RIGHT", a.inhalt, "RIGHT", 0, 0)
        k.text:SetText("Planaufträge anderer Charaktere")
        k.zahl:SetText(#andere)
        O.KopfIcon(k, P.andereAuf and true or false)
        k:SetScript("OnClick", function()
            P.andereAuf = not P.andereAuf
            FensterAktualisieren()
        end)
        k:Show()
        y = y + 40
      else
        local rid = plan.rezeptID
        local r = GuildERPData.recipes[rid]
        local k = Frei(a.karten, a.inhalt, P.KarteBauen)
        k:ClearAllPoints()
        k:SetPoint("TOPLEFT", 0, -y)
        k:SetPoint("RIGHT", a.inhalt, "RIGHT", 0, 0)
        -- hat ein Besteller storniert, fuer den dieser Planauftrag gedacht war?
        local weg = {}
        for oid, fe in pairs(plan.fuer or {}) do
            local oo = B.Liste()[oid]
            if oo and oo.status == "zurueckgezogen" and not fe.quittiert then
                table.insert(weg, { oid = oid, fe = fe })
            end
        end
        local bannerH = #weg > 0 and 36 or 0
        k.kopf:ClearAllPoints()
        k.kopf:SetPoint("TOPLEFT", 0, -bannerH)
        k.kopf:SetPoint("TOPRIGHT", 0, -bannerH)
        k.banner:SetShown(#weg > 0)
        if #weg > 0 then
            local namen = {}
            for _, w in ipairs(weg) do
                table.insert(namen, B.Anzeige(w.fe.von))
            end
            k.banner.text:SetText(Farbe("e0604b", "! ") .. table.concat(namen, ", ") .. (#namen == 1 and " hat die Bestellung storniert."
                or " haben die Bestellungen storniert.") .. " Dieser Planauftrag war dafür gedacht.")
            k.banner.behalten:SetScript("OnClick", function()
                for _, w in ipairs(weg) do
                    w.fe.quittiert = true
                end
                FensterAktualisieren()
            end)
            k.banner.auch:SetScript("OnClick", function()
                P.StornoOeffnen("plan", plan)
            end)
        end
        k.storno:SetScript("OnClick", function()
            P.StornoOeffnen("plan", plan)
        end)
        local offen = P.auf[plan.id]
        if offen == nil then
            offen = #eigene == 1 and P.VomSpieler(plan)
        end
        k.knopf:SetTexture(offen and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
        k.kopf:SetScript("OnClick", function()
            P.auf[plan.id] = not offen
            FensterAktualisieren()
        end)
        k.netz:SetScript("OnClick", function()
            P.NetzOeffnen(rid)
        end)
        k.werkstatt:SetScript("OnClick", function()
            local s = Daten().settings
            s.wunsch, s.menge, s.ansicht = rid, plan.menge or 1, "werk"
            if plan.wer then
                wahlHersteller[rid] = plan.wer
            end
            FensterAktualisieren()
        end)
        local q = r and ItemQualitaet(r.itemID)
        k.icon:SetTexture(r and (ItemIcon(r.itemID) or r.icon) or K.ICON_UNBEKANNT)
        local breite = (a.inhalt:GetWidth() or 820)
        if breite <= 0 then
            breite = 820
        end
        local textBreite = breite - 80 - 14
        k.kopf.itemID = r and r.itemID
        k.name:SetText(Farbe(K.QUALITAET_HEX[q or 1] or "ffffff", r and r.name or "Unbekanntes Rezept"))
        k.menge:SetText((plan.menge or 1) .. "×")
        local mengeB = (k.menge:GetStringWidth() or 24) + 8
        k.name:SetWidth(math.max(80, math.min((k.name:GetStringWidth() or textBreite) + 2, textBreite - mengeB)))
        local fuer = {}
        for oid, fe in pairs(plan.fuer or {}) do
            local oo = B.Liste()[oid]
            if not oo or oo.status ~= "zurueckgezogen" or not fe.quittiert then
                table.insert(fuer, B.Anzeige(fe.von) .. " (" .. fe.n .. "×)")
            end
        end
        table.sort(fuer)
        k.unter:SetText((plan.wer or "?") .. (plan.wer == ich and " (du)" or "") .. " stellt her"
            .. (#fuer > 0 and (" für " .. table.concat(fuer, ", ")) or "")
            .. ", vorgemerkt " .. P.Zeit(plan.at))
        -- Hoehen messen, damit nichts ueberlappt (auch bei grosser Spielschrift)
        local nameH = math.max(18, k.name:GetStringHeight() or 18)
        local unterH = k.unter:GetStringHeight() or 13
        local balkenY = 10 + nameH + 4 + unterH + 8
        local liste = r and Stueckliste(rid, plan.menge or 1, fraktion) or {}
        -- Ampel-Balken und Satz
        local zahl = { tasche = 0, gruen = 0, blau = 0, gelb = 0, rot = 0 }
        for _, z in ipairs(liste) do
            local st = z.tasche and "tasche" or z.status
            zahl[st] = zahl[st] + 1
        end
        local n = math.max(1, #liste)
        local seg = (textBreite - (n - 1) * 3) / n
        for i, z in ipairs(liste) do
            local t = k.balken[i]
            if not t then
                t = k.kopf:CreateTexture(nil, "ARTWORK")
                t:SetHeight(8)
                t:SetTexture(K.WEISS)
                k.balken[i] = t
            end
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", 80 + (i - 1) * (seg + 3), -balkenY)
            t:SetWidth(seg)
            Faerben(t, z.tasche and "tasche" or z.status)
            t:Show()
        end
        for j = #liste + 1, #k.balken do
            k.balken[j]:Hide()
        end
        local satz
        local bestellungen = P.Bestellungen(plan)
        if not r then
            satz = "Dieses Rezept kennt gerade keiner deiner Charaktere."
        elseif #liste > 0 and zahl.tasche == #liste then
            satz = Farbe(K.STATUS_HEX.tasche, "Alles in deiner Tasche. Bereit zum Herstellen.")
        else
            local teile = { (zahl.tasche + zahl.gruen) .. " von " .. #liste .. " Zutaten da" }
            if zahl.blau > 0 then
                table.insert(teile, Farbe(K.STATUS_HEX.blau, zahl.blau .. " zugesagt"))
            end
            if zahl.gelb > 0 then
                table.insert(teile, zahl.gelb .. " herstellbar")
            end
            if zahl.rot > 0 then
                table.insert(teile, Farbe(K.STATUS_HEX.rot, zahl.rot .. (zahl.rot == 1 and " fehlt" or " fehlen")))
            end
            satz = table.concat(teile, ", ") .. "."
            if #bestellungen > 0 then
                local o = bestellungen[#bestellungen]
                satz = satz .. " Bestellung " .. (o.an == "" and "an die Gruppe" or ("an " .. o.an)) .. " läuft."
            elseif zahl.rot > 0 then
                satz = satz .. " Noch nichts bestellt."
            end
            local kosten = A.KostenText(A.Fehlendes(liste))
            if kosten then
                satz = satz .. " Fehlendes im AH " .. kosten .. "."
            end
        end
        k.satz:ClearAllPoints()
        k.satz:SetPoint("TOPLEFT", 80, -(balkenY + 8 + 7))
        k.satz:SetPoint("RIGHT", k.kopf, "RIGHT", -14, 0)
        k.satz:SetText(satz)
        local kopfH = balkenY + 8 + 7 + (k.satz:GetStringHeight() or 14) + 12
        k.kopf:SetHeight(kopfH)
        k.knopf:ClearAllPoints()
        k.knopf:SetPoint("TOPLEFT", 12, -(10 + nameH / 2 - 6))
        -- Knoepfe passend zur Schrift breit machen
        k.werkstatt:SetWidth((k.werkstatt:GetFontString() and k.werkstatt:GetFontString():GetStringWidth() or 150) + 28)
        k.netz:SetWidth((k.netz:GetFontString() and k.netz:GetFontString():GetStringWidth() or 90) + 28)
        k.storno:SetWidth((k.storno.text:GetStringWidth() or 70) + 6)
        k.aktionen:ClearAllPoints()
        k.aktionen:SetPoint("TOPLEFT", 0, -(bannerH + kopfH))
        k.aktionen:SetPoint("TOPRIGHT", 0, -(bannerH + kopfH))
        -- aufgeklappt: jede Zutat mit Ort und Zusagen
        local zy = bannerH + kopfH + 38
        local i = 0
        local function zeigen(zeile, tiefe, pfad)
            i = i + 1
            local z = P.ZeileBauen(k, i)
            z:ClearAllPoints()
            z:SetPoint("TOPLEFT", 12, -zy)
            z:SetPoint("RIGHT", k, "RIGHT", -12, 0)
            local x = 22 + (tiefe - 1) * 22
            local farbe = zeile.tasche and "tasche" or zeile.status
            local schluessel = zeile.kinder and (pfad .. ">" .. zeile.itemID) or nil
            local zu = schluessel and P.zuKlapp[schluessel]
            z.schluessel, z.itemID = schluessel, zeile.itemID
            z.hg:SetColorTexture(1, 1, 1, tiefe > 1 and 0.025 or 0)
            z.knopf:ClearAllPoints()
            z.knopf:SetPoint("TOPLEFT", x - 16, -9)
            z.knopf:SetTexture(zu and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
            z.knopf:SetShown(schluessel ~= nil)
            z.leit:ClearAllPoints()
            z.leit:SetPoint("TOPLEFT", x - 30, 0)
            z.leit:SetPoint("BOTTOMLEFT", x - 30, 0)
            z.leitQuer:ClearAllPoints()
            z.leitQuer:SetPoint("TOPLEFT", x - 30, -14)
            z.leit:SetShown(tiefe > 1)
            z.leitQuer:SetShown(tiefe > 1 and not schluessel)
            z.punkt:ClearAllPoints()
            z.punkt:SetPoint("TOPLEFT", x, -10)
            Faerben(z.punkt, farbe)
            z.zahl:SetText(Farbe(K.STATUS_HEX[farbe], zeile.da) .. Farbe("77715f", " / " .. zeile.bedarf))
            z.name:ClearAllPoints()
            z.name:SetPoint("TOPLEFT", x + 16, -7)
            z.name:SetPoint("RIGHT", z.zahl, "LEFT", -8, 0)
            z.name:SetText(ItemName(zeile.itemID) or Farbe("9a9384", "Name wird geladen …"))
            z.info:ClearAllPoints()
            z.info:SetPoint("TOPLEFT", z.name, "BOTTOMLEFT", 0, -2)
            z.info:SetPoint("RIGHT", z, "RIGHT", -60, 0)
            local info = P.InfoText(zeile, fraktion)
            z.info:SetText(info)
            local h = 7 + (z.name:GetStringHeight() or 14) + (info ~= "" and (2 + (z.info:GetStringHeight() or 12)) or 0) + 8
            z:SetHeight(h)
            z:Show()
            zy = zy + h
            if schluessel and not zu then
                for _, kind in ipairs(zeile.kinder) do
                    zeigen(kind, tiefe + 1, schluessel)
                end
            end
        end
        if offen then
            for _, zeile in ipairs(liste) do
                zeigen(zeile, 1, plan.id)
            end
        end
        for j = i + 1, #k.zeilen do
            k.zeilen[j]:Hide()
        end
        local hoehe = zy + (i > 0 and 8 or 0)
        k:SetHeight(hoehe)
        k:Show()
        y = y + hoehe + 10
      end
    end
    a.inhalt:SetHeight(math.max(10, y))
end

-- ----- Fenster "Auftragsnetz" (Version 0.7, nur Anzeige) -----
-- Kacheln von links nach rechts: was hergestellt wird -> Zutaten -> deren Zutaten.
-- Linien zeigen, woraus etwas hergestellt wird. Unter-Zutaten erscheinen nur, wenn die
-- Zutat nicht schon da ist (gleiche Bedarfsrechnung wie in der Werkstatt).
K.NETZ_LUECKE = 12

function P.NetzBauen()
    local n = O.Rahmen("Frame", "GuildERPNetz", UIParent, K.BACKDROP_VORLAGE)
    n:SetSize(900, 620)
    n:SetPoint("CENTER", 0, 20)
    n:SetFrameStrata("HIGH")
    n:SetToplevel(true)
    n:SetMovable(true)
    n:SetClampedToScreen(true)
    n:EnableMouse(true)
    if n.SetBackdrop then
        n:SetBackdrop(K.BACKDROP_RAHMEN)
    end
    n:RegisterForDrag("LeftButton")
    n:SetScript("OnDragStart", function() n:StartMoving() end)
    n:SetScript("OnDragStop", function() n:StopMovingOrSizing() end)
    table.insert(UISpecialFrames, "GuildERPNetz")
    n.icon = n:CreateTexture(nil, "ARTWORK")
    n.icon:SetSize(20, 20)
    n.icon:SetPoint("TOPLEFT", 18, -16)
    n.icon:SetTexture(K.ICON_REZEPT)
    n.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    n.titel = Schrift(n, "GameFontNormalLarge")
    n.titel:SetPoint("TOPLEFT", n.icon, "TOPRIGHT", 8, 2)
    n.titel:SetText("Auftragsnetz")
    n.unter = Schrift(n, "GameFontHighlightSmall", false)
    n.unter:SetPoint("TOPLEFT", n.titel, "BOTTOMLEFT", 0, -3)
    n.unter:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    local zu = O.Rahmen("Button", nil, n, "UIPanelCloseButton")
    zu:SetPoint("TOPRIGHT", -4, -4)
    zu:SetScript("OnClick", function() n:Hide() end)
    n.werkstatt = O.Rahmen("Button", nil, n, "UIPanelButtonTemplate")
    n.werkstatt:SetSize(180, 24)
    n.werkstatt:SetPoint("RIGHT", zu, "LEFT", -6, 0)
    n.werkstatt:SetText("In der Werkstatt öffnen")
    n.linie = n:CreateTexture(nil, "ARTWORK")
    n.linie:SetHeight(1)
    n.linie:SetPoint("TOPLEFT", 18, -52)
    n.linie:SetPoint("TOPRIGHT", -18, -52)
    n.linie:SetColorTexture(K.GOLD_DUNKEL[1], K.GOLD_DUNKEL[2], K.GOLD_DUNKEL[3], 0.8)
    n.spalten = {}
    n.scroll, n.inhalt = Liste(n)
    n.scroll:SetPoint("TOPLEFT", 18, -80)
    n.scroll:SetPoint("BOTTOMRIGHT", -40, 44)
    -- Legende
    local vorher
    for _, e in ipairs({ { "tasche", "in deiner Tasche" }, { "gruen", "woanders da" }, { "blau", "zugesagt" },
        { "gelb", "herstellbar" }, { "rot", "fehlt" } }) do
        local r = Raute(n, 7)
        Faerben(r, e[1])
        if vorher then
            r:SetPoint("LEFT", vorher, "RIGHT", 16, 0)
        else
            r:SetPoint("BOTTOMLEFT", 22, 20)
        end
        local t = Schrift(n, "GameFontHighlightSmall", false)
        t:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
        t:SetPoint("LEFT", r, "RIGHT", 5, 0)
        t:SetText(e[2])
        vorher = t
    end
    n.hinweis = Schrift(n, "GameFontDisableSmall", false)
    n.hinweis:SetPoint("BOTTOMRIGHT", -22, 16)
    n.hinweis:SetText("Eine Linie heißt: wird daraus hergestellt.")
    n.kacheln = {}
    n.striche = {}
    n:Hide()
    P.netz = n
    return n
end

function P.KachelBauen(eltern)
    local t = O.Rahmen("Button", nil, eltern, K.BACKDROP_VORLAGE)
    t.streifen = t:CreateTexture(nil, "ARTWORK")
    t.streifen:SetWidth(4)
    t.streifen:SetPoint("TOPLEFT", 1, -1)
    t.streifen:SetPoint("BOTTOMLEFT", 1, 1)
    t.streifen:SetTexture(K.WEISS)
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetPoint("TOPLEFT", 12, -8)
    t.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    t.zahl = Schrift(t, "GameFontHighlight", false)
    t.zahl:SetPoint("TOPRIGHT", -9, -8)
    t.name = Schrift(t, "GameFontHighlight")
    t.info = Schrift(t, "GameFontHighlightSmall")
    t.info:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    t:SetScript("OnEnter", function(self)
        if GameTooltip and self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. self.itemID)
            GameTooltip:Show()
        end
    end)
    t:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    return t
end

function P.Strich(n, x, y, w, h)
    local s
    for _, e in ipairs(n.striche) do
        if not e.benutzt then
            s = e
            break
        end
    end
    if not s then
        s = n.inhalt:CreateTexture(nil, "BACKGROUND")
        s:SetColorTexture(0.54, 0.45, 0.25, 1)
        table.insert(n.striche, s)
    end
    s.benutzt = true
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", n.inhalt, "TOPLEFT", x, -y)
    s:SetSize(math.max(2, w), math.max(2, h))
    s:Show()
end

function P.NetzOeffnen(rezeptID)
    local n = P.netz or P.NetzBauen()
    P.netzRezept = rezeptID
    n:Show()
    P.NetzZeigen()
end

function P.NetzZeigen()
    local n = P.netz
    local rid = P.netzRezept
    local plan = P.Plan(rid)
    local r = rid and GuildERPData.recipes[rid]
    if not n or not plan or not r then
        if n then
            n:Hide()
        end
        return
    end
    local fraktion = SpielerFraktion()
    local ich = UnitName("player")
    local menge = plan.menge or 1
    n.unter:SetText("Planauftrag " .. (r.name or "?") .. ", " .. menge .. "×  ·  vorgemerkt " .. P.Zeit(plan.at))
    n.werkstatt:SetScript("OnClick", function()
        local s = Daten().settings
        s.wunsch, s.menge, s.ansicht = rid, menge, "werk"
        if plan.wer then
            wahlHersteller[rid] = plan.wer
        end
        n:Hide()
        if not (Fenster and Fenster:IsShown()) then
            SlashCmdList.GUILDERP("")
        end
        FensterAktualisieren()
    end)
    for _, t in ipairs(n.kacheln) do
        t:Hide()
        t.benutzt = false
    end
    for _, s in ipairs(n.striche) do
        s:Hide()
        s.benutzt = false
    end
    local liste = Stueckliste(rid, menge, fraktion) or {}
    -- Baum: Wurzel = das Rezept selbst
    local zahl = { tasche = 0, gruen = 0, blau = 0, gelb = 0, rot = 0 }
    for _, z in ipairs(liste) do
        local st = z.tasche and "tasche" or z.status
        zahl[st] = zahl[st] + 1
    end
    local teile = { (zahl.tasche + zahl.gruen) .. " von " .. #liste .. " da" }
    for _, e in ipairs({ { "blau", " zugesagt" }, { "gelb", " herstellbar" }, { "rot", " fehlen" } }) do
        if zahl[e[1]] > 0 then
            table.insert(teile, zahl[e[1]] .. e[2])
        end
    end
    local wurzel = { wurzel = true, kinder = liste, itemID = r.itemID,
        status = #liste > 0 and zahl.tasche == #liste and "tasche" or (zahl.rot > 0 and "rot" or (zahl.gelb + zahl.blau > 0 and "gelb" or "gruen")) }
    wurzel.text = "Stellt her: " .. (plan.wer or "?") .. (plan.wer == ich and " (du)" or "") .. "\n" .. table.concat(teile, ", ")
    -- Spalten
    local tiefe = 0
    local function messen(z, t)
        tiefe = math.max(tiefe, t)
        for _, k in ipairs(z.kinder or {}) do
            messen(k, t + 1)
        end
    end
    messen(wurzel, 0)
    local breite = (n.inhalt:GetWidth() or 840)
    if breite <= 0 then
        breite = 840
    end
    local spalte = math.min(300, math.floor((breite - 4) / (tiefe + 1)))
    local kachelB = spalte - 34
    -- Kachel fuellen und Hoehe messen
    local function kachel(z, t)
        local k = Frei(n.kacheln, n.inhalt, P.KachelBauen)
        local farbe = z.tasche and "tasche" or z.status
        local rgb = K.STATUS_RGB[farbe] or K.GEDAEMPFT
        Flaeche(k, z.wurzel and { 0.16, 0.14, 0.08, 1 } or { 0.12, 0.13, 0.15, 1 }, { rgb[1], rgb[2], rgb[3], 0.9 })
        k.streifen:SetVertexColor(rgb[1], rgb[2], rgb[3], 1)
        k:SetWidth(kachelB)
        local gr = z.wurzel and 34 or 28
        k.icon:SetSize(gr, gr)
        k.icon:SetTexture((z.wurzel and (ItemIcon(r.itemID) or r.icon)) or ItemIcon(z.itemID) or K.ICON_UNBEKANNT)
        k.itemID = z.itemID
        if z.wurzel then
            local q = ItemQualitaet(r.itemID)
            k.name:SetText(Farbe(K.QUALITAET_HEX[q or 1] or "ffffff", r.name or "?"))
            k.zahl:SetText(Farbe(K.STATUS_HEX.gelb, menge .. "×"))
            k.info:SetText(z.text)
        else
            k.name:SetText(ItemName(z.itemID) or Farbe("9a9384", "Name wird geladen …"))
            k.zahl:SetText(Farbe(K.STATUS_HEX[farbe], z.da) .. Farbe("77715f", " / " .. z.bedarf))
            k.info:SetText(P.InfoText(z, fraktion))
        end
        k.name:SetWidth(kachelB - (12 + gr + 8) - 60)
        k.info:SetWidth(kachelB - (12 + gr + 8) - 9)
        k.name:ClearAllPoints()
        k.name:SetPoint("TOPLEFT", 12 + gr + 8, -8)
        k.name:SetPoint("RIGHT", k.zahl, "LEFT", -6, 0)
        k.info:ClearAllPoints()
        k.info:SetPoint("TOPLEFT", k.name, "BOTTOMLEFT", 0, -2)
        k.info:SetPoint("RIGHT", k, "RIGHT", -9, 0)
        local h = 8 + (k.name:GetStringHeight() or 14) + 2 + ((k.info:GetText() or "") ~= "" and (k.info:GetStringHeight() or 12) or 0) + 9
        k:SetHeight(math.max(gr + 16, h))
        k.h = math.max(gr + 16, h)
        k:Show()
        return k
    end
    -- Anordnen: Kinder untereinander, Eltern auf Hoehe des ersten Kindes (Wurzel mittig)
    local function setzen(z, t, oben)
        local k = kachel(z, t)
        z.kachel, z.x = k, 4 + t * spalte
        local unten
        if z.kinder and #z.kinder > 0 then
            local y = oben
            for _, kind in ipairs(z.kinder) do
                y = setzen(kind, t + 1, y) + K.NETZ_LUECKE
            end
            unten = y - K.NETZ_LUECKE
            if z.wurzel then
                local erst, letzt = z.kinder[1], z.kinder[#z.kinder]
                z.y = math.max(oben, math.floor((erst.y + letzt.y + letzt.kachel.h) / 2 - k.h / 2))
            else
                z.y = oben
            end
            unten = math.max(unten, z.y + k.h)
        else
            z.y = oben
            unten = oben + k.h
        end
        k:ClearAllPoints()
        k:SetPoint("TOPLEFT", n.inhalt, "TOPLEFT", z.x, -z.y)
        return unten
    end
    local unten = setzen(wurzel, 0, 4)
    -- Linien: rechtwinklig, Eltern -> Mitte der Luecke -> Kind
    local function linien(z)
        if not z.kinder or #z.kinder == 0 then
            return
        end
        local px = z.x + kachelB
        local py = z.y + (z.wurzel and math.floor(z.kachel.h / 2) or 22)
        local mx = px + math.floor((spalte - kachelB) / 2)
        P.Strich(n, px, py - 1, mx - px, 2)
        local oben, tief = py, py
        for _, kind in ipairs(z.kinder) do
            local ky = kind.y + 22
            oben, tief = math.min(oben, ky), math.max(tief, ky)
            P.Strich(n, mx, ky - 1, kind.x - mx, 2)
            linien(kind)
        end
        P.Strich(n, mx - 1, oben - 1, 2, tief - oben + 2)
    end
    linien(wurzel)
    n.inhalt:SetHeight(math.max(10, unten + 8))
end

-- ---------------------------------------------------------------------------
-- Auktionshaus-Preise (Version 0.8) - NUR LESEN
-- Beim Oeffnen des Auktionshauses sucht Guild ERP einzeln nach den Zutaten der Rezepte,
-- die deine Charaktere kennen (eine Suche je Sekunde; das Spiel erlaubt 100 je Minute).
-- Gemerkt werden je Zutat der guenstigste Preis und der Durchschnitt der Angebote
-- (Angebote ueber dem Dreifachen des guenstigsten zaehlen nicht mit).
-- Es wird nichts gekauft, geboten oder eingestellt. Sucht der Spieler selbst, macht
-- Guild ERP Pause. Preise werden NICHT an andere gesendet.
-- ---------------------------------------------------------------------------
K.AH_TAKT = 1.0          -- Sekunden zwischen zwei Suchen
K.AH_WARTEN = 4          -- Sekunden, die auf eine Antwort gewartet wird
K.AH_FRISCH = 30 * 60    -- Preise juenger als 30 Minuten werden nicht neu gesucht
K.AH_PAUSE = 10          -- Pause, wenn der Spieler selbst sucht
K.AH_AUSREISSER = 3      -- Angebote ueber dem Dreifachen des guenstigsten zaehlen nicht

function A.Neu()
    O.Nach(0.3, function()
        FensterAktualisieren()
    end)
end

function A.Preise(fraktion)
    local d = Daten()
    d.prices = d.prices or {}
    fraktion = fraktion or SpielerFraktion() or "?"
    d.prices[fraktion] = d.prices[fraktion] or {}
    return d.prices[fraktion]
end

function A.Preis(itemID)
    return itemID and A.Preise()[itemID] or nil
end

-- Muenzen wie im Zielbild: "1 S 10 K" in den Farben des Spiels
function A.Muenzen(kupfer, tinte)
    kupfer = math.floor((kupfer or 0) + 0.5)
    local g, s, c = math.floor(kupfer / 10000), math.floor(kupfer / 100) % 100, kupfer % 100
    local teile = {}
    if g > 0 then
        table.insert(teile, g .. Farbe(tinte and "8a6a10" or "e6c46a", " G"))
    end
    if s > 0 then
        table.insert(teile, s .. Farbe(tinte and "5a5a62" or "c7c7cf", " S"))
    end
    if c > 0 or #teile == 0 then
        table.insert(teile, c .. Farbe(tinte and "8a5a2a" or "c08a5a", " K"))
    end
    return table.concat(teile, " ")
end

-- Zeitpunkt der neuesten Preise (oder nil)
function A.Stand()
    local neu
    for _, p in pairs(A.Preise()) do
        if not neu or (p.at or 0) > neu then
            neu = p.at
        end
    end
    return neu
end

-- "AH: ab 45 K · Schnitt 52 K" (ohne Datum) oder nil, wenn noch nie gesucht
function A.Text(itemID, mitZeit, tinte)
    local p = A.Preis(itemID)
    if not p then
        return nil
    end
    local t
    if tinte then
        -- auf Pergament: Text in Tintenfarbe, nur die Muenzen farbig
        return p.leer and "AH: nicht im Angebot" or ("AH: ab " .. A.Muenzen(p.min, true) .. " · Schnitt " .. A.Muenzen(p.avg, true))
    end
    if p.leer then
        t = Farbe("8a8578", "AH: nicht im Angebot")
    else
        t = Farbe("8a7a52", "AH:") .. Farbe("c9b88a", " ab ") .. A.Muenzen(p.min) .. Farbe("c9b88a", " · Schnitt ") .. A.Muenzen(p.avg)
    end
    if mitZeit then
        t = t .. Farbe("8a8578", " · " .. P.Zeit(p.at) .. (p.von and (", von " .. B.Anzeige(p.von)) or ""))
    end
    return t
end

-- Kosten fuer eine Liste {{itemID, n}}: Summe nach guenstigstem Preis + Namen ohne Preis
function A.Kosten(liste)
    local summe, ohne, bekannt = 0, {}, false
    for _, e in ipairs(liste) do
        local p = A.Preis(e.itemID)
        if p and not p.leer then
            summe = summe + p.min * e.n
            bekannt = true
        else
            table.insert(ohne, ItemName(e.itemID) or "?")
        end
    end
    return bekannt and summe or nil, ohne
end

-- was in einer Stueckliste noch fehlt (Blaetter mit Rest, ohne Zugesagtes)
function A.Fehlendes(stueckliste)
    local liste = {}
    local function sammeln(z)
        if z.kinder then
            for _, k in ipairs(z.kinder) do
                sammeln(k)
            end
        elseif (z.rest or 0) > 0 then
            table.insert(liste, { itemID = z.itemID, n = z.rest })
        end
    end
    for _, z in ipairs(stueckliste or {}) do
        sammeln(z)
    end
    return liste
end

-- "etwa 1 S 25 K (ohne Schwacher Fluxus)" oder nil
function A.KostenText(liste, tinte)
    if #liste == 0 then
        return nil
    end
    local summe, ohne = A.Kosten(liste)
    if not summe then
        return nil
    end
    return "etwa " .. A.Muenzen(summe, tinte) .. (#ohne > 0 and (" (ohne " .. table.concat(ohne, ", ") .. ")") or "")
end

-- ----- Suchen -----
A.schlange = {}
A.gesamt = 0
A.fertig = 0
A.letzte = {}

function A.Moeglich()
    return C_AuctionHouse and C_AuctionHouse.SendSearchQuery and C_AuctionHouse.MakeItemKey and true or false
end

function A.Zutaten()
    local fraktion = SpielerFraktion()
    local _, rezepte = HerstellerSammeln(fraktion)
    local ids, liste = {}, {}
    for rid in pairs(rezepte or {}) do
        local r = GuildERPData.recipes[rid]
        for _, z in ipairs(r and r.reagents or {}) do
            if not ids[z.itemID] then
                ids[z.itemID] = true
                table.insert(liste, z.itemID)
            end
        end
    end
    table.sort(liste, function(x, y) return (ItemName(x) or "") < (ItemName(y) or "") end)
    return liste
end

function A.Start()
    if not A.Moeglich() then
        return
    end
    local preise = A.Preise()
    local jetzt = time()
    A.schlange, A.letzte = {}, {}
    local alle = A.Zutaten()
    for _, id in ipairs(alle) do
        local p = preise[id]
        if not p or jetzt - (p.at or 0) >= K.AH_FRISCH then
            table.insert(A.schlange, id)
        end
    end
    A.gesamt, A.fertig, A.alle = #A.schlange, 0, #alle
    A.laeuft = #A.schlange > 0
    A.gestoppt, A.blockiert, A.warteAuf = false, false, nil
    A.FensterZeigen()
    if A.laeuft then
        O.Nach(1.5, A.Takt)
    end
end

function A.Takt()
    if not A.laeuft or A.gestoppt or A.blockiert then
        return
    end
    local jetzt = GetTime and GetTime() or 0
    if A.pauseBis and jetzt < A.pauseBis then
        A.FensterZeigen()
        O.Nach(1, A.Takt)
        return
    end
    -- auf Antwort warten (hoechstens K.AH_WARTEN Sekunden)
    if A.warteAuf and jetzt - (A.gesendet or 0) < K.AH_WARTEN then
        O.Nach(0.25, A.Takt)
        return
    end
    if A.warteAuf then
        -- keine Antwort: diese Zutat ueberspringen (alter Preis bleibt)
        A.Fertig(A.warteAuf, nil)
    end
    local id = table.remove(A.schlange, 1)
    if not id then
        A.laeuft = false
        A.FensterZeigen()
        A.Neu()
        return
    end
    A.warteAuf, A.gesendet = id, jetzt
    A.eigeneSuche = true
    local ok = pcall(C_AuctionHouse.SendSearchQuery, C_AuctionHouse.MakeItemKey(id),
        { { sortOrder = Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0, reverseSort = false } }, false)
    A.eigeneSuche = false
    if not ok then
        A.warteAuf = nil
        A.Fertig(id, nil)
    end
    A.FensterZeigen()
    O.Nach(K.AH_TAKT, A.Takt)
end

-- Ergebnis auswerten. angebote = {{preis je Stueck, menge}} oder nil (keine Antwort)
function A.Fertig(itemID, angebote)
    if A.warteAuf == itemID then
        A.warteAuf = nil
    end
    A.fertig = A.fertig + 1
    local eintrag = { itemID = itemID }
    if angebote then
        local min
        for _, a in ipairs(angebote) do
            if a[1] > 0 and (not min or a[1] < min) then
                min = a[1]
            end
        end
        if min then
            local summe, menge = 0, 0
            for _, a in ipairs(angebote) do
                if a[1] > 0 and a[1] <= min * K.AH_AUSREISSER then
                    summe = summe + a[1] * a[2]
                    menge = menge + a[2]
                end
            end
            A.Preise()[itemID] = { min = min, avg = math.floor(summe / math.max(1, menge) + 0.5), n = menge, at = time() }
        else
            A.Preise()[itemID] = { leer = true, at = time() }
        end
        eintrag.p = A.Preise()[itemID]
        Kat.VielleichtTeilen()
    end
    table.insert(A.letzte, 1, eintrag)
    while #A.letzte > 6 do
        table.remove(A.letzte)
    end
end

function A.Lesen(itemID, warCommodity)
    local angebote = {}
    if warCommodity then
        local n = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
        for i = 1, n do
            local r = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
            if r and r.unitPrice then
                table.insert(angebote, { r.unitPrice, r.quantity or 1 })
            end
        end
    else
        local key = C_AuctionHouse.MakeItemKey(itemID)
        local n = C_AuctionHouse.GetNumItemSearchResults(key) or 0
        for i = 1, n do
            local r = C_AuctionHouse.GetItemSearchResultInfo(key, i)
            if r and r.buyoutAmount then
                table.insert(angebote, { r.buyoutAmount, r.quantity or 1 })
            end
        end
    end
    return angebote
end

-- Ereignisse rund ums Auktionshaus. Rueckgabe true = erledigt
function A.Ereignis(event, ...)
    if event == "AUCTION_HOUSE_SHOW" then
        if not A.gehookt and hooksecurefunc and C_AuctionHouse then
            A.gehookt = true
            -- sucht der Spieler selbst, macht Guild ERP eine Pause (nur beobachten, nichts aendern)
            local function selbst()
                O.Sicher("AH-Beobachtung", function()
                    if not A.eigeneSuche then
                        A.pauseBis = (GetTime and GetTime() or 0) + K.AH_PAUSE
                    end
                end)
            end
            for _, f in ipairs({ "SendBrowseQuery", "SendSearchQuery", "SendSellSearchQuery" }) do
                if C_AuctionHouse[f] then
                    pcall(hooksecurefunc, C_AuctionHouse, f, selbst)
                end
            end
        end
        local modus = O.Wert("ah")
        if modus == "auto" then
            O.Nach(0.5, A.Start)
        elseif modus == "knopf" then
            A.aufKnopf = true
            A.gesamt, A.fertig, A.laeuft, A.letzte = 0, 0, false, {}
            O.Nach(0.5, A.FensterZeigen)
        end
        return true
    elseif event == "AUCTION_HOUSE_CLOSED" then
        A.laeuft = false
        A.schlange = {}
        A.warteAuf = nil
        if A.fenster then
            A.fenster:Hide()
        end
        A.Neu()
        return true
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" or event == "ITEM_SEARCH_RESULTS_UPDATED" then
        local arg = ...
        local itemID = type(arg) == "table" and arg.itemID or arg
        if itemID and itemID == A.warteAuf then
            local ok, angebote = pcall(A.Lesen, itemID, event == "COMMODITY_SEARCH_RESULTS_UPDATED")
            A.Fertig(itemID, ok and angebote or nil)
            A.FensterZeigen()
        end
        return true
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        local addon = ...
        if addon == "GuildERP" and A.laeuft then
            A.blockiert = true
            A.laeuft = false
            A.FensterZeigen()
        end
        return true
    end
    return false
end

-- ----- Fenster neben dem Auktionshaus -----
function A.FensterBauen()
    local w = O.Rahmen("Frame", "GuildERPPreise", UIParent, K.BACKDROP_VORLAGE)
    w:SetSize(300, 330)
    w:SetFrameStrata("HIGH")
    w:SetClampedToScreen(true)
    w:EnableMouse(true)
    if w.SetBackdrop then
        w:SetBackdrop(K.BACKDROP_RAHMEN)
    end
    w.titel = Schrift(w, "GameFontNormalLarge")
    w.titel:SetPoint("TOPLEFT", 16, -16)
    w.titel:SetText("Guild ERP · Preise")
    w.text = Schrift(w, "GameFontHighlightSmall")
    w.text:SetPoint("TOPLEFT", w.titel, "BOTTOMLEFT", 0, -8)
    w.text:SetPoint("RIGHT", -16, 0)
    w.text:SetTextColor(0.72, 0.67, 0.55)
    w.stand = Schrift(w, "GameFontHighlight")
    w.stand:SetPoint("TOPLEFT", w.text, "BOTTOMLEFT", 0, -10)
    w.rest = Schrift(w, "GameFontDisableSmall", false)
    w.rest:SetPoint("RIGHT", -16, 0)
    w.rest:SetPoint("TOP", w.stand, "TOP", 0, 0)
    w.balkenHg = w:CreateTexture(nil, "ARTWORK")
    w.balkenHg:SetHeight(8)
    w.balkenHg:SetPoint("TOPLEFT", w.stand, "BOTTOMLEFT", 0, -6)
    w.balkenHg:SetPoint("RIGHT", -16, 0)
    w.balkenHg:SetColorTexture(0.16, 0.17, 0.19, 1)
    w.balken = w:CreateTexture(nil, "OVERLAY")
    w.balken:SetHeight(8)
    w.balken:SetPoint("TOPLEFT", w.balkenHg, "TOPLEFT", 0, 0)
    w.balken:SetColorTexture(K.GOLD[1], K.GOLD[2], K.GOLD[3], 1)
    w.zeilen = {}
    for i = 1, 6 do
        local z = {}
        z.name = Schrift(w, "GameFontHighlightSmall", false)
        z.preis = Schrift(w, "GameFontHighlightSmall", false)
        z.name:SetPoint("TOPLEFT", w.balkenHg, "BOTTOMLEFT", 0, -10 - (i - 1) * 21)
        z.preis:SetPoint("RIGHT", -16, 0)
        z.preis:SetPoint("TOP", z.name, "TOP", 0, 0)
        w.zeilen[i] = z
    end
    w.hinweis = Schrift(w, "GameFontDisableSmall")
    w.hinweis:SetPoint("BOTTOMLEFT", 16, 18)
    w.hinweis:SetPoint("RIGHT", -110, 0)
    w.knopf = O.Rahmen("Button", nil, w, "UIPanelButtonTemplate")
    w.knopf:SetSize(86, 24)
    w.knopf:SetPoint("BOTTOMRIGHT", -14, 14)
    w:Hide()
    A.fenster = w
    return w
end

function A.FensterZeigen()
    local w = A.fenster or A.FensterBauen()
    if AuctionHouseFrame and AuctionHouseFrame.IsShown and AuctionHouseFrame:IsShown() then
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 6, 0)
    elseif not w:GetPoint() then
        w:SetPoint("RIGHT", UIParent, "RIGHT", -40, 60)
    end
    local jetzt = GetTime and GetTime() or 0
    if A.aufKnopf and not A.laeuft then
        w.text:SetText("Preise holst du hier per Knopf. Guild ERP sucht dann nacheinander nach den Zutaten deiner Rezepte.")
    elseif A.blockiert then
        w.text:SetText("Das Spiel hat die Preissuche gestoppt. Guild ERP sucht in dieser Sitzung nicht weiter.")
    elseif A.laeuft then
        w.text:SetText("Ich schaue nach, was die Zutaten deiner Rezepte kosten. Gekauft wird nichts.")
    elseif A.gesamt == 0 then
        w.text:SetText("Die Preise sind noch aktuell. Neu gesucht wird frühestens 30 Minuten nach der letzten Suche.")
    else
        w.text:SetText("Fertig. Die Preise siehst du in der Werkstatt, in den Planaufträgen und bei den Bestellungen.")
    end
    if A.laeuft and A.pauseBis and jetzt < A.pauseBis then
        w.stand:SetText("Pause")
        w.rest:SetText("du suchst gerade selbst")
    elseif A.laeuft then
        w.stand:SetText(A.fertig .. " von " .. A.gesamt .. " Zutaten")
        local sek = math.ceil((A.gesamt - A.fertig) * K.AH_TAKT)
        w.rest:SetText("noch etwa " .. sek .. " Sek.")
    else
        local n = 0
        for _ in pairs(A.Preise()) do
            n = n + 1
        end
        w.stand:SetText(Farbe(K.STATUS_HEX.tasche, (A.alle or n) .. " Preise aktuell"))
        w.rest:SetText("")
    end
    local anteil = A.gesamt > 0 and (A.fertig / A.gesamt) or 1
    local breite = (w.balkenHg:GetWidth() or 268)
    if breite <= 0 then
        breite = 268
    end
    w.balken:SetWidth(math.max(1, breite * math.min(1, anteil)))
    -- Liste: zuerst die gerade gesuchte Zutat, dann die letzten Ergebnisse
    local zeilen = {}
    if A.laeuft and A.warteAuf then
        table.insert(zeilen, { Farbe("f3d98a", "… " .. (ItemName(A.warteAuf) or "?")), Farbe("c9b88a", "sucht gerade …") })
    end
    for _, e in ipairs(A.letzte) do
        local preis
        if not e.p then
            preis = Farbe("8a8578", "keine Antwort")
        elseif e.p.leer then
            preis = Farbe("8a8578", "nicht im Angebot")
        else
            preis = Farbe("c9b88a", "ab ") .. A.Muenzen(e.p.min)
        end
        table.insert(zeilen, { "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t " .. (ItemName(e.itemID) or "?"), preis })
    end
    for i, z in ipairs(w.zeilen) do
        local e = zeilen[i]
        z.name:SetText(e and e[1] or "")
        z.preis:SetText(e and e[2] or "")
    end
    if A.laeuft then
        w.hinweis:SetText("Suchst du selbst etwas, mache ich Pause.")
        w.knopf:SetText("Stopp")
        w.knopf:SetScript("OnClick", function()
            A.gestoppt, A.laeuft = true, false
            A.FensterZeigen()
            A.Neu()
        end)
    elseif A.aufKnopf and A.gesamt == 0 then
        w.hinweis:SetText("")
        w.knopf:SetText("Preise holen")
        w.knopf:SetScript("OnClick", function()
            A.aufKnopf = false
            A.Start()
        end)
    else
        w.hinweis:SetText(A.gestoppt and "Gestoppt. Beim nächsten Besuch geht es weiter." or "")
        w.knopf:SetText("Schließen")
        w.knopf:SetScript("OnClick", function() w:Hide() end)
    end
    w.knopf:SetWidth(math.max(86, (w.knopf:GetFontString() and w.knopf:GetFontString():GetStringWidth() or 60) + 26))
    w:Show()
end

-- ---------------------------------------------------------------------------
-- Katalog (Version 0.9): wer kann was?
-- Jeder teilt mit seiner Gruppe, welche Rezepte seine Charaktere kennen
-- (nur Rezept-Nummer und Ergebnis-Gegenstand, je Charakter und Beruf).
-- Zuerst wird nur ein kurzer Stand ("S~Pruefzahl") gesendet. Nur wenn der andere einen
-- anderen Stand hat, fragt er nach ("Q~Name") und bekommt die Liste ("K~...").
-- In 0.9 nur zum Anschauen; Bestellen aus dem Katalog folgt mit 1.0.
-- ---------------------------------------------------------------------------
function Kat.Daten()
    local d = Daten()
    d.fremd = d.fremd or {}           -- [Charaktername] = { von, at, berufe = { [Beruf] = { [rezeptID] = itemID oder 0 } } }
    d.fremdStand = d.fremdStand or {} -- [Absender] = Pruefzahl der zuletzt erhaltenen Liste
    d.katNamen = d.katNamen or {}     -- [rezeptID] = Name (gemerkt)
    d.katGruppe = d.katGruppe or {}   -- [rezeptID] = Gruppe des Spiels, vom Abgleich (ab 1.1.4)
    return d
end

-- eigene Liste als Text: Name=Beruf=rid.item,rid.item ^ ...
function Kat.Text()
    local d = Daten()
    local bloecke = {}
    local namen = {}
    local fraktion = SpielerFraktion()
    for schluessel, c in pairs(d.characters) do
        -- ab 1.2.1: nur Charaktere der eigenen Fraktion (Allianz sieht nur Allianz, Horde nur Horde)
        if c.name and c.recipes and (not c.faction or c.faction == fraktion) then
            table.insert(namen, schluessel)
        end
    end
    table.sort(namen)
    for _, schluessel in ipairs(namen) do
        local c = d.characters[schluessel]
        local berufe = {}
        for beruf, ids in pairs(c.recipes) do
            if type(ids) == "table" then
                table.insert(berufe, tostring(beruf))
            end
        end
        table.sort(berufe)
        for _, beruf in ipairs(berufe) do
            local ids = {}
            for rid in pairs(c.recipes[beruf]) do
                if tonumber(rid) then
                    table.insert(ids, tonumber(rid))
                end
            end
            table.sort(ids)
            local teile = {}
            -- ab 1.1.4: Gruppe des Spiels als Nummer in eine Namensliste am Ende ("rid.item.nr")
            local kats, katNr = {}, {}
            for _, rid in ipairs(ids) do
                local r = d.recipes[rid]
                local t = rid .. "." .. (r and r.itemID or 0)
                local k = r and r.kategorie
                if k and k ~= "" then
                    if not katNr[k] then
                        table.insert(kats, B.M(k))
                        katNr[k] = #kats
                    end
                    t = t .. "." .. katNr[k]
                end
                table.insert(teile, t)
            end
            if #teile > 0 then
                table.insert(bloecke, B.M(c.voll or c.name) .. "=" .. B.M(beruf) .. "=" .. table.concat(teile, ",")
                    .. (#kats > 0 and ("=" .. table.concat(kats, ";")) or ""))
            end
        end
    end
    return table.concat(bloecke, "^")
end

function Kat.Pruefzahl(text)
    local h = 5381
    for i = 1, #text do
        h = (h * 33 + string.byte(text, i)) % 2147483647
    end
    return tostring(h)
end

-- Pruefzahl der eigenen Liste
function Kat.Eigener()
    return Kat.Pruefzahl(Kat.Text())
end

function Kat.Senden()
    if not B.InGruppe() then
        return
    end
    local ok, text = pcall(Kat.Text)
    if not ok then
        B.Diagnose("fehler", "KatalogText", text)
        return
    end
    local zahl = Kat.Pruefzahl(text)
    -- fragen mehrere gleichzeitig, wird nur einmal gesendet
    if Kat.gesendet == zahl and time() - (Kat.gesendetAt or 0) < 20 then
        return
    end
    Kat.gesendet, Kat.gesendetAt = zahl, time()
    B.Paket("K", text)
end

function Kat.StandEmpfangen(zahl, absender)
    local d = Kat.Daten()
    zahl = string.match(zahl or "", "^(%d+)$")
    if zahl and d.fremdStand[absender] ~= zahl then
        B.Einreihen("Q~" .. B.M(absender))
    end
end

-- Knopf "Jetzt abgleichen": alles neu anfragen und den eigenen Stand senden
function Kat.JetztAbgleichen()
    if not B.InGruppe() then
        Melden(O.GildeModus() and "Guild-Found ist an: Abgleichen geht nur innerhalb deiner Gilde."
            or "Abgleichen geht nur, wenn ihr zusammen in einer Gruppe seid.")
        return
    end
    local d = Kat.Daten()
    d.fremdStand = {}
    d.teilenStand = {}
    Kat.gesendet = nil
    Kat.teilenGesendet = nil
    B.Einreihen("H~2")
    B.StandSenden(true)
    Melden("Abgleich gestartet. Das dauert etwa 20 Sekunden.")
end

-- "/gerp abgleich": was wurde gesendet und empfangen?
function Kat.DiagnoseZeigen()
    local g = (Daten().diagnostics or {}).abgleich or {}
    local function liste(t)
        local teile = {}
        for k, v in pairs(t or {}) do
            table.insert(teile, k .. "=" .. v)
        end
        table.sort(teile)
        return #teile > 0 and table.concat(teile, " ") or "-"
    end
    Melden("Abgleich-Prüfung (Version " .. K.VERSION .. "):")
    print("  In Gruppe: " .. (B.InGruppe() and "ja" or "nein") .. ", Mitglieder: " .. table.concat(B.Mitglieder(), ", "))
    print("  Gesendet: " .. liste(g.gesendet) .. "  |  Empfangen: " .. liste(g.empfangen))
    print("  Gedrosselt: " .. liste(g.gedrosselt) .. "  |  Fehler: " .. liste(g.fehler))
    print("  Warteschlange: " .. #B.schlange .. " Nachrichten")
    local n = 0
    for _ in pairs(Kat.Daten().fremd) do
        n = n + 1
    end
    print("  Rezeptlisten von anderen: " .. n .. " Charaktere")
    if g.letzte then
        print("  Zuletzt: " .. g.letzte)
    end
end

-- ---------------------------------------------------------------------------
-- Teilen (ab 1.4): Fundorte von Rezepten und Auktionshaus-Preise, nur zwischen Spielern mit
-- Guild ERP und nur innerhalb der eigenen Fraktion. Jeder sendet nur, was er SELBST gesehen hat
-- (nichts wird weitergereicht). Zuerst geht eine Pruefzahl raus ("T~zahl"), wer sie noch nicht
-- kennt, fragt nach ("R~Name"), dann kommen die Pakete "Z" (Fundorte) und "W" (Preise).
-- Aeltere Versionen ignorieren diese Nachrichten. Bei Preisen gewinnt der neuere Zeitstempel.
-- ---------------------------------------------------------------------------
K.TEILEN_QUELLEN_MAX = 6000 -- Zeichen je Paket (30 Teile, gut eine halbe Minute)
K.TEILEN_PREISE_MAX = 3000  -- Zeichen je Paket (etwa 90 Preise)
K.TEILEN_PREISE_ALTER = 3 * 86400
K.TEILEN_QUELLEN_JE_REZEPT = 20
K.QUELLEN_ARTEN = { Lehrer = true, ["Händler"] = true, Beute = true }

-- Text aus den neuesten Eintraegen bauen, bis die Hoechstmenge erreicht ist
function Kat.TeilenBauen(eintraege, max)
    table.sort(eintraege, function(a, b)
        if a.at ~= b.at then
            return a.at > b.at
        end
        return a.text < b.text
    end)
    local teile, laenge = {}, 0
    for _, e in ipairs(eintraege) do
        if laenge + #e.text > max then
            break
        end
        table.insert(teile, e.text)
        laenge = laenge + #e.text + 1
    end
    return teile
end

function Kat.QuellenText()
    local fraktion = SpielerFraktion()
    local eintraege = {}
    for name, quellen in pairs(Daten().quellen) do
        for _, q in ipairs(quellen) do
            local f = q.fraktion
            if not q.von and (not f or f == "Neutral" or f == fraktion) then
                local felder = { B.M(name), B.M(q.art), B.M(q.wer), B.M(q.zone), q.x or "", q.y or "", q.kosten or "",
                    q.skill or "", B.M(q.beruf), B.M(f), q.at or 0 }
                table.insert(eintraege, { at = q.at or 0, text = table.concat(felder, "=") })
            end
        end
    end
    return table.concat(Kat.TeilenBauen(eintraege, K.TEILEN_QUELLEN_MAX), "^")
end

function Kat.PreiseText()
    local grenze = time() - K.TEILEN_PREISE_ALTER
    local eintraege = {}
    for id, p in pairs(A.Preise()) do
        if not p.von and (p.at or 0) > grenze then
            local felder = { id, p.leer and 0 or (p.min or 0), p.leer and 0 or (p.avg or 0), p.n or 0, p.at }
            table.insert(eintraege, { at = p.at, text = table.concat(felder, "=") })
        end
    end
    local teile = Kat.TeilenBauen(eintraege, K.TEILEN_PREISE_MAX)
    if #teile == 0 then
        return ""
    end
    return B.M(SpielerFraktion()) .. "^" .. table.concat(teile, ",")
end

-- Pruefzahl des eigenen Standes, nil wenn es nichts zu teilen gibt
function Kat.TeilenZahl()
    if not O.Wert("teilen") then
        return nil
    end
    local text = Kat.QuellenText() .. "#" .. Kat.PreiseText()
    return text ~= "#" and Kat.Pruefzahl(text) or nil
end

function Kat.TeilenStandSenden()
    local zahl = Kat.TeilenZahl()
    if zahl then
        Kat.teilenGemeldet = zahl
        B.Einreihen("T~" .. zahl)
    end
end

-- Neues gesehen: spaetestens nach einer Minute Bescheid sagen, nie oefter
function Kat.VielleichtTeilen()
    if Kat.teilenWartet or not O.Wert("teilen") then
        return
    end
    Kat.teilenWartet = true
    O.Nach(60, function()
        Kat.teilenWartet = false
        if B.InGruppe() and Kat.TeilenZahl() ~= Kat.teilenGemeldet then
            B.Sicher("Teilen", Kat.TeilenStandSenden)
        end
    end)
end

function Kat.TeilenStandEmpfangen(zahl, absender)
    zahl = string.match(zahl or "", "^(%d+)$")
    if not zahl or not O.Wert("teilen") then
        return
    end
    local d = Kat.Daten()
    d.teilenStand = d.teilenStand or {}
    if d.teilenStand[absender] ~= zahl then
        d.teilenStand[absender] = zahl
        B.Einreihen("R~" .. B.M(absender))
    end
end

function Kat.TeilenSenden()
    local zahl = Kat.TeilenZahl()
    -- fragen mehrere gleichzeitig, wird nur einmal gesendet
    if not zahl or (Kat.teilenGesendet == zahl and time() - (Kat.teilenGesendetAt or 0) < 20) then
        return
    end
    Kat.teilenGesendet, Kat.teilenGesendetAt = zahl, time()
    local quellen, preise = Kat.QuellenText(), Kat.PreiseText()
    if quellen ~= "" then
        B.Paket("Z", quellen)
    end
    if preise ~= "" then
        B.Paket("W", preise)
    end
end

-- Zeitstempel anderer: nie in der Zukunft, sonst bliebe ein Preis fuer immer "der neueste"
function Kat.TeilenZeit(text)
    local at = tonumber(text)
    return at and at > 0 and math.floor(math.min(at, time())) or nil
end

function Kat.QuellenEmpfangen(text, absender)
    if not O.Wert("teilen") then
        return
    end
    local d = Daten()
    local fraktion = SpielerFraktion()
    local neu = 0
    for block in string.gmatch(text or "", "[^%^]+") do
        local w = {}
        for feld in string.gmatch(block .. "=", "([^=]*)=") do
            table.insert(w, feld)
        end
        local name, art, wer = B.Kurz(B.D(w[1]), 80), B.D(w[2]), B.Kurz(B.D(w[3]), 60)
        local beruf, f, at = B.Kurz(B.D(w[9]), 40), B.D(w[10]), Kat.TeilenZeit(w[11])
        local sichtbar = f == "" or f == "Neutral" or f == fraktion
        if name ~= "" and not Kat.IstStufe(name) and K.QUELLEN_ARTEN[art] and wer ~= "" and beruf ~= "" and at and sichtbar then
            local q = { art = art, wer = wer, zone = B.Kurz(B.D(w[4]), 60), x = tonumber(w[5]), y = tonumber(w[6]),
                kosten = tonumber(w[7]), skill = tonumber(w[8]), beruf = beruf, fraktion = f ~= "" and f or nil,
                at = at, von = absender }
            local liste = d.quellen[name] or {}
            local alt
            for i, e in ipairs(liste) do
                if e.art == q.art and e.wer == q.wer and e.zone == q.zone and e.beruf == q.beruf then
                    alt = i
                end
            end
            if alt then
                -- selbst Gesehenes bleibt, Fremdes wird durch Neueres ersetzt
                if liste[alt].von and (liste[alt].at or 0) < at then
                    liste[alt] = q
                end
            elseif #liste < K.TEILEN_QUELLEN_JE_REZEPT then
                table.insert(liste, q)
                d.quellen[name] = liste
                neu = neu + 1
            end
        end
    end
    if neu > 0 then
        O.Chat(B.Anzeige(absender) .. " hat " .. neu .. (neu == 1 and " Fundort" or " Fundorte") .. " von Rezepten geteilt.")
        if FensterAktualisieren then
            FensterAktualisieren()
        end
    end
end

function Kat.PreiseEmpfangen(text, absender)
    if not O.Wert("teilen") then
        return
    end
    local kopf, inhalt = string.match(text or "", "^([^%^]*)%^(.*)$")
    -- Allianz sieht nur Allianz-Preise, Horde nur Horde-Preise
    if not kopf or B.D(kopf) ~= SpielerFraktion() then
        return
    end
    local preise = A.Preise()
    local neu = false
    for id, min, avg, n, zeit in string.gmatch(inhalt, "(%d+)=(%d+)=(%d+)=(%d+)=(%d+)") do
        id = tonumber(id)
        local at = Kat.TeilenZeit(zeit)
        local alt = preise[id]
        if id and id > 0 and at and (not alt or (alt.at or 0) < at) then
            min, avg, n = B.Zahl(min, 1e10), B.Zahl(avg, 1e10), B.Zahl(n, 1e7)
            if min > 0 then
                preise[id] = { min = min, avg = avg, n = n, at = at, von = absender }
            else
                preise[id] = { leer = true, at = at, von = absender }
            end
            neu = true
        end
    end
    if neu and FensterAktualisieren then
        FensterAktualisieren()
    end
end

-- eigene Liste geaendert (neues Rezept gelernt)? Dann kurz Bescheid sagen
function Kat.VielleichtMelden()
    if not B.InGruppe() then
        return
    end
    local zahl = Kat.Eigener()
    if zahl ~= Kat.gemeldet then
        Kat.gemeldet = zahl
        B.Einreihen("S~" .. zahl)
    end
end

function Kat.Empfangen(text, absender)
    local d = Kat.Daten()
    local eigene = B.EigeneNamen()
    for name, e in pairs(d.fremd) do
        -- auch alte Eintraege unter dem Vornamen (vor 1.0) entfernen
        if B.Gleich(e.von or "", absender) then
            d.fremd[name] = nil
        end
    end
    local anzahl = 0
    for block in string.gmatch(text or "", "[^%^]+") do
        local name, beruf, ids, katText = string.match(block, "^([^=]+)=([^=]+)=([^=]*)=?(.*)$")
        if name then
            local kats = {}
            for k in string.gmatch(katText or "", "[^;]+") do
                table.insert(kats, B.Kurz(B.D(k), 40))
            end
            name, beruf = B.Kurz(B.D(name), 40), B.Kurz(B.D(beruf), 40)
            if not eigene[name] then
                local e = d.fremd[name] or { von = absender, at = time(), berufe = {} }
                d.fremd[name] = e
                e.berufe[beruf] = e.berufe[beruf] or {}
                for rid, item, nr in string.gmatch(ids, "(%d+)%.(%d+)%.?(%d*)") do
                    if anzahl < 3000 then
                        anzahl = anzahl + 1
                        e.berufe[beruf][tonumber(rid)] = tonumber(item)
                        local k = kats[tonumber(nr) or 0]
                        if k then
                            d.katGruppe[tonumber(rid)] = k
                        end
                    end
                end
            end
        end
    end
    d.fremdStand[absender] = Kat.Pruefzahl(text or "")
    if FensterAktualisieren then
        FensterAktualisieren()
    end
end

-- Name eines Rezepts (auch Verzauberungen ohne Gegenstand)
function Kat.Name(rid, itemID)
    local d = Kat.Daten()
    local r = d.recipes[rid]
    if r and r.name then
        return r.name
    end
    if d.katNamen[rid] then
        return d.katNamen[rid]
    end
    local name
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, rid)
        name = ok and n or nil
    elseif GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, rid)
        name = ok and n or nil
    end
    if not name and itemID and itemID > 0 then
        name = ItemName(itemID)
    end
    if name then
        d.katNamen[rid] = name
    end
    return name
end

function Kat.Icon(rid, itemID)
    if itemID and itemID > 0 then
        local i = ItemIcon(itemID)
        if i then
            return i
        end
    end
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, t = pcall(C_Spell.GetSpellTexture, rid)
        if ok and t then
            return t
        end
    end
    local r = GuildERPData.recipes[rid]
    return r and r.icon or K.ICON_REZEPT
end

-- alles zusammen: berufe[Beruf][rid] = { itemID, wer = { Namen }, eigen = true/false }
function Kat.Sammeln()
    local d = Kat.Daten()
    local berufe = {}
    local function dazu(beruf, rid, itemID, wer, eigen)
        berufe[beruf] = berufe[beruf] or {}
        local e = berufe[beruf][rid]
        if not e then
            e = { itemID = itemID, wer = {}, eigen = false }
            berufe[beruf][rid] = e
        end
        if (not e.itemID or e.itemID == 0) and itemID then
            e.itemID = itemID
        end
        table.insert(e.wer, wer)
        e.eigen = e.eigen or eigen
    end
    local fraktion = SpielerFraktion()
    for _, c in pairs(d.characters) do
        for beruf, ids in pairs((not c.faction or c.faction == fraktion) and c.recipes or {}) do
            for rid in pairs(ids) do
                local r = d.recipes[rid]
                dazu(beruf, rid, r and r.itemID or 0, c.name or "?", true)
            end
        end
    end
    for name, e in pairs(d.fremd) do
        for beruf, ids in pairs(e.berufe or {}) do
            for rid, item in pairs(ids) do
                dazu(beruf, rid, item, name, false)
            end
        end
    end
    return berufe
end

-- ----- Ansicht "Katalog" -----
function Kat.AnsichtBauen(f)
    local a = O.Rahmen("Frame", nil, f)
    a:SetPoint("TOPLEFT", 18, -46)
    a:SetPoint("BOTTOMRIGHT", -18, 16)
    a:Hide()
    local L = O.Rahmen("Frame", nil, a)
    L:SetPoint("TOPLEFT", 0, 0)
    L:SetPoint("BOTTOMLEFT", 0, 0)
    L:SetWidth(400)
    L.titel = Schrift(L, "GameFontNormalLarge")
    L.titel:SetPoint("TOPLEFT", 0, -4)
    L.titel:SetText("Wer kann was?")
    L.beruf = WahlKnopf(L, 400)
    L.beruf:SetHeight(40)
    L.beruf:SetPoint("TOPLEFT", 0, -30)
    if L.beruf.text.SetFontObject then
        L.beruf.text:SetFontObject("GameFontNormalLarge")
    end
    L.beruf.rechts = Schrift(L.beruf, "GameFontHighlightSmall", false)
    L.beruf.rechts:SetPoint("RIGHT", -26, 0)
    L.beruf.rechts:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    L.beruf.text:ClearAllPoints()
    L.beruf.text:SetPoint("LEFT", 12, 0)
    L.beruf.text:SetPoint("RIGHT", L.beruf.rechts, "LEFT", -8, 0)
    L.suche = O.Rahmen("EditBox", nil, L, K.BACKDROP_VORLAGE)
    L.suche:SetHeight(28)
    L.suche:SetPoint("TOPLEFT", 0, -80)
    L.suche:SetPoint("TOPRIGHT", 0, -80)
    L.suche:SetAutoFocus(false)
    L.suche:SetFontObject("GameFontHighlight")
    L.suche:SetTextInsets(26, 8, 0, 0)
    Flaeche(L.suche, { 0.12, 0.13, 0.15, 1 }, { 0.23, 0.21, 0.16, 1 })
    L.suche.lupe = L.suche:CreateTexture(nil, "ARTWORK")
    L.suche.lupe:SetSize(14, 14)
    L.suche.lupe:SetPoint("LEFT", 8, 0)
    L.suche.lupe:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    L.suche.platzhalter = Schrift(L.suche, "GameFontDisable")
    L.suche.platzhalter:SetPoint("LEFT", 26, 0)
    L.suche:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    L.suche:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    L.suche:SetScript("OnTextChanged", function(self)
        L.suche.platzhalter:SetShown((self:GetText() or "") == "")
        FensterAktualisieren()
    end)
    O.SucheLook(L.suche)
    O.ListenHg(L)
    L.scroll, L.inhalt = Liste(L)
    L.scroll:SetPoint("TOPLEFT", 0, -116)
    L.scroll:SetPoint("BOTTOMRIGHT", -24, 28)
    L.leer = Schrift(L.inhalt, "GameFontHighlight")
    L.leer:SetPoint("TOPLEFT", 4, -6)
    L.leer:SetPoint("RIGHT", L.inhalt, "RIGHT", -4, 0)
    L.leer:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    L.abgleich = O.Rahmen("Button", nil, L, "UIPanelButtonTemplate")
    L.abgleich:SetSize(130, 22)
    L.abgleich:SetPoint("BOTTOMRIGHT", 0, 0)
    L.abgleich:SetText("Jetzt abgleichen")
    L.abgleich:SetScript("OnClick", function() Kat.JetztAbgleichen() end)
    L.fuss = Schrift(L, "GameFontDisableSmall")
    L.fuss:SetPoint("BOTTOMLEFT", 2, 4)
    L.fuss:SetPoint("RIGHT", L.abgleich, "LEFT", -8, 0)
    L.zeilen = {}
    a.links = L
    a.trenner = a:CreateTexture(nil, "ARTWORK")
    a.trenner:SetWidth(1)
    a.trenner:SetPoint("TOPLEFT", 414, -2)
    a.trenner:SetPoint("BOTTOMLEFT", 414, 2)
    a.trenner:SetColorTexture(K.GOLD_DUNKEL[1], K.GOLD_DUNKEL[2], K.GOLD_DUNKEL[3], 0.7)
    -- rechts: gewaehltes Rezept
    local R = O.Rahmen("Frame", nil, a)
    R:SetPoint("TOPLEFT", 430, 0)
    R:SetPoint("BOTTOMRIGHT", 0, 0)
    R.karte = O.Rahmen("Frame", nil, R, K.BACKDROP_VORLAGE)
    R.karte:SetPoint("TOPLEFT", 0, -2)
    R.karte:SetPoint("TOPRIGHT", 0, -2)
    R.karte:SetHeight(66)
    Flaeche(R.karte, { 0.12, 0.13, 0.15, 1 }, { 0.23, 0.21, 0.16, 1 })
    R.karte.icon = R.karte:CreateTexture(nil, "ARTWORK")
    R.karte.icon:SetSize(40, 40)
    R.karte.icon:SetPoint("LEFT", 12, 0)
    R.karte.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    R.karte.name = Schrift(R.karte, "GameFontNormalLarge")
    R.karte.name:SetPoint("TOPLEFT", 64, -12)
    R.karte.name:SetPoint("RIGHT", -10, 0)
    R.karte.unter = Schrift(R.karte, "GameFontHighlightSmall")
    R.karte.unter:SetPoint("TOPLEFT", R.karte.name, "BOTTOMLEFT", 0, -4)
    R.karte.unter:SetPoint("RIGHT", -10, 0)
    R.karte.unter:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    R.karte:EnableMouse(true)
    R.karte:SetScript("OnEnter", function(self) Kat.Tooltip(self, self.rid, self.itemID, self.werText) end)
    R.karte:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    R.wer = Schrift(R, "GameFontHighlight")
    R.wer:SetPoint("TOPLEFT", R.karte, "BOTTOMLEFT", 2, -12)
    R.wer:SetPoint("RIGHT", -2, 0)
    R.zTitel = Schrift(R, "GameFontNormal")
    R.zTitel:SetPoint("TOPLEFT", R.wer, "BOTTOMLEFT", 0, -14)
    R.zTitel:SetText("Zutaten")
    R.zutaten = Schrift(R, "GameFontHighlight")
    R.zutaten:SetPoint("TOPLEFT", R.zTitel, "BOTTOMLEFT", 0, -6)
    R.zutaten:SetPoint("RIGHT", -2, 0)
    if R.zutaten.SetSpacing then
        R.zutaten:SetSpacing(4)
    end
    -- Bestellfeld (ab 1.0)
    local F = O.Rahmen("Frame", nil, R, K.BACKDROP_VORLAGE)
    F:SetPoint("BOTTOMLEFT", 0, 0)
    F:SetPoint("BOTTOMRIGHT", 0, 0)
    F:SetHeight(196)
    Flaeche(F, { 0.11, 0.11, 0.13, 1 }, { 0.23, 0.21, 0.16, 1 })
    F.titel = Schrift(F, "GameFontNormalLarge")
    F.titel:SetPoint("TOPLEFT", 12, -10)
    F.titel:SetText("Bestellen")
    local function label(text, y)
        local t = Schrift(F, "GameFontHighlightSmall")
        t:SetPoint("TOPLEFT", 12, y)
        t:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
        t:SetText(text)
        return t
    end
    label("Wie viele?", -44)
    F.minus = O.Rahmen("Button", nil, F, "UIPanelButtonTemplate")
    F.minus:SetSize(26, 24)
    F.minus:SetPoint("TOPLEFT", 104, -38)
    F.minus:SetText("-")
    F.menge = Schrift(F, "GameFontHighlightLarge")
    F.menge:SetWidth(36)
    F.menge:SetJustifyH("CENTER")
    F.menge:SetPoint("LEFT", F.minus, "RIGHT", 2, 0)
    F.plus = O.Rahmen("Button", nil, F, "UIPanelButtonTemplate")
    F.plus:SetSize(26, 24)
    F.plus:SetPoint("LEFT", F.menge, "RIGHT", 2, 0)
    F.plus:SetText("+")
    label("Bei wem?", -76)
    F.an = WahlKnopf(F, 260)
    F.an:SetPoint("TOPLEFT", 104, -70)
    label("Zutaten", -108)
    F.mats = WahlKnopf(F, 260)
    F.mats:SetPoint("TOPLEFT", 104, -102)
    label("Notiz", -140)
    F.notiz = O.Rahmen("EditBox", nil, F, K.BACKDROP_VORLAGE)
    F.notiz:SetHeight(24)
    F.notiz:SetPoint("TOPLEFT", 104, -134)
    F.notiz:SetPoint("RIGHT", -12, 0)
    F.notiz:SetAutoFocus(false)
    F.notiz:SetFontObject("GameFontHighlightSmall")
    F.notiz:SetTextInsets(8, 8, 0, 0)
    F.notiz:SetMaxLetters(120)
    Flaeche(F.notiz, { 0.07, 0.07, 0.09, 1 }, { 0.23, 0.21, 0.16, 1 })
    F.notiz:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    F.notiz:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    F.knopf = O.Rahmen("Button", nil, F, "UIPanelButtonTemplate")
    F.knopf:SetSize(110, 26)
    F.knopf:SetPoint("BOTTOMRIGHT", -10, 10)
    F.knopf:SetText("Bestellen")
    F.hinweis = Schrift(F, "GameFontHighlightSmall")
    F.hinweis:SetPoint("BOTTOMLEFT", 12, 14)
    F.hinweis:SetPoint("RIGHT", F.knopf, "LEFT", -10, 0)
    F.hinweis:SetTextColor(0.85, 0.80, 0.66)
    R.form = F
    R.baumScroll, R.baumInhalt = Liste(R)
    R.baumScroll:SetPoint("TOPLEFT", R.zTitel, "BOTTOMLEFT", -2, -4)
    R.baumScroll:SetPoint("BOTTOMRIGHT", F, "TOPRIGHT", -24, 8)
    R.baumZeilen = {}
    R.leer = Schrift(R, "GameFontHighlight")
    R.leer:SetPoint("TOPLEFT", 2, -8)
    R.leer:SetPoint("RIGHT", -2, 0)
    R.leer:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    a.rechts = R
    f.kat = a
    return a
end

function Kat.ZeileBauen(eltern)
    local z = O.Rahmen("Button", nil, eltern)
    z:SetHeight(32)
    z.hg = z:CreateTexture(nil, "BACKGROUND")
    z.hg:SetAllPoints()
    local hl = z:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.05)
    z.hl, z.hlAlpha = hl, 0.05
    z.markierung = z:CreateTexture(nil, "ARTWORK")
    z.markierung:SetWidth(2)
    z.markierung:SetPoint("TOPLEFT")
    z.markierung:SetPoint("BOTTOMLEFT")
    z.markierung:SetColorTexture(K.GOLD[1], K.GOLD[2], K.GOLD[3], 1)
    z.linie = z:CreateTexture(nil, "BACKGROUND")
    z.linie:SetHeight(1)
    z.linie:SetPoint("BOTTOMLEFT")
    z.linie:SetPoint("BOTTOMRIGHT")
    z.linie:SetColorTexture(1, 1, 1, 0.05)
    z.icon = z:CreateTexture(nil, "ARTWORK")
    z.icon:SetSize(22, 22)
    z.icon:SetPoint("LEFT", 8, 0)
    z.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    z.wer = Schrift(z, "GameFontHighlightSmall", false)
    z.wer:SetPoint("RIGHT", -6, 0)
    z.wer:SetTextColor(K.STATUS_RGB.blau[1], K.STATUS_RGB.blau[2], K.STATUS_RGB.blau[3])
    z.name = Schrift(z, "GameFontHighlight")
    z.name:SetPoint("LEFT", z.icon, "RIGHT", 8, 0)
    z.name:SetPoint("RIGHT", z.wer, "LEFT", -8, 0)
    if z.name.SetWordWrap then
        z.name:SetWordWrap(false)
    end
    O.Teil(function(spiel) O.ZeileLook(z, spiel) end)
    z:SetScript("OnEnter", function(self) Kat.Tooltip(self, self.rid, self.itemID, self.werText) end)
    z:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    return z
end

-- Tooltip: Gegenstand (falls es einen gibt), sonst der Zauber (z. B. Verzauberung), dazu wer es kann
function Kat.Tooltip(eigner, rid, itemID, wer)
    if not GameTooltip or not rid then
        return
    end
    GameTooltip:SetOwner(eigner, "ANCHOR_RIGHT")
    local ok = false
    if itemID and itemID > 0 then
        ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. itemID)
    end
    if not ok and GameTooltip.SetSpellByID then
        ok = pcall(GameTooltip.SetSpellByID, GameTooltip, rid)
    end
    if not ok then
        GameTooltip:AddLine(Kat.Name(rid, itemID) or ("Rezept " .. rid), 1, 0.82, 0)
    end
    if wer and wer ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Kann es: " .. wer, K.STATUS_RGB.blau[1], K.STATUS_RGB.blau[2], K.STATUS_RGB.blau[3], true)
    end
    GameTooltip:Show()
end

Kat.auf = {} -- nur fuer diese Sitzung: auf-/zugeklappte Gruppen im Katalog
Kat.baumZu = {} -- nur fuer diese Sitzung: zugeklappte Zutaten im Katalog-Baum



-- ===========================================================================
-- Guild-Found (ab 1.3): Haken in den Optionen.
-- - Abgleich, Katalog und Bestellungen nur mit der Gilde (Gildenkanal statt Gruppe).
-- - Handel: oeffnet ein Nicht-Gildenmitglied den Handel, schliesst Guild ERP ihn und antwortet
--   einmal freundlich (Ausnahme von "nur lesen", vom Nutzer am 18.10. so entschieden).
-- - Post: kann nicht verhindert werden; fremde Post wird markiert, Zuruecksenden nur auf Klick.
--   Beim Schreiben an Nicht-Gildenmitglieder erscheint eine Warnung (Senden-Knopf bleibt unberuehrt).
-- ===========================================================================
O.gilde = { namen = {}, zahl = 0, at = 0, geantwortet = {} }

function O.GildeModus()
    return O.Wert("gilde") == true
end

function O.Wir()
    return O.GildeModus() and "Gilde" or "Gruppe"
end

-- Gildenliste beim Spiel anfordern (hoechstens alle 30 s) und lesen
function O.GildeLesen()
    if not (IsInGuild and IsInGuild()) then
        O.gilde.namen, O.gilde.zahl = {}, 0
        return
    end
    if time() - (O.gilde.angefragt or 0) > 30 then
        O.gilde.angefragt = time()
        if C_GuildInfo and C_GuildInfo.GuildRoster then
            pcall(C_GuildInfo.GuildRoster)
        elseif GuildRoster then
            pcall(GuildRoster)
        end
    end
    local n = GetNumGuildMembers and GetNumGuildMembers() or 0
    if n <= 0 or not GetGuildRosterInfo then
        return
    end
    local namen, online = {}, {}
    for i = 1, n do
        local ok, name, _, _, _, _, _, _, _, istOnline = pcall(GetGuildRosterInfo, i)
        if ok and name then
            local kurz = B.Name(name)
            namen[kurz] = true
            if istOnline then
                table.insert(online, kurz)
            end
        end
    end
    O.gilde.namen, O.gilde.online, O.gilde.zahl, O.gilde.at = namen, online, n, time()
end

-- Ist der Name (voll, mit oder ohne Realm, oder nur Vorname) in meiner Gilde?
function O.InGilde(name)
    name = B.Name(name)
    if not name then
        return false
    end
    if O.gilde.zahl == 0 then
        O.GildeLesen()
    end
    if O.gilde.namen[name] then
        return true
    end
    for m in pairs(O.gilde.namen) do
        if B.Gleich(name, m) then
            return true
        end
    end
    -- eigene Charaktere zaehlen immer als "in der Gilde"
    return B.EigeneNamen()[name] and true or false
end

function O.GildeBekannt()
    if O.gilde.zahl == 0 then
        O.GildeLesen()
    end
    return O.gilde.zahl > 0
end

function O.GildeOnline()
    O.GildeLesen()
    local namen = {}
    for _, n in ipairs(O.gilde.online or {}) do
        if not B.Gleich(n, B.Ich()) then
            table.insert(namen, n)
        end
    end
    table.sort(namen)
    return namen
end

-- beim Einloggen bzw. Einschalten: mit der Gilde abgleichen
function O.GildeStart()
    if not (O.GildeModus() and IsInGuild and IsInGuild()) then
        return
    end
    O.GildeLesen()
    B.Einreihen("H~2")
    B.StandSenden()
end

-- ----- Handel -----
function O.HandelPruefen()
    if not O.GildeModus() then
        return
    end
    local inGilde
    if UnitIsInMyGuild then
        local ok, ja = pcall(UnitIsInMyGuild, "NPC")
        if ok then
            inGilde = ja and true or false
        end
    end
    local name = UnitName and UnitName("NPC")
    if inGilde == nil then
        if not O.GildeBekannt() then
            return -- Gildenliste noch unbekannt: lieber nichts tun
        end
        inGilde = O.InGilde(name)
    end
    if inGilde or (name and B.EigeneNamen()[B.Name(name)]) then
        return
    end
    local ok = CancelTrade and pcall(CancelTrade)
    if not ok then
        Melden("Guild-Found: " .. (name or "Jemand") .. " ist nicht in deiner Gilde. Bitte den Handel selbst ablehnen.")
        return
    end
    Melden("Guild-Found: Handel mit " .. (name or "?") .. " abgelehnt (nicht in deiner Gilde).")
    -- hoechstens eine Antwort pro Spieler und 5 Minuten, nie im Kampf
    local schluessel = name or "?"
    if name and time() - (O.gilde.geantwortet[schluessel] or 0) > 300 and not (InCombatLockdown and InCombatLockdown()) then
        O.gilde.geantwortet[schluessel] = time()
        local ziel = (GetUnitName and GetUnitName("NPC", true)) or name
        local text = "Nein danke – wir spielen Guild-Found und handeln nur innerhalb unserer Gilde. Viel Spaß noch!"
        if C_ChatInfo and C_ChatInfo.SendChatMessage then
            pcall(C_ChatInfo.SendChatMessage, text, "WHISPER", nil, ziel)
        elseif SendChatMessage then
            pcall(SendChatMessage, text, "WHISPER", nil, ziel)
        end
    end
end

-- ----- Post -----
function O.PostFenster()
    local w = O.post
    if w then
        return w
    end
    local anker = _G.InboxFrame or _G.MailFrame
    if not anker then
        return nil
    end
    w = O.Rahmen("Frame", "GuildERPPost", _G.MailFrame or UIParent, K.BACKDROP_VORLAGE)
    w:SetWidth(300)
    w:SetPoint("TOPLEFT", _G.MailFrame or anker, "TOPRIGHT", 4, -24)
    if w.SetBackdrop then
        w:SetBackdrop(K.BACKDROP_RAHMEN)
    end
    local deckel = w:CreateTexture(nil, "BACKGROUND", nil, -8)
    deckel:SetPoint("TOPLEFT", 6, -6)
    deckel:SetPoint("BOTTOMRIGHT", -6, 6)
    deckel:SetColorTexture(0.06, 0.06, 0.07, 0.96)
    w.titel = Schrift(w, "GameFontNormal")
    w.titel:SetPoint("TOPLEFT", 16, -14)
    w.titel:SetPoint("RIGHT", -16, 0)
    w.titel:SetText("Guild-Found: Post von außerhalb der Gilde")
    w.unter = Schrift(w, "GameFontHighlightSmall")
    w.unter:SetPoint("TOPLEFT", w.titel, "BOTTOMLEFT", 0, -4)
    w.unter:SetPoint("RIGHT", -16, 0)
    w.unter:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    w.unter:SetText("Nichts davon annehmen. „Zurücksenden“ schickt den Brief samt Inhalt zurück.")
    w.zeilen = {}
    O.post = w
    return w
end

function O.PostPruefen()
    local w = O.post
    if not O.GildeModus() or not (GetInboxNumItems and GetInboxHeaderInfo) then
        if w then
            w:Hide()
        end
        return
    end
    if not O.GildeBekannt() then
        return
    end
    local fremde = {}
    local n = GetInboxNumItems() or 0
    for i = 1, n do
        local ok, _, _, absender, betreff, _, _, _, _, _, _, _, kannAntworten, istGM = pcall(GetInboxHeaderInfo, i)
        if ok and absender and kannAntworten and not istGM and not O.InGilde(absender) then
            table.insert(fremde, { i = i, wer = absender, betreff = betreff or "" })
        end
    end
    if #fremde == 0 then
        if w then
            w:Hide()
        end
        return
    end
    w = O.PostFenster()
    if not w then
        return
    end
    local y = 50
    for k, e in ipairs(fremde) do
        local z = w.zeilen[k]
        if not z then
            z = O.Rahmen("Frame", nil, w)
            z:SetHeight(26)
            z.text = Schrift(z, "GameFontHighlightSmall")
            z.text:SetPoint("LEFT", 0, 0)
            z.text:SetPoint("RIGHT", -112, 0)
            if z.text.SetWordWrap then
                z.text:SetWordWrap(false)
            end
            z.knopf = O.Rahmen("Button", nil, z, "UIPanelButtonTemplate")
            z.knopf:SetSize(106, 22)
            z.knopf:SetPoint("RIGHT", 0, 0)
            z.knopf:SetText("Zurücksenden")
            w.zeilen[k] = z
        end
        z:ClearAllPoints()
        z:SetPoint("TOPLEFT", 16, -y)
        z:SetPoint("RIGHT", w, "RIGHT", -16, 0)
        z.text:SetText(e.wer .. ": " .. e.betreff)
        local index = e.i
        z.knopf:SetScript("OnClick", function()
            -- nur auf Klick des Spielers
            if ReturnInboxItem then
                pcall(ReturnInboxItem, index)
            end
        end)
        z:Show()
        y = y + 28
    end
    for k = #fremde + 1, #w.zeilen do
        w.zeilen[k]:Hide()
    end
    w:SetHeight(y + 12)
    w:Show()
end

-- Warnung beim Schreiben an Nicht-Gildenmitglieder (Senden-Knopf des Spiels bleibt unberuehrt)
function O.PostSendenWarnung()
    local feld = _G.SendMailNameEditBox
    if not feld or O.postHaken then
        return
    end
    O.postHaken = true
    local warn = feld:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    warn:SetPoint("TOPLEFT", feld, "BOTTOMLEFT", 0, -2)
    warn:SetWidth(260)
    warn:SetJustifyH("LEFT")
    warn:Hide()
    O.postWarn = warn
    feld:HookScript("OnTextChanged", function(self)
        O.Sicher("Post-Warnung", function()
            local t = self:GetText() or ""
            local zeigen = O.GildeModus() and t ~= "" and O.GildeBekannt() and not O.InGilde(t)
            warn:SetText(zeigen and "Guild-Found: nicht in deiner Gilde" or "")
            warn:SetShown(zeigen and true or false)
        end)
    end)
end

function O.GildeEreignis(event, ...)
    if event == "TRADE_SHOW" then
        pcall(O.HandelPruefen)
        return true
    elseif event == "MAIL_SHOW" then
        O.GildeLesen()
        pcall(O.PostSendenWarnung)
        pcall(O.PostPruefen)
        return true
    elseif event == "MAIL_INBOX_UPDATE" then
        pcall(O.PostPruefen)
        return true
    elseif event == "MAIL_CLOSED" then
        if O.post then
            O.post:Hide()
        end
        return true
    elseif event == "GUILD_ROSTER_UPDATE" then
        if O.GildeModus() then
            O.gilde.angefragt = O.gilde.angefragt or time()
            local n = GetNumGuildMembers and GetNumGuildMembers() or 0
            if n > 0 then
                O.gilde.zahl = 0 -- beim naechsten Zugriff neu lesen
            end
        end
        return true
    end
    return false
end

-- ===========================================================================
-- Spiel-Look (ab 1.1.6, Testversion): Guild ERP sieht aus wie das Berufefenster.
-- Nur Grafiken und Schriften aus dem Spielclient (Namen per /gerp optik ausgelesen).
-- Umschaltbar in den Optionen ("Aussehen"); alles laesst sich zuruecknehmen.
-- ===========================================================================
O.teile = {}
O.BERUF_KARTE = { [164] = "Blacksmithing", [165] = "Leatherworking", [171] = "Alchemy", [197] = "Tailoring",
    [202] = "Engineering", [333] = "Enchanting", [755] = "Jewelcrafting", [773] = "Inscription", [185] = "Cooking",
    [186] = "Mining", [182] = "Herbalism", [393] = "Skinning", [356] = "Fishing", [129] = "FirstAid" }

function O.Spiel()
    return O.Wert("look") == "spiel"
end

function O.HatAtlas(name)
    if not (C_Texture and C_Texture.GetAtlasInfo) then
        return false
    end
    local ok, info = pcall(C_Texture.GetAtlasInfo, name)
    return ok and info ~= nil
end

function O.Atlas(tex, name, groesse)
    if tex and tex.SetAtlas and O.HatAtlas(name) then
        tex:SetAtlas(name, groesse and true or false)
        return true
    end
    return false
end

-- Teil anmelden: fn(spiel) wird jetzt und bei jedem Umschalten aufgerufen
function O.Teil(fn)
    table.insert(O.teile, fn)
    local ok, fehler = pcall(fn, O.Spiel())
    if not ok and GuildERPData and GuildERPData.diagnostics then
        GuildERPData.diagnostics.lookFehler = tostring(fehler)
    end
end

function O.LookAnwenden()
    local spiel = O.Spiel()
    for _, fn in ipairs(O.teile) do
        local ok, fehler = pcall(fn, spiel)
        if not ok then
            Daten().diagnostics.lookFehler = tostring(fehler)
        end
    end
    for _, fl in ipairs(O.flaechen or {}) do
        if fl.lookHg and fl.GetBackdrop and fl:GetBackdrop() then
            fl:SetBackdropColor(fl.lookHg[1], fl.lookHg[2], fl.lookHg[3], (fl.lookHg[4] or 1) * O.FlaecheAlpha(fl))
        end
    end
    if FensterAktualisieren then
        FensterAktualisieren()
    end
end

-- dunkle Kaesten im Hauptfenster werden im Spiel-Look durchscheinend (Holz sichtbar)
function O.FlaecheAlpha(f)
    if not O.Spiel() then
        return 1
    end
    if f.lookImFenster == nil then
        local p, n = f, 0
        f.lookImFenster = false
        while p and p.GetParent and n < 20 do
            if p.deckend then
                break -- eigene Fenster (Bestellschein, Zusage) bleiben immer deckend
            end
            if p == _G.GuildERPFenster then
                f.lookImFenster = true
                break
            end
            p = p:GetParent()
            n = n + 1
        end
    end
    return f.lookImFenster and 0.55 or 1
end

-- Kasten mit/ohne eigenen Rahmen
function O.Kasten(f, spielAn)
    if not f.SetBackdrop then
        return
    end
    if spielAn then
        f:SetBackdrop(nil)
    elseif f.lookHg then
        Flaeche(f, f.lookHg, f.lookKante)
    end
end

function O.WahlLook(b, spiel)
    if spiel and not b.spielHg then
        b.spielHg = b:CreateTexture(nil, "BACKGROUND")
        b.spielHg:SetAllPoints()
        b.spielOk = O.Atlas(b.spielHg, "common-dropdown-b-button")
    end
    local an = spiel and b.spielOk
    if b.spielHg then
        b.spielHg:SetShown(an and true or false)
    end
    O.Kasten(b, an)
end

function O.SucheLook(e)
    O.Teil(function(spiel)
        if spiel and not e.spielM then
            e.spielL = e:CreateTexture(nil, "BACKGROUND")
            e.spielR = e:CreateTexture(nil, "BACKGROUND")
            e.spielM = e:CreateTexture(nil, "BACKGROUND")
            e.spielOk = O.Atlas(e.spielL, "common-search-border-left") and O.Atlas(e.spielR, "common-search-border-right")
                and O.Atlas(e.spielM, "common-search-border-middle")
            e.spielL:SetPoint("TOPLEFT", 0, -2)
            e.spielL:SetPoint("BOTTOMLEFT", 0, 2)
            e.spielL:SetWidth(8)
            e.spielR:SetPoint("TOPRIGHT", 0, -2)
            e.spielR:SetPoint("BOTTOMRIGHT", 0, 2)
            e.spielR:SetWidth(8)
            e.spielM:SetPoint("TOPLEFT", e.spielL, "TOPRIGHT")
            e.spielM:SetPoint("BOTTOMRIGHT", e.spielR, "BOTTOMLEFT")
        end
        local an = spiel and e.spielOk and true or false
        for _, t in ipairs({ e.spielL, e.spielR, e.spielM }) do
            t:SetShown(an)
        end
        O.Kasten(e, an)
        if an and O.Atlas(e.lupe, "common-search-magnifyingglass") then
            e.lupe:SetSize(12, 12)
            e.lupe:SetVertexColor(0.6, 0.6, 0.6, 1)
        else
            e.lupe:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
            e.lupe:SetSize(14, 14)
            e.lupe:SetVertexColor(1, 1, 1, 1)
        end
    end)
end

-- dunkler Listen-Hintergrund wie links im Berufefenster
function O.ListenHg(L)
    O.Teil(function(spiel)
        if spiel and not L.spielHg then
            L.spielHg = L:CreateTexture(nil, "BACKGROUND", nil, -6)
            L.spielHg:SetPoint("TOPLEFT", L.suche, "TOPLEFT", -6, 6)
            L.spielHg:SetPoint("BOTTOMRIGHT", L, "BOTTOMRIGHT", 2, -4)
            L.spielOk = O.Atlas(L.spielHg, "Professions-background-summarylist")
        end
        if L.spielHg then
            L.spielHg:SetShown(spiel and L.spielOk and true or false)
        end
    end)
end

function O.ZeileLook(z, spiel)
    if z.linie then
        z.linie:SetShown(not spiel)
    end
    if spiel and O.Atlas(z.hl, "Professions_Recipe_Hover") then
        z.hl:SetAlpha(0.5)
    else
        z.hl:SetColorTexture(1, 1, 1, z.hlAlpha or 0.06)
        z.hl:SetAlpha(1)
    end
end

function O.Gewaehlt(z, an)
    if O.Spiel() and O.HatAtlas("Professions_Recipe_Active") then
        z.markierung:Hide()
        if an then
            z.hg:SetAtlas("Professions_Recipe_Active")
            z.hg:SetVertexColor(1, 1, 1, 1)
        else
            z.hg:SetColorTexture(0, 0, 0, 0)
        end
    else
        z.hg:SetColorTexture(0.16, 0.14, 0.08, an and 1 or 0)
        z.markierung:SetShown(an and true or false)
    end
end

function O.KopfLook(k, spiel)
    if spiel and not k.spielHg then
        k.spielHg = k:CreateTexture(nil, "BACKGROUND")
        k.spielHg:SetAllPoints()
        k.spielOk = O.Atlas(k.spielHg, "common-button-list-collapseExpand")
    end
    local an = spiel and k.spielOk and true or false
    if k.spielHg then
        k.spielHg:SetShown(an)
    end
    k.linie:SetShown(not an)
    k.spielAn = an
    if an then
        k.pfeil:ClearAllPoints()
        k.pfeil:SetPoint("RIGHT", -12, 0)
        k.rechtsText:ClearAllPoints()
        k.rechtsText:SetPoint("RIGHT", -34, 0)
        k.text:ClearAllPoints()
        k.text:SetPoint("LEFT", 10, 0)
        k.text:SetPoint("RIGHT", k.rechtsText, "LEFT", -8, 0)
        if _G.Game15Font_Shadow and k.text.SetFontObject then
            k.text:SetFontObject("Game15Font_Shadow")
        end
    else
        k.anker()
        if k.text.SetFontObject then
            k.text:SetFontObject("GameFontNormal")
        end
    end
end

-- Auf-/Zu-Zeichen eines Kopfes
function O.KopfIcon(k, offen)
    if k.spielAn then
        if k.pfeil.SetRotation then
            k.pfeil:SetRotation(0)
        end
        k.pfeil:SetVertexColor(1, 1, 1, 1)
        if O.Atlas(k.pfeil, offen and "common-button-list-minus" or "common-button-list-plus", true) then
            return
        end
    end
    k.pfeil:SetSize(k.pfeilGr or 12, k.pfeilGr or 12)
    if k.altPfeil and not k.spielAn then
        k.pfeil:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
        if k.pfeil.SetRotation then
            k.pfeil:SetRotation(offen and (-math.pi / 2) or 0)
        end
    else
        if k.pfeil.SetRotation then
            k.pfeil:SetRotation(0)
        end
        k.pfeil:SetTexture(offen and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
    end
end

-- Hintergrund-Karte des Berufs (rechte Seite), z. B. Amboss bei Schmiedekunst
function O.KarteHg(R, beruf)
    if not R then
        return
    end
    if not O.Spiel() then
        if R.spielKarte then
            R.spielKarte:Hide()
            R.spielRand:Hide()
        end
        return
    end
    if not R.spielKarte then
        R.spielKarte = R:CreateTexture(nil, "BACKGROUND", nil, -6)
        R.spielKarte:SetPoint("TOPLEFT", -6, 6)
        R.spielKarte:SetPoint("BOTTOMRIGHT", 6, -6)
        R.spielRand = R:CreateTexture(nil, "BORDER", nil, -6)
        R.spielRand:SetAllPoints(R.spielKarte)
        if not O.Atlas(R.spielRand, "common-insideframe") then
            R.spielRand:SetTexture(nil)
        end
    end
    local id
    for _, r in pairs(Daten().recipes) do
        if r.profession == beruf and r.professionID then
            id = r.professionID
            break
        end
    end
    local schl = (id and O.BERUF_KARTE[id]) or Kat.BERUF_NAME[beruf or ""]
    local ok = schl and O.Atlas(R.spielKarte, "Profession-background-card-" .. schl)
    if not ok then
        ok = O.Atlas(R.spielKarte, "Profession-Background-Template2")
    end
    R.spielKarte:SetShown(ok and true or false)
    R.spielRand:Show()
end

-- Seitenreiter rechts am Fenster (wie die Berufe-Reiter im Berufefenster)
-- Reihenfolge der Reiter (ab 1.1.9): settings.optionen.reiter = { "werk", "plan", "best", "kat" }
O.REITER_NAME = { werk = "Werkstatt", plan = "Planaufträge", best = "Bestellungen", kat = "Katalog" }
O.REITER_STANDARD = { "werk", "plan", "best", "kat" }

function O.Reihenfolge()
    local r = O.Wert("reiter")
    if type(r) == "table" and #r == 4 then
        local da = {}
        for _, w in ipairs(r) do
            if O.REITER_NAME[w] and not da[w] then
                da[w] = true
            end
        end
        if da.werk and da.plan and da.best and da.kat then
            return r
        end
    end
    return O.REITER_STANDARD
end

function O.ReiterSchieben(i, um)
    local r = {}
    for k, w in ipairs(O.Reihenfolge()) do
        r[k] = w
    end
    local j = i + um
    if j < 1 or j > 4 then
        return
    end
    r[i], r[j] = r[j], r[i]
    O.Setzen("reiter", r)
    if Fenster then
        O.ReiterOrdnen(Fenster)
        FensterAktualisieren()
    end
    if O.fenster and O.fenster:IsShown() then
        O.Zeigen()
    end
end

function O.ReiterOrdnen(f)
    local knopf = { werk = f.reiterWerk, plan = f.reiterPlan, best = f.reiterBest, kat = f.reiterKat }
    local vorher
    for i, w in ipairs(O.Reihenfolge()) do
        local b = knopf[w]
        b:ClearAllPoints()
        if vorher then
            b:SetPoint("LEFT", vorher, "RIGHT", 4, 0)
        else
            b:SetPoint("LEFT", f.titel, "RIGHT", 22, -1)
        end
        vorher = b
        for _, sb in ipairs(f.seiten or {}) do
            if sb.wert == w then
                sb:ClearAllPoints()
                sb:SetPoint("TOPLEFT", f, "TOPRIGHT", -2, -44 - (i - 1) * 62)
            end
        end
    end
end

function O.SeitenSync(f, ansicht, planZahl, offen)
    O.ReiterOrdnen(f)
    if not f.seiten then
        return
    end
    local spiel = O.Spiel()
    for _, b in ipairs(f.seiten) do
        b:SetShown(spiel)
        b.wahl:SetShown(b.wert == ansicht)
        local n = (b.wert == "plan" and planZahl) or (b.wert == "best" and offen) or 0
        b.zahl:SetText(n > 0 and n or "")
    end
    if spiel then
        O.KarteHg(f.rechts, Daten().settings.beruf)
        O.KarteHg(f.kat and f.kat.rechts, Daten().settings.katBeruf)
    end
end

-- Inhalt nach unten schieben (Platz fuer das runde Bild oben links)
function O.Lage(f, dy)
    local function setze(fr, punkte)
        if not fr then
            return
        end
        fr:ClearAllPoints()
        for _, p in ipairs(punkte) do
            fr:SetPoint(p[1], p[2], p[3] - (string.find(p[1], "TOP") and dy or 0))
        end
    end
    setze(f.links, { { "TOPLEFT", 18, -46 }, { "BOTTOMLEFT", 18, 16 } })
    f.links:SetWidth(400)
    setze(f.rechts, { { "TOPLEFT", 446, -46 }, { "BOTTOMRIGHT", -18, 16 } })
    setze(f.trenner, { { "TOPLEFT", 432, -48 }, { "BOTTOMLEFT", 432, 18 } })
    setze(f.best, { { "TOPLEFT", 18, -52 }, { "BOTTOMRIGHT", -18, 16 } })
    setze(f.plan, { { "TOPLEFT", 18, -52 }, { "BOTTOMRIGHT", -18, 16 } })
    setze(f.kat, { { "TOPLEFT", 18, -46 }, { "BOTTOMRIGHT", -18, 16 } })
end

function O.RahmenBauen(f)
    local r = O.Rahmen("Frame", nil, f)
    r:SetAllPoints()
    r:SetFrameLevel((f:GetFrameLevel() or 1) + 40)
    local ok = NineSliceUtil and NineSliceUtil.ApplyLayoutByName and pcall(NineSliceUtil.ApplyLayoutByName, r, "PortraitFrameTemplate")
    if not ok then
        local function teil(atlas, ...)
            local t = r:CreateTexture(nil, "OVERLAY")
            O.Atlas(t, atlas, true)
            t:SetPoint(...)
            return t
        end
        local tl = teil("UI-Frame-PortraitMetal-CornerTopLeft", "TOPLEFT", -13, 16)
        local tr = teil("UI-Frame-Metal-CornerTopRight", "TOPRIGHT", 4, 16)
        local bl = teil("UI-Frame-Metal-CornerBottomLeft", "BOTTOMLEFT", -13, -3)
        local br = teil("UI-Frame-Metal-CornerBottomRight", "BOTTOMRIGHT", 4, -3)
        local function kante(atlas, a1, p1, a2, p2, horiz)
            local t = r:CreateTexture(nil, "OVERLAY")
            O.Atlas(t, atlas, true)
            t:SetPoint(a1, p1, horiz and "TOPRIGHT" or "BOTTOMLEFT")
            t:SetPoint(a2, p2, horiz and "BOTTOMLEFT" or "TOPRIGHT")
            if horiz and t.SetHorizTile then
                t:SetHorizTile(true)
            elseif t.SetVertTile then
                t:SetVertTile(true)
            end
        end
        kante("_UI-Frame-Metal-EdgeTop", "TOPLEFT", tl, "BOTTOMRIGHT", tr, true)
        kante("_UI-Frame-Metal-EdgeBottom", "TOPLEFT", bl, "BOTTOMRIGHT", br, true)
        kante("!UI-Frame-Metal-EdgeLeft", "TOPLEFT", tl, "BOTTOMRIGHT", bl, false)
        kante("!UI-Frame-Metal-EdgeRight", "TOPLEFT", tr, "BOTTOMRIGHT", br, false)
    end
    -- rundes Bild oben links (liegt unter dem Rahmen-Ring)
    f.portrait = f:CreateTexture(nil, "ARTWORK", nil, 7)
    f.portrait:SetSize(62, 62)
    f.portrait:SetPoint("TOPLEFT", -5, 7)
    f.portrait:SetTexture(K.ICON_TITEL)
    if f.CreateMaskTexture and f.portrait.AddMaskTexture then
        local m = f:CreateMaskTexture()
        if m then
        m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(f.portrait)
        f.portrait:AddMaskTexture(m)
        end
    end
    r.titel = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.titel:SetPoint("TOP", 0, -5)
    r.titel:SetText("Guild ERP")
    r.version = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.version:SetPoint("TOPRIGHT", -64, -6)
    r.version:SetText("Version " .. K.VERSION .. " (Beta)")
    -- Seitenreiter
    f.seiten = {}
    local liste = {
        { f.reiterWerk, "werk", K.ICON_TITEL, "Werkstatt" },
        { f.reiterPlan, "plan", "Interface\\Icons\\INV_Scroll_03", "Planaufträge" },
        { f.reiterBest, "best", "Interface\\Icons\\INV_Misc_Bag_08", "Bestellungen" },
        { f.reiterKat, "kat", "Interface\\Icons\\INV_Misc_Book_11", "Katalog" },
    }
    for i, e in ipairs(liste) do
        local b = O.Rahmen("Button", nil, f)
        b:SetSize(55, 60)
        b:SetPoint("TOPLEFT", f, "TOPRIGHT", -2, -44 - (i - 1) * 62)
        b.wert = e[2]
        b.hg = b:CreateTexture(nil, "BACKGROUND")
        b.hg:SetAllPoints()
        O.Atlas(b.hg, "common-sidetab")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(34, 34)
        b.icon:SetPoint("CENTER", -3, 0)
        b.icon:SetTexture(e[3])
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.wahl = b:CreateTexture(nil, "OVERLAY")
        b.wahl:SetAllPoints()
        O.Atlas(b.wahl, "common-sidetab-selected")
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        if not O.Atlas(hl, "common-sidetab-hover") then
            hl:SetColorTexture(1, 1, 1, 0.1)
        end
        b.zahl = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        b.zahl:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", 2, -2)
        local reiter, name = e[1], e[4]
        b:SetScript("OnClick", function()
            local fn = reiter:GetScript("OnClick")
            if fn then
                fn(reiter)
            end
        end)
        b:SetScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(name, 1, 0.82, 0)
                if self.zahl:GetText() and self.zahl:GetText() ~= "" then
                    GameTooltip:AddLine(self.zahl:GetText() .. (self.wert == "plan" and " vorgemerkt" or " offen für dich"), 1, 1, 1)
                end
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function()
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)
        b:Hide()
        f.seiten[i] = b
    end
    return r
end

function O.FensterLook(f)
    O.Teil(function(spiel)
        local an = spiel and O.HatAtlas("UI-Frame-PortraitMetal-CornerTopLeft")
        if an and not f.spielRahmen then
            f.spielRahmen = O.RahmenBauen(f)
        end
        if f.spielRahmen then
            f.spielRahmen:SetShown(an and true or false)
            f.portrait:SetShown(an and true or false)
        end
        if f.SetBackdrop then
            f:SetBackdrop(not an and K.BACKDROP_RAHMEN or nil)
        end
        f.deckel:ClearAllPoints()
        if an and O.Atlas(f.deckel, "Profession-Background-Template2") then
            f.deckel:SetPoint("TOPLEFT", 2, -2)
            f.deckel:SetPoint("BOTTOMRIGHT", -2, 2)
            f.deckel:SetVertexColor(1, 1, 1, 1)
        else
            f.deckel:SetColorTexture(0.06, 0.06, 0.07, 0.96)
            f.deckel:SetPoint("TOPLEFT", 6, -6)
            f.deckel:SetPoint("BOTTOMRIGHT", -6, 6)
        end
        for _, t in ipairs({ f.titelIcon, f.titel, f.version, f.reiterWerk, f.reiterPlan, f.reiterBest, f.reiterKat }) do
            t:SetShown(not an)
        end
        f.zu:ClearAllPoints()
        if an then
            f.zu:SetPoint("TOPRIGHT", 1, 0)
            f.zu:SetFrameLevel((f:GetFrameLevel() or 1) + 45)
            f.zahnrad:SetFrameLevel((f:GetFrameLevel() or 1) + 45)
        else
            f.zu:SetPoint("TOPRIGHT", -4, -4)
        end
        f:SetHeight(an and 698 or 680)
        O.Lage(f, an and 18 or 0)
        if not an and f.seiten then
            for _, b in ipairs(f.seiten) do
                b:Hide()
            end
        end
        if not an then
            O.KarteHg(f.rechts, nil)
            O.KarteHg(f.kat and f.kat.rechts, nil)
        end
    end)
end

-- "/gerp optik" (ab 1.1.5): liest NUR, wie das offene Berufefenster gebaut ist (Grafiken, Schriften),
-- damit Guild ERP spaeter optional genauso aussehen kann. Nichts wird angeklickt oder veraendert.
function O.OptikLesen()
    local wurzel
    for _, n in ipairs({ "ProfessionsFrame", "TradeSkillFrame", "ClassicProfessionsFrame", "CraftFrame" }) do
        local fr = _G[n]
        if fr and fr.IsShown and fr:IsShown() then
            wurzel = fr
            break
        end
    end
    if not wurzel then
        local fokus = GetMouseFoci and GetMouseFoci()
        fokus = type(fokus) == "table" and fokus[1] or (GetMouseFocus and GetMouseFocus())
        while fokus and fokus.GetParent and fokus:GetParent() and fokus:GetParent() ~= UIParent do
            fokus = fokus:GetParent()
        end
        wurzel = fokus ~= WorldFrame and fokus or nil
    end
    if not wurzel then
        Melden("Bitte zuerst das Berufefenster öffnen, dann /gerp optik eingeben.")
        return
    end
    local liste, n = {}, 0
    local function z(v)
        return v and math.floor(v + 0.5) or 0
    end
    local function lesen(fr, pfad, tiefe)
        if n >= 900 or tiefe > 8 then
            return
        end
        local regionen = { pcall(fr.GetRegions, fr) }
        for i = 2, #regionen do
            local r = regionen[i]
            if n < 900 and r and r.GetObjectType then
                local art = r:GetObjectType()
                local e = { p = pfad, a = art, s = r:IsShown() and 1 or 0, w = z(r:GetWidth()), h = z(r:GetHeight()), n = r.GetDebugName and r:GetDebugName() or nil }
                if art == "Texture" then
                    e.atlas = r.GetAtlas and r:GetAtlas() or nil
                    e.tex = r.GetTexture and r:GetTexture() or nil
                    if r.GetTexCoord then
                        local ok, a1, a2, a3, a4, a5, a6, a7, a8 = pcall(r.GetTexCoord, r)
                        if ok and a1 then
                            e.tc = string.format("%.3f,%.3f,%.3f,%.3f", a1, a7 or a3, a2, a8 or a4)
                        end
                    end
                    e.lay = r.GetDrawLayer and r:GetDrawLayer() or nil
                    local ok, cr, cg, cb, ca = pcall(r.GetVertexColor, r)
                    if ok and cr then
                        e.col = string.format("%.2f,%.2f,%.2f,%.2f", cr, cg, cb, ca or 1)
                    end
                elseif art == "FontString" then
                    e.text = B.Kurz(r:GetText() or "", 40)
                    e.font = r.GetFontObject and r:GetFontObject() and r:GetFontObject().GetName and r:GetFontObject():GetName() or nil
                    local ok, datei, groesse = pcall(r.GetFont, r)
                    if ok then
                        e.datei, e.gr = datei, groesse
                    end
                    local ok2, cr, cg, cb = pcall(r.GetTextColor, r)
                    if ok2 and cr then
                        e.col = string.format("%.2f,%.2f,%.2f", cr, cg, cb)
                    end
                end
                n = n + 1
                liste[n] = e
            end
        end
        local kinder = { pcall(fr.GetChildren, fr) }
        for i = 2, #kinder do
            local k = kinder[i]
            if k and k.IsShown and k:IsShown() then
                local name = (k.GetDebugName and k:GetDebugName()) or (k.GetName and k:GetName()) or ("#" .. (i - 1))
                lesen(k, pfad .. ">" .. B.Kurz(tostring(name), 60), tiefe + 1)
            end
        end
    end
    lesen(wurzel, (wurzel.GetName and wurzel:GetName()) or "Fenster", 0)
    local d = Daten()
    d.diagnostics.optik = { at = date("%Y-%m-%d %H:%M"), fenster = (wurzel.GetName and wurzel:GetName()) or "?", teile = liste }
    Melden("Berufefenster gelesen (" .. n .. " Teile). Jetzt /reload eingeben, dann kann Claude es auswerten.")
end

-- Wird der Gegenstand beim Aufheben/Herstellen seelengebunden? (Bindung 1; unbekannt = nein, bis das Spiel es liefert)
function Kat.Seelengebunden(itemID)
    if not itemID or itemID <= 0 then
        return false
    end
    local e = GuildERPData.items[itemID]
    if e and e.bind ~= nil then
        return e.bind == 1
    end
    local bind
    local holen = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if holen then
        local ok, r1, _, _, _, _, _, _, _, _, _, _, _, _, b = pcall(holen, itemID)
        if ok and r1 then
            bind = b
        end
    end
    if type(bind) == "number" then
        GuildERPData.items[itemID] = GuildERPData.items[itemID] or {}
        GuildERPData.items[itemID].bind = bind
        return bind == 1
    end
    return false
end

-- ab 1.1.8: Hauptberufe (Skill-Linien), die ein Charakter wirklich gelernt haben muss
Kat.HAUPT = { [164] = true, [165] = true, [171] = true, [197] = true, [202] = true, [333] = true,
    [755] = true, [773] = true, [186] = true, [182] = true, [393] = true }
-- Name -> englischer Schluessel (fuer Hauptberuf-Erkennung und die Berufs-Karte im Spiel-Look)
Kat.BERUF_NAME = {
    Schmiedekunst = "Blacksmithing", Lederverarbeitung = "Leatherworking", Alchemie = "Alchemy", Schneiderei = "Tailoring",
    Ingenieurskunst = "Engineering", Verzauberkunst = "Enchanting", Juwelierskunst = "Jewelcrafting", Juwelenschleifen = "Jewelcrafting",
    Inschriftenkunde = "Inscription", Bergbau = "Mining", ["Kräuterkunde"] = "Herbalism", ["Kürschnerei"] = "Skinning",
    Kochkunst = "Cooking", Angeln = "Fishing", ["Erste Hilfe"] = "FirstAid",
    Blacksmithing = "Blacksmithing", Leatherworking = "Leatherworking", Alchemy = "Alchemy", Tailoring = "Tailoring",
    Engineering = "Engineering", Enchanting = "Enchanting", Jewelcrafting = "Jewelcrafting", Inscription = "Inscription",
    Mining = "Mining", Herbalism = "Herbalism", Skinning = "Skinning", Cooking = "Cooking", Fishing = "Fishing", ["First Aid"] = "FirstAid",
}
Kat.HAUPT_NAME = { Blacksmithing = true, Leatherworking = true, Alchemy = true, Tailoring = true, Engineering = true,
    Enchanting = true, Jewelcrafting = true, Inscription = true, Mining = true, Herbalism = true, Skinning = true }

function Kat.IstHaupt(name, id, eltern)
    return (Kat.HAUPT[id] or Kat.HAUPT[eltern] or Kat.HAUPT_NAME[Kat.BERUF_NAME[name or ""] or ""]) and true or false
end

-- Ist das offene Berufefenster gar nicht das eigene? (verlinkt, Gilde, NPC)
function Kat.FremdesFenster()
    if not C_TradeSkillUI then
        return false
    end
    for _, fn in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsTradeSkillGuildMember", "IsNPCCrafting" }) do
        if C_TradeSkillUI[fn] then
            local ok, ja = pcall(C_TradeSkillUI[fn])
            if ok and ja then
                return true
            end
        end
    end
    return false
end

-- Berufe des gerade gespielten Charakters laut Spiel (Namen und Skill-Linien), nil wenn unbekannt
function Kat.MeineBerufe()
    if not (GetProfessions and GetProfessionInfo) then
        return nil
    end
    local ok, a, b, c, d2, e = pcall(GetProfessions)
    if not ok then
        return nil
    end
    local m = { namen = {}, linien = {}, n = 0 }
    for _, idx in pairs({ a, b, c, d2, e }) do
        local ok2, name, _, _, _, _, _, linie = pcall(GetProfessionInfo, idx)
        if ok2 and name then
            m.namen[name] = true
            if linie then
                m.linien[linie] = true
            end
            m.n = m.n + 1
        end
    end
    return m
end

-- Beim Einloggen: Hauptberufe entfernen, die der Charakter gar nicht hat
-- (z. B. aus einem verlinkten Berufefenster eines anderen Spielers vor 1.1.8)
function Kat.Aufraeumen()
    local c = Charakter()
    local meine = Kat.MeineBerufe()
    if not (c and c.recipes and meine and meine.n > 0) then
        return
    end
    local d = Daten()
    for beruf, ids in pairs(c.recipes) do
        if type(ids) == "table" and not meine.namen[beruf] then
            local pid
            for rid in pairs(ids) do
                pid = d.recipes[rid] and d.recipes[rid].professionID
                if pid then
                    break
                end
            end
            if Kat.IstHaupt(beruf, pid) and not (pid and meine.linien[pid]) then
                c.recipes[beruf] = nil
                d.diagnostics.aufgeraeumt = beruf .. " bei " .. (c.name or "?") .. " " .. date("%Y-%m-%d %H:%M")
                Melden(beruf .. " bei " .. (c.name or "?") .. " entfernt – den Beruf hat dieser Charakter nicht gelernt.")
            end
        end
    end
end

-- Gruppe des Spiels (wie im Berufefenster, z. B. "Waffensteine") aus den Rezept-Infos (ab 1.1.4)
function Kat.SpielKategorie(info)
    local cid = type(info) == "table" and info.categoryID
    if not (cid and C_TradeSkillUI and C_TradeSkillUI.GetCategoryInfo) then
        return nil
    end
    local ok, k = pcall(C_TradeSkillUI.GetCategoryInfo, cid)
    if ok and type(k) == "table" and type(k.name) == "string" and k.name ~= "" then
        return B.Kurz(k.name, 40)
    end
    return nil
end

-- Ersatzweg fuer das klassische Berufefenster: Ueberschriften der Liste lesen (nur lesen, nichts anklicken)
function Kat.AlteKategorien(bekannt)
    if not (GetNumTradeSkills and GetTradeSkillInfo) then
        return
    end
    local d = Daten()
    local nachName = {}
    for rid in pairs(bekannt) do
        local r = d.recipes[rid]
        if r and r.name and not r.kategorie then
            nachName[r.name] = r
        end
    end
    if next(nachName) == nil then
        return
    end
    local ok, n = pcall(GetNumTradeSkills)
    local kopf
    for i = 1, (ok and tonumber(n) or 0) do
        local ok2, name, art = pcall(GetTradeSkillInfo, i)
        if ok2 and name then
            if art == "header" or art == "subheader" then
                kopf = B.Kurz(name, 40)
            elseif kopf and nachName[name] then
                nachName[name].kategorie = kopf
            end
        end
    end
end

-- Gruppe eines Rezepts: zuerst die Gruppe des Spiels (ab 1.1.4, eigene oder vom Abgleich),
-- sonst "Armschiene - Geringe Ausdauer" -> "Armschiene", sonst Art des Gegenstands
function Kat.Gruppe(rid, itemID, name)
    if rid then
        local d = Daten()
        local r = d.recipes[rid]
        local k = (r and r.kategorie) or (d.katGruppe and d.katGruppe[rid])
        if k and k ~= "" then
            return k
        end
    end
    local vorne = name and string.match(name, "^(.-)%s+%-%s+.+$")
    if vorne and vorne ~= "" then
        return vorne
    end
    if itemID and itemID > 0 then
        local art
        if C_Item and C_Item.GetItemInfoInstant then
            local ok, _, typ, unter = pcall(C_Item.GetItemInfoInstant, itemID)
            art = ok and (unter or typ) or nil
        elseif GetItemInfoInstant then
            local ok, _, typ, unter = pcall(GetItemInfoInstant, itemID)
            art = ok and (unter or typ) or nil
        end
        if art and art ~= "" then
            return art
        end
    end
    return "Sonstiges"
end

function Kat.KopfBauen(eltern)
    local k = O.Rahmen("Button", nil, eltern)
    k:SetHeight(30)
    local hl = k:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.04)
    k.linie = k:CreateTexture(nil, "ARTWORK")
    k.linie:SetHeight(1)
    k.linie:SetPoint("BOTTOMLEFT")
    k.linie:SetPoint("BOTTOMRIGHT")
    k.linie:SetColorTexture(K.GOLD_DUNKEL[1], K.GOLD_DUNKEL[2], K.GOLD_DUNKEL[3], 0.8)
    k.pfeil = k:CreateTexture(nil, "ARTWORK")
    k.pfeil:SetSize(12, 12)
    k.pfeil:SetPoint("LEFT", 6, 0)
    k.zahl = Schrift(k, "GameFontHighlightSmall", false)
    k.zahl:SetPoint("RIGHT", -8, 0)
    k.zahl:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    k.text = Schrift(k, "GameFontNormal")
    k.text:SetPoint("LEFT", k.pfeil, "RIGHT", 8, 0)
    k.text:SetPoint("RIGHT", k.zahl, "LEFT", -8, 0)
    k.rechtsText, k.pfeilGr = k.zahl, 12
    k.anker = function()
        k.pfeil:ClearAllPoints()
        k.pfeil:SetPoint("LEFT", 6, 0)
        k.zahl:ClearAllPoints()
        k.zahl:SetPoint("RIGHT", -8, 0)
        k.text:ClearAllPoints()
        k.text:SetPoint("LEFT", k.pfeil, "RIGHT", 8, 0)
        k.text:SetPoint("RIGHT", k.zahl, "LEFT", -8, 0)
    end
    O.Teil(function(spiel) O.KopfLook(k, spiel) end)
    return k
end

function Kat.AnsichtZeigen(f)
    local a = f.kat
    local L, R = a.links, a.rechts
    local s = Daten().settings
    local alle = Kat.Sammeln()
    -- ausblenden (ab 1.1.1): was der gerade gespielte Charakter selbst kann,
    -- und Gegenstaende, die beim Herstellen seelengebunden werden (kann man nicht weitergeben)
    local ich = Charakter()
    local selbst = {}
    for _, ids in pairs(ich and ich.recipes or {}) do
        if type(ids) == "table" then
            for rid in pairs(ids) do
                selbst[rid] = true
            end
        end
    end
    for b, ids in pairs(alle) do
        for rid, e in pairs(ids) do
            if selbst[rid] or Kat.Seelengebunden(e.itemID) then
                ids[rid] = nil
            end
        end
        if next(ids) == nil then
            alle[b] = nil
        end
    end
    local berufe = {}
    for beruf, ids in pairs(alle) do
        local wer, n = {}, 0
        for _, e in pairs(ids) do
            n = n + 1
            for _, w in ipairs(e.wer) do
                wer[w] = true
            end
        end
        local liste = {}
        for w in pairs(wer) do
            table.insert(liste, w)
        end
        table.sort(liste)
        berufe[beruf] = liste
        berufe[beruf].n = n
    end
    if not s.katBeruf or not alle[s.katBeruf] then
        -- zuerst einen Beruf zeigen, den jemand anderes kann (das ist das Neue im Katalog)
        s.katBeruf = nil
        local fremd = {}
        for _, e in pairs(Kat.Daten().fremd) do
            for b in pairs(e.berufe or {}) do
                fremd[b] = true
            end
        end
        for b in pairs(alle) do
            local besser = not s.katBeruf or (fremd[b] and not fremd[s.katBeruf]) or (fremd[b] == fremd[s.katBeruf] and b < s.katBeruf)
            if besser then
                s.katBeruf = b
            end
        end
    end
    local beruf = s.katBeruf
    L.beruf.text:SetText(beruf or "Noch keine Rezepte")
    L.beruf.rechts:SetText(beruf and (#berufe[beruf] .. (#berufe[beruf] == 1 and " kann es, " or " können es, ")
        .. berufe[beruf].n .. " Rezepte") or "")
    L.beruf:SetScript("OnClick", function(self)
        local liste = {}
        local namen = {}
        for b in pairs(berufe) do
            table.insert(namen, b)
        end
        table.sort(namen)
        for _, b in ipairs(namen) do
            local anz = {}
            for _, w in ipairs(berufe[b]) do
                table.insert(anz, B.Anzeige(w))
            end
            table.insert(liste, { wert = b, text = b, rechts = table.concat(anz, ", "), gewaehlt = b == beruf })
        end
        PopupZeigen(self, 400, liste, function(wert)
            Daten().settings.katBeruf = wert
            Daten().settings.katRezept = nil
            L.suche:SetText("")
        end, "Berufe, die du oder jemand aus deiner Gruppe kann.")
    end)
    L.suche.platzhalter:SetText(beruf and ("In " .. beruf .. " suchen") or "Suchen")
    -- Liste
    for _, z in ipairs(L.zeilen) do
        z:Hide()
        z.benutzt = false
    end
    local suche = string.lower(L.suche:GetText() or "")
    local reihe = {}
    for rid, e in pairs(beruf and alle[beruf] or {}) do
        local name = Kat.Name(rid, e.itemID) or ("Rezept " .. rid)
        if suche == "" or string.find(string.lower(name), suche, 1, true) then
            table.insert(reihe, { rid = rid, e = e, name = name })
        end
    end
    table.sort(reihe, function(x, y) return x.name < y.name end)
    local gewaehlt = s.katRezept
    -- Gruppen (ab 1.1): Verzauberungen nach Namensanfang, sonst nach Art des Gegenstands
    local gruppen, gNamen = {}, {}
    for _, r in ipairs(reihe) do
        local g = Kat.Gruppe(r.rid, r.e.itemID, r.name)
        if not gruppen[g] then
            gruppen[g] = {}
            table.insert(gNamen, g)
        end
        table.insert(gruppen[g], r)
        r.anzeige = (string.match(r.name, "^.-%s+%-%s+(.+)$") and g ~= "Sonstiges") and r.name or r.name
    end
    table.sort(gNamen, function(x, y)
        if x == "Sonstiges" or y == "Sonstiges" then
            return y == "Sonstiges" and x ~= "Sonstiges"
        end
        return x < y
    end)
    for _, k in ipairs(L.koepfe or {}) do
        k:Hide()
        k.benutzt = false
    end
    L.koepfe = L.koepfe or {}
    local y = 0
    local zeigen = {}
    for _, g in ipairs(gNamen) do
        local schluessel = (beruf or "") .. ">" .. g
        local enthaelt = false
        for _, r in ipairs(gruppen[g]) do
            enthaelt = enthaelt or r.rid == gewaehlt
        end
        local offen = Kat.auf[schluessel]
        if offen == nil then
            offen = suche ~= "" or enthaelt or #gNamen == 1
        end
        local k = Frei(L.koepfe, L.inhalt, Kat.KopfBauen)
        k:ClearAllPoints()
        k:SetPoint("TOPLEFT", 0, -y)
        k:SetPoint("RIGHT", L.inhalt, "RIGHT", 0, 0)
        k.text:SetText(g)
        k.zahl:SetText(#gruppen[g])
        O.KopfIcon(k, offen)
        k:SetScript("OnClick", function()
            Kat.auf[schluessel] = not offen
            FensterAktualisieren()
        end)
        k:Show()
        y = y + 30
        if offen then
            for _, r in ipairs(gruppen[g]) do
                table.insert(zeigen, { r = r, y = y })
                y = y + 32
            end
        end
    end
    for _, eintrag in ipairs(zeigen) do
        local r = eintrag.r
        local z = Frei(L.zeilen, L.inhalt, Kat.ZeileBauen)
        z:ClearAllPoints()
        z:SetPoint("TOPLEFT", 18, -eintrag.y)
        z:SetPoint("RIGHT", L.inhalt, "RIGHT", 0, 0)
        local akt = r.rid == gewaehlt
        O.Gewaehlt(z, akt)
        z.icon:SetTexture(Kat.Icon(r.rid, r.e.itemID))
        z.name:SetText(akt and Farbe("f3d98a", r.name) or r.name)
        table.sort(r.e.wer)
        local anz = {}
        for _, w in ipairs(r.e.wer) do
            table.insert(anz, B.Anzeige(w))
        end
        z.wer:SetText(table.concat(anz, ", "))
        z.rid, z.itemID, z.werText = r.rid, r.e.itemID, table.concat(anz, ", ")
        local rid = r.rid
        z:SetScript("OnClick", function()
            Daten().settings.katRezept = rid
            FensterAktualisieren()
        end)
        z:Show()
    end
    L.inhalt:SetHeight(math.max(10, y))
    L.leer:SetShown(#reihe == 0)
    L.leer:SetText(beruf and "Nichts gefunden." or ("Hier stehen Rezepte, die dein jetziger Charakter nicht selbst kann. "
        .. "Seelengebundene Sachen fehlen, weil man sie nicht weitergeben kann. "
        .. "Rezepte von anderen erscheinen, sobald ihr zusammen in einer Gruppe seid und sie Guild ERP ab Version 0.9 haben."))
    local d = Kat.Daten()
    local zuletzt
    for _, e in pairs(d.fremd) do
        if not zuletzt or (e.at or 0) > zuletzt then
            zuletzt = e.at
        end
    end
    L.fuss:SetText(zuletzt and ("Stand der anderen: zuletzt abgeglichen " .. P.Zeit(zuletzt) .. ".")
        or "Rezepte der anderen kommen, sobald ihr zusammen in einer Gruppe seid.")
    -- rechts
    local e = beruf and alle[beruf] and gewaehlt and alle[beruf][gewaehlt]
    R.karte:SetShown(e and true or false)
    R.wer:SetShown(e and true or false)
    R.zTitel:SetShown(e and true or false)
    R.zutaten:SetShown(e and true or false)
    R.baumScroll:SetShown(e and true or false)
    R.leer:SetShown(not e)
    R.form:SetShown(e and true or false)
    R.leer:SetText("Wähle links ein Rezept. Du siehst dann, wer es kann und was es braucht.")
    if not e then
        return
    end
    R.karte.icon:SetTexture(Kat.Icon(gewaehlt, e.itemID))
    R.karte.rid, R.karte.itemID, R.karte.werText = gewaehlt, e.itemID, table.concat(e.wer, ", ")
    local q = e.itemID and e.itemID > 0 and ItemQualitaet(e.itemID)
    R.karte.name:SetText(Farbe(q and K.QUALITAET_HEX[q] or "f3d98a", Kat.Name(gewaehlt, e.itemID) or ("Rezept " .. gewaehlt)))
    R.karte.unter:SetText(beruf .. ((not e.itemID or e.itemID == 0) and " · Verzauberung, wird beim Handeln aufgetragen" or ""))
    local wer = {}
    for _, w in ipairs(e.wer) do
        local f2 = d.fremd[w]
        table.insert(wer, Farbe(K.STATUS_HEX.blau, B.Anzeige(w)) .. (f2 and Farbe("8a8578", " (Stand " .. P.Zeit(f2.at) .. ")") or Farbe("8a8578", " (dein Charakter)")))
    end
    R.wer:SetText("Kann es: " .. table.concat(wer, ", "))
    -- Zutaten: eigene Daten oder beim Spiel nachfragen
    local r = d.recipes[gewaehlt]
    local zutaten = r and r.reagents
    if not zutaten then
        Kat.zutatenCache = Kat.zutatenCache or {}
        if Kat.zutatenCache[gewaehlt] == nil then
            local ok, liste = pcall(Zutaten, gewaehlt)
            Kat.zutatenCache[gewaehlt] = ok and liste or false
        end
        zutaten = Kat.zutatenCache[gewaehlt] or nil
    end
    local menge = (Kat.form and Kat.form.rid == gewaehlt and Kat.form.menge) or 1
    if zutaten and #zutaten > 0 then
        R.zutaten:SetText("")
        R.zTitel:SetText("Zutaten für " .. menge .. "×")
        Kat.BaumZeigen(R, gewaehlt, zutaten, menge, alle)
    else
        R.zTitel:SetText("Zutaten")
        R.zutaten:SetText(Farbe("8a8578", "Die Zutaten zeigt das Spiel hier noch nicht an."))
        Kat.BaumZeigen(R, gewaehlt, {}, menge, alle)
    end
    Kat.FormZeigen(R.form, gewaehlt, e, zutaten)
end

-- Zutaten eines Rezepts (eigene Daten oder beim Spiel nachfragen)
function Kat.Zutaten(rid)
    local r = GuildERPData.recipes[rid]
    if r and r.reagents then
        return r.reagents, r.numMade or 1
    end
    Kat.zutatenCache = Kat.zutatenCache or {}
    if Kat.zutatenCache[rid] == nil then
        local ok, liste = pcall(Zutaten, rid)
        Kat.zutatenCache[rid] = ok and liste or false
    end
    return Kat.zutatenCache[rid] or nil, 1
end

function Kat.BaumZeileBauen(eltern)
    local z = O.Rahmen("Button", nil, eltern)
    z.hg = z:CreateTexture(nil, "BACKGROUND")
    z.hg:SetAllPoints()
    z.linie = z:CreateTexture(nil, "ARTWORK")
    z.linie:SetHeight(1)
    z.linie:SetPoint("BOTTOMLEFT")
    z.linie:SetPoint("BOTTOMRIGHT")
    z.linie:SetColorTexture(1, 1, 1, 0.05)
    z.knopf = z:CreateTexture(nil, "ARTWORK")
    z.knopf:SetSize(12, 12)
    z.leit = z:CreateTexture(nil, "ARTWORK")
    z.leit:SetWidth(1)
    z.leit:SetColorTexture(K.GOLD_DUNKEL[1], K.GOLD_DUNKEL[2], K.GOLD_DUNKEL[3], 1)
    z.punkt = Raute(z, 8)
    z.zahl = Schrift(z, "GameFontHighlight", false)
    z.zahl:SetPoint("TOPRIGHT", -4, -6)
    z.name = Schrift(z, "GameFontHighlight")
    z.info = Schrift(z, "GameFontHighlightSmall")
    z.info:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
    z:SetScript("OnClick", function(self)
        if self.schluessel then
            Kat.baumZu[self.schluessel] = not Kat.baumZu[self.schluessel]
            FensterAktualisieren()
        end
    end)
    z:SetScript("OnEnter", function(self)
        if GameTooltip and self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. self.itemID)
            GameTooltip:Show()
        end
    end)
    z:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    return z
end

-- Zutaten als Baum: Bestand, wer es herstellen kann (eigene oder Gruppe), Unter-Zutaten, AH-Preis
function Kat.BaumZeigen(R, rid, zutaten, menge, alle)
    for _, z in ipairs(R.baumZeilen) do
        z:Hide()
        z.benutzt = false
    end
    -- wer stellt welchen Gegenstand her?
    local hersteller = {}
    for _, ids in pairs(alle) do
        for r2, e2 in pairs(ids) do
            if e2.itemID and e2.itemID > 0 then
                local h = hersteller[e2.itemID]
                if not h then
                    h = { rid = r2, wer = {} }
                    hersteller[e2.itemID] = h
                end
                for _, w in ipairs(e2.wer) do
                    h.wer[w] = true
                end
            end
        end
    end
    local pool = BestandSammeln(SpielerFraktion())
    local y = 0
    local function zweig(itemID, noetig, tiefe, pfad, besucht)
        local hab, orte = 0, {}
        for _, q in ipairs(pool[itemID] or {}) do
            hab = hab + q.n
            if #orte < 2 then
                table.insert(orte, q.wer .. ", " .. q.wo .. ": " .. q.n)
            end
        end
        local h = hersteller[itemID]
        local st = hab >= noetig and "gruen" or (h and "gelb" or "rot")
        local z = Frei(R.baumZeilen, R.baumInhalt, Kat.BaumZeileBauen)
        z:ClearAllPoints()
        z:SetPoint("TOPLEFT", 0, -y)
        z:SetPoint("RIGHT", R.baumInhalt, "RIGHT", 0, 0)
        local x = 20 + (tiefe - 1) * 22
        local schluessel = (st == "gelb" and tiefe < 4 and not besucht[itemID]) and (pfad .. ">" .. itemID) or nil
        local zu = schluessel and Kat.baumZu[schluessel]
        z.schluessel, z.itemID = schluessel, itemID
        z.hg:SetColorTexture(1, 1, 1, tiefe > 1 and 0.025 or 0)
        z.knopf:ClearAllPoints()
        z.knopf:SetPoint("TOPLEFT", x - 16, -8)
        z.knopf:SetTexture(zu and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        z.knopf:SetShown(schluessel ~= nil)
        z.leit:ClearAllPoints()
        z.leit:SetPoint("TOPLEFT", x - 28, 0)
        z.leit:SetPoint("BOTTOMLEFT", x - 28, 0)
        z.leit:SetShown(tiefe > 1)
        z.punkt:ClearAllPoints()
        z.punkt:SetPoint("TOPLEFT", x, -9)
        Faerben(z.punkt, st)
        z.zahl:SetText(Farbe(K.STATUS_HEX[st], math.min(hab, 99999)) .. Farbe("77715f", " / " .. noetig))
        z.name:ClearAllPoints()
        z.name:SetPoint("TOPLEFT", x + 16, -5)
        z.name:SetPoint("RIGHT", z.zahl, "LEFT", -8, 0)
        z.name:SetText(ItemName(itemID) or Farbe("9a9384", "Name wird geladen …"))
        local zeilen = { #orte > 0 and table.concat(orte, "  ·  ") or "Du hast keine." }
        if st == "gelb" then
            local namen = {}
            for w in pairs(h.wer) do
                table.insert(namen, B.Anzeige(w))
            end
            table.sort(namen)
            table.insert(zeilen, Farbe(K.STATUS_HEX.gelb, "Kann herstellen: " .. table.concat(namen, ", ")))
        end
        local ah = A.Text(itemID, true)
        if ah then
            table.insert(zeilen, ah)
        end
        z.info:ClearAllPoints()
        z.info:SetPoint("TOPLEFT", z.name, "BOTTOMLEFT", 0, -2)
        z.info:SetPoint("RIGHT", z, "RIGHT", -60, 0)
        z.info:SetText(table.concat(zeilen, "\n"))
        local hoehe = 5 + (z.name:GetStringHeight() or 14) + 2 + (z.info:GetStringHeight() or 12) + 6
        z:SetHeight(hoehe)
        z:Show()
        y = y + hoehe
        if schluessel and not zu then
            local unter, je = Kat.Zutaten(h.rid)
            if unter then
                besucht[itemID] = true
                local laeufe = math.ceil((noetig - hab) / (je or 1))
                for _, u in ipairs(unter) do
                    zweig(u.itemID, (u.count or 1) * laeufe, tiefe + 1, schluessel, besucht)
                end
                besucht[itemID] = nil
            end
        end
    end
    for _, zt in ipairs(zutaten) do
        zweig(zt.itemID, (zt.count or 1) * menge, 1, tostring(rid), {})
    end
    R.baumInhalt:SetHeight(math.max(10, y))
end

-- Bestellfeld im Katalog
function Kat.FormZeigen(F, rid, e, zutaten)
    local eigene = B.EigeneNamen()
    local fremdWer = {}
    for _, w in ipairs(e.wer) do
        if not eigene[w] then
            table.insert(fremdWer, w)
        end
    end
    table.sort(fremdWer)
    local f = Kat.form
    if not f or f.rid ~= rid then
        f = { rid = rid, menge = 1, an = fremdWer[1] or "", mats = "b" }
        Kat.form = f
        F.notiz:SetText("")
    end
    local einzeln = #fremdWer > 0
    F.menge:SetText(f.menge)
    F.minus:SetScript("OnClick", function() f.menge = math.max(1, f.menge - 1); FensterAktualisieren() end)
    F.plus:SetScript("OnClick", function() f.menge = math.min(K.MENGE_MAX, f.menge + 1); FensterAktualisieren() end)
    F.an.text:SetText(f.an == "" and "Alle, die es können" or B.Anzeige(f.an))
    F.an:SetScript("OnClick", function(self)
        local liste = {}
        for _, w in ipairs(fremdWer) do
            table.insert(liste, { wert = w, text = B.Anzeige(w), rechts = "kennt das Rezept", gewaehlt = w == f.an })
        end
        table.insert(liste, { wert = "", text = "Alle, die es können", rechts = "wer zuerst zusagt", gewaehlt = f.an == "" })
        PopupZeigen(self, 260, liste, function(wert) f.an = wert end)
    end)
    local matsText = { b = "Ich bringe die Zutaten mit", h = "Hersteller besorgt sie" }
    F.mats.text:SetText(matsText[f.mats])
    F.mats:SetScript("OnClick", function(self)
        PopupZeigen(self, 260, {
            { wert = "b", text = matsText.b, gewaehlt = f.mats == "b" },
            { wert = "h", text = matsText.h, gewaehlt = f.mats == "h" },
        }, function(wert) f.mats = wert end)
    end)
    -- Hinweis: was mir an Zutaten noch fehlt
    local text
    if not einzeln then
        text = "Das kann nur dein eigener Charakter. Herstellen geht über die Werkstatt."
    elseif f.mats == "h" then
        text = (f.an == "" and "Der Hersteller" or B.Anzeige(f.an)) .. " besorgt die Zutaten."
    elseif zutaten and #zutaten > 0 then
        local pool = BestandSammeln(SpielerFraktion())
        local fehlt = {}
        for _, z in ipairs(zutaten) do
            local hab = 0
            for _, q in ipairs(pool[z.itemID] or {}) do
                hab = hab + q.n
            end
            local n = z.count * f.menge - hab
            if n > 0 then
                table.insert(fehlt, { itemID = z.itemID, n = n })
            end
        end
        if #fehlt == 0 then
            text = Farbe(K.STATUS_HEX.gruen, "Alle Zutaten hast du.")
        else
            local teile = {}
            for _, x in ipairs(fehlt) do
                table.insert(teile, x.n .. " " .. (ItemName(x.itemID) or "?"))
            end
            local kosten = A.KostenText(fehlt)
            text = "Dir fehlt noch: " .. table.concat(teile, ", ") .. (kosten and (" (AH " .. kosten .. ")") or "") .. "."
        end
    else
        text = ""
    end
    F.hinweis:SetText(text)
    if F.knopf.SetEnabled then
        F.knopf:SetEnabled(einzeln)
    end
    F.knopf:SetScript("OnClick", function()
        if not einzeln then
            return
        end
        B.Anlegen({ { itemID = e.itemID or 0, rezeptID = rid, n = f.menge } }, f.an,
            Kat.Name(rid, e.itemID) or "", F.notiz:GetText() or "", nil, f.mats)
        Kat.form = nil
        Daten().settings.ansicht = "best"
        FensterAktualisieren()
    end)
end


-- ---------------------------------------------------------------------------
-- Stornieren (Version 1.0): "Was haengt daran?"
-- Guild ERP storniert nie etwas bei anderen. Es nimmt nur EIGENE Zusagen zurueck und zieht
-- EIGENE Bestellungen zurueck; die anderen bekommen Bescheid und entscheiden selbst.
-- ---------------------------------------------------------------------------
function P.Folgen(art, obj)
    local punkte, infos = {}, {}
    local eigene = B.EigeneNamen()
    local function geliefertInfo(o, wer, n, name, an)
        table.insert(infos, "Schon geliefert: " .. n .. "× " .. name .. (an and (" an " .. B.Anzeige(an)) or (" von " .. B.Anzeige(wer)))
            .. ". Bleibt als geliefert stehen. Zurückgeben klärt ihr selbst, z. B. per Handel.")
    end
    local function bestellungPunkte(o, pflicht)
        local zusagende, teile = {}, {}
        for _, z in ipairs(o.zeilen) do
            table.insert(teile, z.n .. "× " .. B.ZName(z))
            for wer, sz in pairs(z.zusagen or {}) do
                if (sz.n or 0) > 0 then
                    if sz.g then
                        geliefertInfo(o, wer, sz.n, B.ZName(z))
                    else
                        zusagende[B.Anzeige(wer)] = true
                    end
                end
            end
        end
        local namen = {}
        for n in pairs(zusagende) do
            table.insert(namen, n)
        end
        table.sort(namen)
        table.insert(punkte, {
            text = (pflicht and "Bestellung stornieren (" or "Deine Bestellung dazu zurückziehen (") .. table.concat(teile, ", ") .. ")",
            unter = #namen > 0 and (table.concat(namen, ", ") .. (#namen == 1 and " hat zugesagt und bekommt Bescheid." or " haben zugesagt und bekommen Bescheid.")
                .. " Hängt dort ein Planauftrag daran, entscheidet jeder selbst, ob er ihn behält.") or "Noch hat niemand zugesagt.",
            an = true, pflicht = pflicht,
            tun = function() B.Status(o, "zurueckgezogen") end,
        })
    end
    if art == "plan" then
        local plan = obj
        for oid in pairs(plan.fuer or {}) do
            local o = B.Liste()[oid]
            if o and o.status == "offen" then
                for _, z in ipairs(o.zeilen) do
                    local m = B.MeineZusage(z)
                    if z.rezeptID == plan.rezeptID and m and (m.n or 0) > 0 then
                        if m.g then
                            geliefertInfo(o, nil, m.n, B.ZName(z), o.von)
                        else
                            table.insert(punkte, {
                                text = "Deine Zusage an " .. B.Anzeige(o.von) .. " zurücknehmen",
                                unter = B.Anzeige(o.von) .. " bekommt Bescheid. Die Bestellung ist dann wieder offen, jemand anderes kann zusagen.",
                                an = true,
                                tun = function() B.Zusagen(o, B.ZKey(z), 0, m.weg, false, true) end,
                            })
                        end
                    end
                end
            end
        end
        for _, o in ipairs(P.Bestellungen(plan)) do
            bestellungPunkte(o, false)
        end
    else
        local o = obj
        bestellungPunkte(o, true)
        local plan
        for _, pl in pairs(P.Liste()) do
            if o.plan and pl.id == o.plan then
                plan = pl
            end
        end
        if plan then
            local r = GuildERPData.recipes[plan.rezeptID]
            table.insert(punkte, {
                text = "Planauftrag " .. (r and r.name or "?") .. " auch stornieren",
                unter = "Die Bestellung war dafür gedacht. Lass den Haken weg, wenn du ihn behalten willst.",
                an = false,
                tun = function() P.Liste()[plan.rezeptID] = nil end,
            })
        end
    end
    return punkte, infos
end

function P.StornoOeffnen(art, obj)
    local w = P.stornoFenster
    if not w then
        w = O.Rahmen("Frame", "GuildERPStorno", UIParent, K.BACKDROP_VORLAGE)
        w:SetWidth(560)
        w:SetPoint("CENTER", 0, 60)
        w:SetFrameStrata("DIALOG")
        w:SetToplevel(true)
        w:EnableMouse(true)
        w:SetClampedToScreen(true)
        if w.SetBackdrop then
            w:SetBackdrop(K.BACKDROP_RAHMEN)
        end
        table.insert(UISpecialFrames, "GuildERPStorno")
        w.titel = Schrift(w, "GameFontNormalLarge")
        w.titel:SetPoint("TOPLEFT", 20, -18)
        w.unter = Schrift(w, "GameFontHighlight")
        w.unter:SetPoint("TOPLEFT", w.titel, "BOTTOMLEFT", 0, -6)
        w.unter:SetPoint("RIGHT", -20, 0)
        w.unter:SetTextColor(0.72, 0.67, 0.55)
        w.frage = Schrift(w, "GameFontNormalSmall")
        w.frage:SetPoint("TOPLEFT", w.unter, "BOTTOMLEFT", 0, -12)
        w.frage:SetText("WAS HÄNGT DARAN?")
        w.punkte = {}
        w.infos = {}
        w.ab = O.Rahmen("Button", nil, w, "UIPanelButtonTemplate")
        w.ab:SetSize(100, 26)
        w.ab:SetText("Abbrechen")
        w.ab:SetScript("OnClick", function() w:Hide() end)
        w.ok = O.Rahmen("Button", nil, w, "UIPanelButtonTemplate")
        w.ok:SetSize(120, 26)
        w.ok:SetText("Stornieren")
        w.ok:SetPoint("BOTTOMRIGHT", -16, 14)
        w.ab:SetPoint("RIGHT", w.ok, "LEFT", -6, 0)
        P.stornoFenster = w
    end
    local punkte, infos = P.Folgen(art, obj)
    if art == "plan" then
        local r = GuildERPData.recipes[obj.rezeptID]
        local fuer = {}
        for _, fe in pairs(obj.fuer or {}) do
            table.insert(fuer, B.Anzeige(fe.von))
        end
        w.titel:SetText("Planauftrag stornieren?")
        w.unter:SetText((r and r.name or "?") .. ", " .. (obj.menge or 1) .. "×" .. (#fuer > 0 and (" · für " .. table.concat(fuer, ", ")) or ""))
    else
        w.titel:SetText("Bestellung stornieren?")
        w.unter:SetText((obj.an == "" and "An deine Gruppe" or ("An " .. B.Anzeige(obj.an))) .. ((obj.fuer or "") ~= "" and (" · für " .. obj.fuer) or ""))
    end
    for _, p in ipairs(w.punkte) do
        p:Hide()
    end
    for _, t in ipairs(w.infos) do
        t:Hide()
    end
    local y = 0
    local vorher = w.frage
    for i, pkt in ipairs(punkte) do
        local p = w.punkte[i]
        if not p then
            p = O.Rahmen("CheckButton", nil, w, "UICheckButtonTemplate")
            p:SetSize(24, 24)
            p.text = Schrift(w, "GameFontHighlight")
            p.unter = Schrift(w, "GameFontHighlightSmall")
            p.unter:SetTextColor(0.62, 0.60, 0.54)
            w.punkte[i] = p
        end
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", vorher, "BOTTOMLEFT", i == 1 and -2 or -28, -10)
        p.text:ClearAllPoints()
        p.text:SetPoint("TOPLEFT", p, "TOPRIGHT", 4, -4)
        p.text:SetPoint("RIGHT", w, "RIGHT", -20, 0)
        p.text:SetText(pkt.text)
        p.unter:ClearAllPoints()
        p.unter:SetPoint("TOPLEFT", p.text, "BOTTOMLEFT", 0, -2)
        p.unter:SetPoint("RIGHT", w, "RIGHT", -20, 0)
        p.unter:SetText(pkt.unter or "")
        p:SetChecked(pkt.an)
        if p.SetEnabled then
            p:SetEnabled(not pkt.pflicht)
        end
        p.pkt = pkt
        p:Show()
        p.text:Show()
        p.unter:Show()
        vorher = p.unter
        y = y + 14 + (p.text:GetStringHeight() or 14) + (p.unter:GetStringHeight() or 12)
    end
    for i = #punkte + 1, #w.punkte do
        w.punkte[i].text:Hide()
        w.punkte[i].unter:Hide()
    end
    for i, info in ipairs(infos) do
        local t = w.infos[i]
        if not t then
            t = Schrift(w, "GameFontHighlightSmall")
            t:SetTextColor(0.91, 0.71, 0.24)
            w.infos[i] = t
        end
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", vorher, "BOTTOMLEFT", 0, -10)
        t:SetPoint("RIGHT", w, "RIGHT", -20, 0)
        t:SetText("! " .. info)
        t:Show()
        vorher = t
        y = y + 10 + (t:GetStringHeight() or 12)
    end
    if #punkte == 0 and #infos == 0 then
        local t = w.infos[1] or Schrift(w, "GameFontHighlightSmall")
        w.infos[1] = t
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", w.frage, "BOTTOMLEFT", 0, -10)
        t:SetPoint("RIGHT", w, "RIGHT", -20, 0)
        t:SetTextColor(0.62, 0.60, 0.54)
        t:SetText("Nichts. Es hängt nichts daran.")
        t:Show()
        y = y + 24
    end
    w:SetHeight(18 + 20 + 6 + (w.unter:GetStringHeight() or 14) + 12 + 12 + y + 20 + 26 + 18)
    w.ok:SetScript("OnClick", function()
        for _, p in ipairs(w.punkte) do
            if p:IsShown() and p.pkt and (p:GetChecked() or p.pkt.pflicht) then
                p.pkt.tun()
            end
        end
        if art == "plan" then
            P.Liste()[obj.rezeptID] = nil
            Melden("Planauftrag storniert.")
        else
            Melden("Bestellung storniert.")
        end
        w:Hide()
        FensterAktualisieren()
    end)
    w:Show()
end


-- ---------------------------------------------------------------------------
-- Optionen und Minimap-Knopf (Version 1.1)
-- ---------------------------------------------------------------------------
O.STANDARD = { gilde = false, look = "erp", hinweis = "knopf", ton = true, chat = true, minimap = true, ah = "auto", groesse = 100, winkel = 200, ungelernt = true, teilen = true }

function O.Wert(name)
    local s = Daten().settings
    s.optionen = s.optionen or {}
    local v = s.optionen[name]
    if v == nil then
        return O.STANDARD[name]
    end
    return v
end

function O.Setzen(name, wert)
    local s = Daten().settings
    s.optionen = s.optionen or {}
    s.optionen[name] = wert
end

function O.Chat(text)
    if O.Wert("chat") then
        Melden(text)
    end
end

-- Neues merken (fuer den Knopf an der Minimap), hoechstens 10 Eintraege
function O.Merken(titel, text)
    local d = Daten()
    d.neues = d.neues or {}
    table.insert(d.neues, 1, { titel = titel, text = text, at = time() })
    while #d.neues > 10 do
        table.remove(d.neues)
    end
end

function O.Gesehen()
    local d = Daten()
    if d.neues and #d.neues > 0 then
        d.neues = {}
        O.KnopfZeigen()
    end
end

function O.KnopfPosition()
    local k = O.knopf
    if not k or not Minimap then
        return
    end
    local w = math.rad(O.Wert("winkel") or 200)
    local r = (Minimap:GetWidth() or 140) / 2 + 8
    k:ClearAllPoints()
    k:SetPoint("CENTER", Minimap, "CENTER", math.cos(w) * r, math.sin(w) * r)
end

function O.KnopfBauen()
    if O.knopf or not Minimap then
        return O.knopf
    end
    local k = O.Rahmen("Button", "GuildERPMinimapKnopf", Minimap)
    k:SetSize(32, 32)
    k:SetFrameStrata("MEDIUM")
    k:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
    k:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    k:RegisterForDrag("LeftButton")
    k.hg = k:CreateTexture(nil, "BACKGROUND")
    k.hg:SetSize(22, 22)
    k.hg:SetPoint("CENTER")
    k.hg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    k.icon = k:CreateTexture(nil, "ARTWORK")
    k.icon:SetSize(18, 18)
    k.icon:SetPoint("CENTER")
    k.icon:SetTexture(K.ICON_TITEL)
    k.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    k.rand = k:CreateTexture(nil, "OVERLAY")
    k.rand:SetSize(52, 52)
    k.rand:SetPoint("TOPLEFT")
    k.rand:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    k:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    -- sanftes Leuchten, wenn es Neues gibt
    k.glanz = k:CreateTexture(nil, "BACKGROUND", nil, -1)
    k.glanz:SetSize(46, 46)
    k.glanz:SetPoint("CENTER")
    k.glanz:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    k.glanz:SetBlendMode("ADD")
    k.glanz:SetVertexColor(K.STATUS_RGB.tasche[1], K.STATUS_RGB.tasche[2], K.STATUS_RGB.tasche[3], 1)
    k.glanz:Hide()
    if k.glanz.CreateAnimationGroup then
        local ag = k.glanz:CreateAnimationGroup()
        local a = ag and ag:CreateAnimation("Alpha")
        if a and a.SetFromAlpha then
            a:SetFromAlpha(0.25)
            a:SetToAlpha(1)
            a:SetDuration(1.4)
            ag:SetLooping("BOUNCE")
            k.puls = ag
        end
    end
    k.zahlHg = k:CreateTexture(nil, "OVERLAY", nil, 2)
    k.zahlHg:SetSize(16, 16)
    k.zahlHg:SetPoint("TOPRIGHT", 4, 2)
    k.zahlHg:SetTexture(K.WEISS)
    k.zahlHg:SetVertexColor(K.STATUS_RGB.gelb[1], K.STATUS_RGB.gelb[2], K.STATUS_RGB.gelb[3], 1)
    k.zahl = k:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    k.zahl:SetPoint("CENTER", k.zahlHg, "CENTER", 0, 0)
    k.zahl:SetTextColor(0.16, 0.11, 0.02)
    k:SetScript("OnClick", function(self, taste)
        if taste == "RightButton" then
            O.Zeigen()
            return
        end
        local d = Daten()
        if d.neues and #d.neues > 0 then
            d.settings.ansicht = "best"
            if not (Fenster and Fenster:IsShown()) then
                SlashCmdList.GUILDERP("")
            end
            FensterAktualisieren()
        else
            SlashCmdList.GUILDERP("")
        end
    end)
    k:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local skala = Minimap:GetEffectiveScale()
            if mx and cx then
                local w = math.deg(math.atan2(cy / skala - my, cx / skala - mx))
                O.Setzen("winkel", w)
                O.KnopfPosition()
            end
        end)
    end)
    k:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    k:SetScript("OnEnter", function(self)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Guild ERP")
        local d = Daten()
        if d.neues and #d.neues > 0 then
            for i, n in ipairs(d.neues) do
                if i <= 6 then
                    GameTooltip:AddLine(Farbe(K.STATUS_HEX.tasche, n.titel) .. ": " .. n.text, 1, 1, 1, true)
                end
            end
        else
            GameTooltip:AddLine("Nichts Neues.", 0.7, 0.7, 0.7)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Linksklick: öffnen" .. ((d.neues and #d.neues > 0) and ", wo es Neues gibt" or ""), 0.6, 0.6, 0.6)
        GameTooltip:AddLine("Rechtsklick: Optionen", 0.6, 0.6, 0.6)
        GameTooltip:AddLine("Ziehen: am Rand verschieben", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    k:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    O.knopf = k
    O.KnopfPosition()
    return k
end

function O.KnopfZeigen()
    if not O.Wert("minimap") then
        if O.knopf then
            O.knopf:Hide()
        end
        return
    end
    local k = O.KnopfBauen()
    if not k then
        return
    end
    local d = Daten()
    local n = d.neues and #d.neues or 0
    local leuchten = n > 0 and O.Wert("hinweis") == "knopf"
    k.glanz:SetShown(leuchten)
    if k.puls then
        if leuchten and not k.puls:IsPlaying() then
            k.puls:Play()
        elseif not leuchten then
            k.puls:Stop()
        end
    end
    k.zahl:SetText(n > 0 and (n > 9 and "9+" or n) or "")
    k.zahl:SetShown(n > 0)
    k.zahlHg:SetShown(n > 0)
    k:Show()
end

-- ----- Fenster "Optionen" -----
function O.Zeigen()
    local w = O.fenster
    if not w then
        w = O.Rahmen("Frame", "GuildERPOptionen", UIParent, K.BACKDROP_VORLAGE)
        w:SetSize(520, 400)
        w:SetPoint("CENTER", 0, 40)
        w:SetFrameStrata("HIGH")
        w:SetToplevel(true)
        w:EnableMouse(true)
        w:SetMovable(true)
        w:RegisterForDrag("LeftButton")
        w:SetScript("OnDragStart", function() w:StartMoving() end)
        w:SetScript("OnDragStop", function() w:StopMovingOrSizing() end)
        w:SetClampedToScreen(true)
        if w.SetBackdrop then
            w:SetBackdrop(K.BACKDROP_RAHMEN)
        end
        local deckel = w:CreateTexture(nil, "BACKGROUND", nil, -8)
        deckel:SetPoint("TOPLEFT", 6, -6)
        deckel:SetPoint("BOTTOMRIGHT", -6, 6)
        deckel:SetColorTexture(0.06, 0.06, 0.07, 0.96)
        table.insert(UISpecialFrames, "GuildERPOptionen")
        w.titel = Schrift(w, "GameFontNormalLarge")
        w.titel:SetPoint("TOPLEFT", 20, -18)
        w.titel:SetText("Optionen")
        local zu = O.Rahmen("Button", nil, w, "UIPanelCloseButton")
        zu:SetPoint("TOPRIGHT", -4, -4)
        w.zeilen = {}
        local y = 52
        local function zeile(titel, unter)
            local z = {}
            z.text = Schrift(w, "GameFontHighlight")
            z.text:SetPoint("TOPLEFT", 20, -y)
            z.unter = Schrift(w, "GameFontHighlightSmall")
            z.unter:SetPoint("TOPLEFT", z.text, "BOTTOMLEFT", 0, -2)
            z.unter:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
            z.text:SetText(titel)
            z.unter:SetText(unter or "")
            z.linie = w:CreateTexture(nil, "ARTWORK")
            z.linie:SetHeight(1)
            z.linie:SetPoint("TOPLEFT", 20, -(y - 8))
            z.linie:SetPoint("TOPRIGHT", -20, -(y - 8))
            z.linie:SetColorTexture(1, 1, 1, 0.07)
            z.y = y
            y = y + (unter and 50 or 40)
            return z
        end
        local function auswahl(z, name, eintraege)
            local b = WahlKnopf(w, 230)
            b:SetPoint("TOPRIGHT", -20, -(z.y - 4))
            b.zeigen = function()
                for _, e in ipairs(eintraege) do
                    if e.wert == O.Wert(name) then
                        b.text:SetText(e.text)
                    end
                end
            end
            b:SetScript("OnClick", function(self)
                local liste = {}
                for _, e in ipairs(eintraege) do
                    table.insert(liste, { wert = e.wert, text = e.text, gewaehlt = e.wert == O.Wert(name) })
                end
                PopupZeigen(self, 230, liste, function(wert)
                    O.Setzen(name, wert)
                    O.Anwenden()
                end)
            end)
            table.insert(w.zeilen, b)
        end
        local function haken(z, name)
            local c = O.Rahmen("CheckButton", nil, w, "UICheckButtonTemplate")
            c:SetSize(26, 26)
            c:SetPoint("TOPRIGHT", -18, -(z.y - 6))
            c.zeigen = function() c:SetChecked(O.Wert(name) and true or false) end
            c:SetScript("OnClick", function(self)
                O.Setzen(name, self:GetChecked() and true or false)
                O.Anwenden()
            end)
            table.insert(w.zeilen, c)
        end
        auswahl(zeile("Aussehen", "Spiel-Look: wie das Berufefenster (Testversion)"), "look", {
            { wert = "erp", text = "Guild ERP (dunkel)" },
            { wert = "spiel", text = "Spiel-Look" },
        })
        auswahl(zeile("Neues anzeigen", "Bestellungen, Zusagen und Stornos anderer"), "hinweis", {
            { wert = "knopf", text = "Knopf an der Minimap leuchtet" },
            { wert = "fenster", text = "Fenster in der Mitte" },
            { wert = "chat", text = "Nur im Chat" },
        })
        haken(zeile("Ton bei Neuem"), "ton")
        haken(zeile("Meldungen im Chat"), "chat")
        haken(zeile("Knopf an der Minimap zeigen", "Ohne Knopf öffnest du Guild ERP mit /gerp"), "minimap")
        auswahl(zeile("Preise im Auktionshaus holen", "Gesucht wird nur, gekauft wird nie"), "ah", {
            { wert = "auto", text = "Automatisch beim Öffnen" },
            { wert = "knopf", text = "Nur auf Knopfdruck" },
            { wert = "nie", text = "Nie" },
        })
        haken(zeile("Noch nicht gelernte Berufe zeigen", "Berufe, von denen dir schon Rezepte bekannt sind"), "ungelernt")
        haken(zeile("Fundorte und Preise teilen", "Nur mit Spielern, die Guild ERP haben, gleiche Fraktion"), "teilen")
        haken(zeile("Guild-Found", "Guild ERP, Handel und Post nur innerhalb der Gilde"), "gilde")
        -- Reihenfolge der Reiter (ab 1.1.9)
        local zr = zeile("Reihenfolge der Reiter", "Mit den Pfeilen nach oben oder unten schieben")
        local reihe = { zeigen = function() end, zeilen = {} }
        for i = 1, 4 do
            local r = O.Rahmen("Frame", nil, w)
            r:SetSize(230, 24)
            r:SetPoint("TOPRIGHT", -20, -(zr.y - 4 + (i - 1) * 26))
            r.hg = r:CreateTexture(nil, "BACKGROUND")
            r.hg:SetAllPoints()
            r.hg:SetColorTexture(1, 1, 1, 0.04)
            r.text = Schrift(r, "GameFontHighlight")
            r.text:SetPoint("LEFT", 8, 0)
            local function pfeil(tex, x, um)
                local b = O.Rahmen("Button", nil, r)
                b:SetSize(22, 22)
                b:SetPoint("RIGHT", x, 0)
                b:SetNormalTexture("Interface\\Buttons\\Arrow-" .. tex .. "-Up")
                b:SetPushedTexture("Interface\\Buttons\\Arrow-" .. tex .. "-Down")
                b:SetDisabledTexture("Interface\\Buttons\\Arrow-" .. tex .. "-Disabled")
                b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
                b:SetScript("OnClick", function() O.ReiterSchieben(i, um) end)
                return b
            end
            r.runter = pfeil("Down", -2, 1)
            r.hoch = pfeil("Up", -26, -1)
            reihe.zeilen[i] = r
        end
        reihe.zeigen = function()
            for i, wert in ipairs(O.Reihenfolge()) do
                local r = reihe.zeilen[i]
                r.text:SetText(i .. ".  " .. O.REITER_NAME[wert])
                r.hoch:SetEnabled(i > 1)
                r.runter:SetEnabled(i < 4)
            end
        end
        table.insert(w.zeilen, reihe)
        y = zr.y + 4 * 26 + 14
        local zg = zeile("Größe des Fensters")
        w.groesse = Schrift(w, "GameFontHighlight", false)
        w.groesse:SetWidth(56)
        w.groesse:SetJustifyH("CENTER")
        w.plus = O.Rahmen("Button", nil, w, "UIPanelButtonTemplate")
        w.plus:SetSize(26, 22)
        w.plus:SetText("+")
        w.plus:SetPoint("TOPRIGHT", -20, -(zg.y - 4))
        w.groesse:SetPoint("RIGHT", w.plus, "LEFT", -2, 0)
        w.minus = O.Rahmen("Button", nil, w, "UIPanelButtonTemplate")
        w.minus:SetSize(26, 22)
        w.minus:SetText("-")
        w.minus:SetPoint("RIGHT", w.groesse, "LEFT", -2, 0)
        local function groesse(um)
            O.Setzen("groesse", math.max(70, math.min(130, (O.Wert("groesse") or 100) + um)))
            O.Anwenden()
        end
        w.plus:SetScript("OnClick", function() groesse(5) end)
        w.minus:SetScript("OnClick", function() groesse(-5) end)
        w.fertig = O.Rahmen("Button", nil, w, "UIPanelButtonTemplate")
        w.fertig:SetSize(100, 26)
        w.fertig:SetPoint("BOTTOMRIGHT", -18, 16)
        w.fertig:SetText("Fertig")
        w.fertig:SetScript("OnClick", function() w:Hide() end)
        w:SetHeight(y + 50)
        O.fenster = w
    end
    for _, el in ipairs(w.zeilen) do
        el.zeigen()
    end
    w.groesse:SetText((O.Wert("groesse") or 100) .. " %")
    w:Show()
end

-- Optionen sofort wirken lassen
function O.Anwenden()
    if Fenster then
        Fenster:SetScale((O.Wert("groesse") or 100) / 100)
    end
    if O.letzteGilde ~= O.GildeModus() then
        local vorher = O.letzteGilde
        O.letzteGilde = O.GildeModus()
        if vorher ~= nil then
            B.schlange = {}
            Kat.Daten().fremdStand = {}
            Melden(O.GildeModus() and "Guild-Found ist an: Guild ERP gleicht nur noch mit deiner Gilde ab. Handel und Post von außerhalb der Gilde werden abgelehnt bzw. markiert."
                or "Guild-Found ist aus: Guild ERP gleicht wieder mit deiner Gruppe ab.")
            pcall(O.GildeStart)
            if B.GruppeGeaendert and not O.GildeModus() then
                B.mitglieder = {}
                pcall(B.GruppeGeaendert)
            end
        end
    end
    if O.letzterLook ~= O.Wert("look") then
        O.letzterLook = O.Wert("look")
        O.LookAnwenden()
    end
    O.KnopfZeigen()
    if O.fenster and O.fenster:IsShown() then
        O.Zeigen()
    end
    FensterAktualisieren()
end

FensterAktualisieren = function()
    if P.netz and P.netz:IsShown() then
        P.NetzZeigen()
    end
    if not Fenster or not Fenster:IsShown() then
        return
    end
    local f = Fenster
    local ansicht = Daten().settings.ansicht
    if ansicht ~= "best" and ansicht ~= "plan" and ansicht ~= "kat" then
        ansicht = "werk"
    end
    local werk = ansicht == "werk"
    f.links:SetShown(werk)
    f.rechts:SetShown(werk)
    f.trenner:SetShown(werk)
    f.best:SetShown(ansicht == "best")
    f.plan:SetShown(ansicht == "plan")
    f.kat:SetShown(ansicht == "kat")
    if not werk and B.schein then
        B.schein:Hide()
    end
    if ansicht ~= "best" and B.zusage then
        B.zusage:Hide()
    end
    local offen = B.OffenFuerMich()
    f.reiterBest.text:SetText("Bestellungen" .. (offen > 0 and ("  " .. Farbe("e8b53e", "(" .. offen .. ")")) or ""))
    f.reiterBest:SetWidth((f.reiterBest.text:GetStringWidth() or 100) + 28)
    local planZahl = 0
    for _, plan in pairs(P.Liste()) do
        if P.VomSpieler(plan) then
            planZahl = planZahl + 1
        end
    end
    f.reiterPlan.text:SetText("Planaufträge" .. (planZahl > 0 and ("  " .. Farbe(K.STATUS_HEX.blau, "(" .. planZahl .. ")")) or ""))
    f.reiterPlan:SetWidth((f.reiterPlan.text:GetStringWidth() or 100) + 28)
    O.SeitenSync(f, ansicht, planZahl, offen)
    for _, r in ipairs({ { f.reiterWerk, werk }, { f.reiterPlan, ansicht == "plan" }, { f.reiterBest, ansicht == "best" }, { f.reiterKat, ansicht == "kat" } }) do
        r[1].linie:SetShown(r[2])
        if r[2] then
            r[1].text:SetTextColor(K.TEXT[1], K.TEXT[2], K.TEXT[3])
        else
            r[1].text:SetTextColor(K.GEDAEMPFT[1], K.GEDAEMPFT[2], K.GEDAEMPFT[3])
        end
    end
    if werk then
        local fraktion = SpielerFraktion()
        local _, rezepte, berufe = HerstellerSammeln(fraktion)
        Kat.BerufeErgaenzen(berufe, fraktion)
        RezeptbuchZeigen(f, fraktion, rezepte, berufe)
        AuftragZeigen(f, fraktion, rezepte)
    elseif ansicht == "plan" then
        P.AnsichtZeigen(f)
    elseif ansicht == "kat" then
        Kat.AnsichtZeigen(f)
    else
        B.AnsichtZeigen(f)
        O.Gesehen()
    end
end

local aktualisierenWartet = false
local function FensterSpaeterAktualisieren()
    if aktualisierenWartet or not (Fenster and Fenster:IsShown()) then
        return
    end
    aktualisierenWartet = true
    O.Nach(0.5, function()
        aktualisierenWartet = false
        FensterAktualisieren()
    end)
end

local function FensterUmschalten()
    if not Fenster then
        Fenster = FensterBauen()
    end
    if Fenster:IsShown() then
        Fenster:Hide()
    else
        Fenster:Show()
        O.Nach(0.05, FensterAktualisieren)
    end
end

local function StandZeigen()
    local d = Daten()
    local fraktion = SpielerFraktion()
    print(ADDON_TITEL .. " " .. K.VERSION .. " (Beta)")
    local namen = {}
    for s in pairs(d.characters) do
        table.insert(namen, s)
    end
    table.sort(namen)
    for _, s in ipairs(namen) do
        local c = d.characters[s]
        local anzahl = 0
        for _, ids in pairs(c.recipes or {}) do
            for _ in pairs(ids) do
                anzahl = anzahl + 1
            end
        end
        print("- " .. (c.name or s) .. (c.faction ~= fraktion and " (andere Fraktion)" or "")
            .. ": " .. anzahl .. (anzahl == 1 and " Rezept" or " Rezepte") .. ", Taschen " .. Alter(c.bagsAt)
            .. ", Bank " .. (c.bankAt and Alter(c.bankAt) or "unbekannt"))
    end
    local namenZahl = 0
    for _, e in pairs(d.items) do
        if e.name then
            namenZahl = namenZahl + 1
        end
    end
    print("Berufefenster öffnen: " .. tostring(d.diagnostics.berufefenster or "noch nicht benutzt"))
    print("Zutaten gelesen über: " .. tostring(d.diagnostics.zutatenWeg or "noch nichts")
        .. ", bekannte Gegenstandsnamen: " .. namenZahl
        .. ", Rezepte mit gemerkter Quelle: " .. Kat.QuellenZahl()
        .. ", Reiseführer (optional): " .. (Reisefuehrer() and "gefunden" or "nicht installiert"))
    local fehler = d.diagnostics.fehler or {}
    print("Fehler seit dieser Version: " .. (#fehler == 0 and "keine" or #fehler))
    for i = #fehler, math.max(1, #fehler - 4), -1 do
        local e = fehler[i]
        print("  " .. e.n .. "x " .. e.ort .. " (" .. Alter(e.at) .. "): " .. e.text)
    end
end

-- ---------------------------------------------------------------------------
-- Ereignisse
-- ---------------------------------------------------------------------------
local taschenWarten = false
local function TaschenSpaeterLesen()
    if taschenWarten then
        return
    end
    taschenWarten = true
    O.Nach(1, function()
        taschenWarten = false
        TaschenLesen()
        BankLesen()
        FensterSpaeterAktualisieren()
    end)
end

frame:RegisterEvent("PLAYER_LOGIN")
pcall(frame.RegisterEvent, frame, "BAG_UPDATE")
pcall(frame.RegisterEvent, frame, "BANKFRAME_OPENED")
pcall(frame.RegisterEvent, frame, "BANKFRAME_CLOSED")
pcall(frame.RegisterEvent, frame, "PLAYERBANKSLOTS_CHANGED")
pcall(frame.RegisterEvent, frame, "TRADE_SKILL_SHOW")
pcall(frame.RegisterEvent, frame, "TRADE_SKILL_LIST_UPDATE")
pcall(frame.RegisterEvent, frame, "MERCHANT_SHOW")
pcall(frame.RegisterEvent, frame, "CHAT_MSG_ADDON")
pcall(frame.RegisterEvent, frame, "GROUP_ROSTER_UPDATE")
pcall(frame.RegisterEvent, frame, "GET_ITEM_INFO_RECEIVED")
for _, e in ipairs({ "TRADE_SHOW", "MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_CLOSED", "GUILD_ROSTER_UPDATE",
    "TRAINER_SHOW", "TRAINER_UPDATE", "LOOT_OPENED" }) do
    pcall(frame.RegisterEvent, frame, e)
end
for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "COMMODITY_SEARCH_RESULTS_UPDATED",
    "ITEM_SEARCH_RESULTS_UPDATED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
    pcall(frame.RegisterEvent, frame, e)
end

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, K.PREFIX)
elseif RegisterAddonMessagePrefix then
    pcall(RegisterAddonMessagePrefix, K.PREFIX)
end

frame:SetScript("OnEvent", function(self, event, ...)
    O.Sicher(event, O.Ereignis, event, ...)
end)

function O.Ereignis(event, ...)
    if A.Ereignis(event, ...) then
        return
    end
    if O.GildeEreignis(event, ...) then
        return
    end
    if event == "CHAT_MSG_ADDON" then
        local prefix, text, kanal, absender = ...
        -- Guild-Found (ab 1.3): nur Nachrichten aus dem Gildenkanal; sonst keine aus dem Gildenkanal
        local passt = (kanal == "GUILD") == O.GildeModus()
        if prefix == K.PREFIX and passt and type(text) == "string" and #text <= 255 then
            pcall(B.EchoPruefen, text, absender)
            local ok, fehler = pcall(B.Empfangen, text, absender) -- fehlerhafte Nachrichten anderer ignorieren
            if not ok then
                B.Diagnose("fehler", "Empfang", fehler)
                O.Fehler("Empfang", fehler)
            end
        end
        return
    elseif event == "GROUP_ROSTER_UPDATE" then
        if not B.gruppeWartet then
            B.gruppeWartet = true
            O.Nach(3, function()
                B.gruppeWartet = false
                B.GruppeGeaendert()
            end)
        end
        return
    end
    if event == "PLAYER_LOGIN" then
        -- Fehler aelterer Versionen sind mit dem Update hinfaellig
        local dg = Daten().diagnostics
        if dg.fehlerVersion ~= K.VERSION then
            dg.fehlerVersion, dg.fehler = K.VERSION, nil
        end
        Kat.QuellenAufraeumen()
        O.Nach(3, function()
            Charakter()
            TaschenLesen()
            O.Nach(5, function() pcall(Kat.Aufraeumen) end)
            -- bekannte Zutaten: Namen beim Spiel anfordern (fuer die Anzeige)
            for _, r in pairs(Daten().recipes) do
                for _, z in ipairs(r.reagents or {}) do
                    if not (GuildERPData.items[z.itemID] and GuildERPData.items[z.itemID].name) then
                        ItemName(z.itemID)
                    end
                end
            end
            Melden("Version " .. K.VERSION .. " (Beta) geladen. /gerp öffnet die Werkstatt.")
            pcall(O.KnopfZeigen)
            local offen = B.OffenFuerMich()
            if offen > 0 then
                Melden(offen == 1 and "1 Bestellung wartet auf dich (/gerp, Bestellungen)."
                    or (offen .. " Bestellungen warten auf dich (/gerp, Bestellungen)."))
            end
            B.GruppeGeaendert()
            O.letzteGilde = O.GildeModus()
            pcall(O.GildeStart)
        end)
    elseif event == "BAG_UPDATE" or event == "PLAYERBANKSLOTS_CHANGED" then
        TaschenSpaeterLesen()
    elseif event == "BANKFRAME_OPENED" then
        bankOffen = true
        O.Nach(0.5, function()
            BankLesen()
            FensterSpaeterAktualisieren()
        end)
    elseif event == "BANKFRAME_CLOSED" then
        BankLesen()
        bankOffen = false
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" then
        RezepteSpaeterLesen()
        if not Kat.wartet then
            Kat.wartet = true
            O.Nach(8, function()
                Kat.wartet = false
                Kat.VielleichtMelden()
            end)
        end
        if offenerAuftrag then
            O.Nach(0.3, BerufefensterVorwaehlen)
        end
    elseif event == "MERCHANT_SHOW" then
        O.Nach(0.5, HaendlerLesen)
        O.Nach(0.5, function()
            Kat.QuellenLesen(Kat.HaendlerRezepteLesen)
            FensterSpaeterAktualisieren()
        end)
    elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
        -- die Liste kann erst nach dem Oeffnen vollstaendig sein: pro Fenster einmal nachlesen
        if event == "TRAINER_SHOW" or Kat.lehrerNachlesen then
            Kat.lehrerNachlesen = event == "TRAINER_SHOW"
            O.Nach(event == "TRAINER_SHOW" and 0.5 or 1, function()
                Kat.QuellenLesen(Kat.LehrerLesen)
                FensterSpaeterAktualisieren()
            end)
        end
    elseif event == "LOOT_OPENED" then
        O.Nach(0.1, function()
            Kat.QuellenLesen(Kat.BeuteLesen)
            FensterSpaeterAktualisieren()
        end)
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local itemID = ...
        if itemID then
            ItemName(itemID)
        end
        FensterSpaeterAktualisieren()
    end
end

SLASH_GUILDERP1 = "/gerp"
SLASH_GUILDERP2 = "/guilderp"
SlashCmdList["GUILDERP"] = function(eingabe)
    O.Sicher("Befehl", O.Befehl, eingabe)
end

function O.Befehl(eingabe)
    eingabe = string.lower(strtrim(eingabe or ""))
    if eingabe == "info" or eingabe == "stand" then
        StandZeigen()
    elseif eingabe == "abgleich" then
        Kat.DiagnoseZeigen()
    elseif eingabe == "optionen" or eingabe == "options" then
        O.Zeigen()
    elseif eingabe == "optik" then
        O.OptikLesen()
    elseif eingabe == "hilfe" or eingabe == "help" then
        Melden("/gerp = Werkstatt öffnen/schließen, /gerp optionen = Optionen, /gerp info = Stand im Chat, /gerp abgleich = Abgleich prüfen, /gerp optik = Berufefenster-Optik auslesen.")
    else
        FensterUmschalten()
    end
end
