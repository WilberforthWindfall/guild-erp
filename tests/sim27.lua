-- 1.6 Komplett-Abfrage des Auktionshauses (ReplicateItems) mit Rueckfall auf Einzelsuche
-- lua51 sim27.lua <GuildERP.lua> <GuildERP-SV>
dofile((arg[0]:gsub("sim27%.lua$", "")) .. "stubs.lua")
GetItemInfo = nil
C_Item = { GetItemIconByID = function(id) return "icon" .. id end }
dofile(arg[2])
PLAYER = { name = "Barlor", realm = "Classic Beta PvE", faction = "Alliance", class = "PALADIN", zone = "Eisenschmiede" }
CONTAINERS = { [0] = {} }
CLOCK = 100
GetTime = function() return CLOCK end
local after = C_Timer.After
C_Timer.After = function(t, fn) after(t, function() CLOCK = CLOCK + (t or 0); fn() end) end
function hooksecurefunc(t, name, fn) local old = t[name]; t[name] = function(...) local r = { old(...) }; fn(...); return unpack(r) end end
Enum = { AuctionHouseSortOrder = { Price = 0 } }

local fehler = 0
local function pruefe(ok, text)
  if ok then realPrint("  ok: " .. text) else fehler = fehler + 1; realPrint("  FALSCH: " .. text) end
end

-- Angebote im Auktionshaus: { itemID, Menge, Sofortkauf fuer den Stapel }
local LISTE = {
  { 2770, 20, 900 },    -- Kupfererz: 45 je Stueck
  { 2770, 10, 500 },    -- 50 je Stueck
  { 2770, 1, 900 },     -- Ausreisser 900
  { 2835, 40, 800 },    -- Rauer Stein: 20 je Stueck
  { 2840, 1, 110 },     -- Kupferbarren
  { 2840, 1, 0 },       -- nur Gebot, zaehlt nicht
}
for i = 1, 5000 do table.insert(LISTE, { 90000 + i, 1, 1000 }) end -- fremde Gegenstaende
local unfertig = { [2] = 1 }  -- Angebot 2 ist beim ersten Lesen noch unvollstaendig
local modus = "normal"
local replikat, suchen = 0, 0
C_AuctionHouse = {
  MakeItemKey = function(id) return { itemID = id } end,
  SendSearchQuery = function(key) suchen = suchen + 1
    C_Timer.After(0.2, function() Fire("COMMODITY_SEARCH_RESULTS_UPDATED", key.itemID) end)
  end,
  SendBrowseQuery = function() end,
  GetNumCommoditySearchResults = function() return 1 end,
  GetCommoditySearchResultInfo = function() return { unitPrice = 77, quantity = 3 } end,
  GetNumItemSearchResults = function() return 0 end,
  GetItemSearchResultInfo = function() return nil end,
  ReplicateItems = function()
    replikat = replikat + 1
    if modus == "still" then return end
    C_Timer.After(0.5, function() Fire("REPLICATE_ITEM_LIST_UPDATE") end)
  end,
  GetNumReplicateItems = function() return modus == "leer" and 0 or #LISTE end,
  GetReplicateItemInfo = function(i)
    local e = LISTE[i]
    if unfertig[i] and unfertig[i] > 0 then
      unfertig[i] = unfertig[i] - 1
      return nil, nil, e[2], 1, true, 1, nil, 0, 0, nil, 0, nil, nil, nil, nil, 0, e[1], false
    end
    return "x", 1, e[2], 1, true, 1, nil, 0, 0, e[3], 0, nil, nil, nil, nil, 0, e[1], true
  end,
}
assert(loadfile(arg[1]))()
local ah = CreateFrame("Frame", "AuctionHouseFrame"); AuctionHouseFrame = ah
local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " / ")) end
Fire("PLAYER_LOGIN"); RunTimers()
local function laufen() for i = 1, 60 do RunTimers() end end

realPrint("--- 1. Komplett-Abfrage klappt")
for _, e in pairs(GuildERPData.prices.Alliance or {}) do e.at = 0 end
Fire("AUCTION_HOUSE_SHOW"); laufen()
local w = GuildERPPreise
local p = GuildERPData.prices.Alliance
realPrint("  Fenster: " .. strip(w.stand.text) .. " | " .. strip(w.text.text))
pruefe(replikat == 1, "eine Komplett-Abfrage (" .. replikat .. ")")
pruefe(suchen == 0, "keine Einzelsuchen (" .. suchen .. ")")
pruefe(p[2770] and p[2770].min == 45 and p[2770].avg == 47 and p[2770].n == 30, "Kupfererz ab 45, Schnitt 47 aus 30 Stueck (Ausreisser weg, Nachlese klappt)")
pruefe(p[2835] and p[2835].min == 20, "Rauer Stein ab 20")
pruefe(p[2840] and p[2840].min == 110 and p[2840].n == 1, "Kupferbarren 110, reines Gebot zaehlt nicht")
pruefe(p[2880] and p[2880].leer, "Schwacher Fluxus: nicht im Angebot")
pruefe(GuildERPData.ahKomplett == time(), "Zeitpunkt der Abfrage gemerkt")
Fire("AUCTION_HOUSE_CLOSED"); RunTimers()

realPrint("--- 2. Sperre (andere Abfrage vor 5 Minuten) -> Einzelsuche")
NOW_OFFSET = 31 * 60
C_AuctionHouse.ReplicateItems() -- ein anderes Add-on fragt ab (Haken wird erst beim Oeffnen gesetzt)
replikat = 0
GuildERPData.ahKomplett = time() - 5 * 60
Fire("AUCTION_HOUSE_SHOW"); laufen()
pruefe(replikat == 0, "keine Komplett-Abfrage waehrend der Sperre")
pruefe(suchen > 0, "Einzelsuche als Rueckfall (" .. suchen .. ")")
pruefe(p[2770].min == 77, "Preis aus der Einzelsuche")
Fire("AUCTION_HOUSE_CLOSED"); RunTimers()

realPrint("--- 3. Fremdes Add-on fragt ab -> Sperre wird beachtet")
NOW_OFFSET = 2 * 60 * 60
replikat, suchen = 0, 0
C_AuctionHouse.ReplicateItems() -- jetzt mit Haken
pruefe(GuildERPData.ahKomplett == time(), "fremde Abfrage gemerkt")
replikat = 0
NOW_OFFSET = 2 * 60 * 60 + 31 * 60 - 20 * 60 -- 11 Minuten spaeter, aber Preise schon alt
for _, e in pairs(p) do e.at = 0 end
Fire("AUCTION_HOUSE_SHOW"); laufen()
pruefe(replikat == 0 and suchen > 0, "Einzelsuche statt Komplett-Abfrage")
Fire("AUCTION_HOUSE_CLOSED"); RunTimers()

realPrint("--- 4. Leere Liste -> Rueckfall (alte Preise werden nicht ueberschrieben)")
NOW_OFFSET = 5 * 60 * 60
modus, replikat, suchen = "leer", 0, 0
Fire("AUCTION_HOUSE_SHOW"); laufen()
pruefe(replikat == 1 and suchen > 0, "leere Antwort -> Einzelsuche")
pruefe(GuildERPData.prices.Alliance[2770].min == 77, "Preis nicht als leer gespeichert")
Fire("AUCTION_HOUSE_CLOSED"); RunTimers()

realPrint("--- 5. Keine Antwort -> Rueckfall, in dieser Sitzung nicht wieder")
NOW_OFFSET = 8 * 60 * 60
modus, replikat, suchen = "still", 0, 0
Fire("AUCTION_HOUSE_SHOW"); laufen()
pruefe(replikat == 1, "einmal versucht")
pruefe(suchen > 0, "danach einzeln gesucht")
Fire("AUCTION_HOUSE_CLOSED"); RunTimers()
NOW_OFFSET = 9 * 60 * 60
modus, replikat, suchen = "normal", 0, 0
Fire("AUCTION_HOUSE_SHOW"); laufen()
pruefe(replikat == 0 and suchen > 0, "nicht noch einmal versucht")
Fire("AUCTION_HOUSE_CLOSED"); RunTimers()

realPrint("Pruefungen falsch: " .. fehler)
if fehler > 0 then error("sim27: " .. fehler .. " Pruefungen falsch") end
