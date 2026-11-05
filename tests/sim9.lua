-- 0.8 Auktionshaus-Preise: lua51 sim9.lua <GuildERP.lua> <GuildERP-SV>
dofile((arg[0]:gsub("sim9%.lua$", "")) .. "stubs.lua")
GetItemInfo = nil
C_Item = { GetItemIconByID = function(id) return "icon" .. id end }
dofile(arg[2])
PLAYER = { name = "Barlor", realm = "Classic Beta PvE", faction = "Alliance", class = "PALADIN", zone = "Eisenschmiede" }
local fach = {}
for id, n in pairs(GuildERPData.characters["Classic Beta PvE-Barlor"].bags) do table.insert(fach, { id, n }) end
CONTAINERS = { [0] = fach }
-- Uhr: jeder Timer rueckt die Zeit vor
CLOCK = 100
GetTime = function() return CLOCK end
local after = C_Timer.After
C_Timer.After = function(t, fn) after(t, function() CLOCK = CLOCK + (t or 0); fn() end) end
function hooksecurefunc(t, name, fn) local old = t[name]; t[name] = function(...) old(...); fn(...) end end
Enum = { AuctionHouseSortOrder = { Price = 0 } }
local MARKT = {
  [2770] = { c = true, o = { { 45, 20 }, { 50, 10 }, { 60, 30 }, { 900, 1 } } },  -- Kupfererz
  [2835] = { c = true, o = { { 20, 40 }, { 30, 20 } } },                         -- Rauer Stein
  [2880] = { c = true, o = {} },                                                 -- Schwacher Fluxus
  [2840] = { c = false, o = { { 110, 1 }, { 160, 1 } } },                        -- Kupferbarren (Gegenstand)
  [2589] = "still",                                                              -- Leinenstoff: keine Antwort
}
local anfragen = 0
C_AuctionHouse = {
  MakeItemKey = function(id) return { itemID = id } end,
  SendSearchQuery = function(key) anfragen = anfragen + 1
    local m = MARKT[key.itemID]
    if m == "still" then return end
    if not m then m = { c = true, o = { { 100, 5 }, { 120, 5 } } }; MARKT[key.itemID] = m end
    C_Timer.After(0.2, function() Fire(m.c and "COMMODITY_SEARCH_RESULTS_UPDATED" or "ITEM_SEARCH_RESULTS_UPDATED", m.c and key.itemID or key) end)
  end,
  SendBrowseQuery = function() end,
  GetNumCommoditySearchResults = function(id) return #MARKT[id].o end,
  GetCommoditySearchResultInfo = function(id, i) local o = MARKT[id].o[i]; return { unitPrice = o[1], quantity = o[2] } end,
  GetNumItemSearchResults = function(k) return #(MARKT[k.itemID] or { o = { 1 } }).o end,
  GetItemSearchResultInfo = function(k, i) local m = MARKT[k.itemID] or { o = { { 100, 5 } } }; local o = m.o[i]; return { buyoutAmount = o[1], quantity = o[2] } end,
}
assert(loadfile(arg[1]))()
local ah = CreateFrame("Frame", "AuctionHouseFrame"); AuctionHouseFrame = ah
local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " / ")) end
Fire("PLAYER_LOGIN"); RunTimers()
-- Auktionshaus oeffnen, nach ein paar Schritten sucht der Spieler selbst
Fire("AUCTION_HOUSE_SHOW")
local w
for i = 1, 40 do RunTimers() end
w = GuildERPPreise
realPrint("Preisfenster: " .. strip(w.titel.text) .. " | " .. strip(w.stand.text) .. " | " .. strip(w.rest.text) .. " | Knopf " .. w.knopf.text)
realPrint("  " .. strip(w.text.text))
for _, z in ipairs(w.zeilen) do if z.name.text ~= "" then realPrint("   " .. strip(z.name.text) .. "  =  " .. strip(z.preis.text)) end end
realPrint("Anfragen gesendet: " .. anfragen)
local p = GuildERPData.prices.Alliance
for _, id in ipairs({ 2770, 2835, 2880, 2840, 2589 }) do local e = p[id]; realPrint(string.format("  %d: %s", id, e and (e.leer and "leer" or (e.min .. " / " .. e.avg .. " (n=" .. e.n .. ")")) or "nil")) end
-- Pause testen: Neustart des Laufs nach 31 Minuten, mittendrin sucht der Spieler
Fire("AUCTION_HOUSE_CLOSED"); RunTimers()
NOW_OFFSET = 31 * 60
anfragen = 0
local pausen = 0
local alt = w.rest.SetText
w.rest.SetText = function(self, t) if t == "du suchst gerade selbst" then pausen = pausen + 1 end alt(self, t) end
Fire("AUCTION_HOUSE_SHOW")
C_AuctionHouse.SendBrowseQuery()
-- ein paar Takte
local n = 0
local function schritt() for i = 1, 3 do RunTimers() end end
schritt()
realPrint("Nach eigener Suche: Pause-Anzeigen=" .. pausen .. ", Anfragen=" .. anfragen .. " | " .. strip(w.stand.text))
Click(w.knopf); RunTimers()
realPrint("Nach Stopp: " .. strip(w.stand.text) .. " | " .. strip(w.hinweis.text) .. " | Knopf " .. w.knopf.text)
-- Erneut oeffnen innerhalb von 30 Min: nichts zu tun?
Fire("AUCTION_HOUSE_CLOSED"); RunTimers()
NOW_OFFSET = 31 * 60 + 60
Fire("AUCTION_HOUSE_SHOW"); for i = 1, 40 do RunTimers() end
realPrint("Wieder offen: " .. strip(w.stand.text) .. " | " .. strip(w.text.text))
Fire("AUCTION_HOUSE_CLOSED"); RunTimers()
-- Werkstatt
SlashCmdList.GUILDERP(""); RunTimers()
local f = GuildERPFenster
local d = GuildERPData
for id, r in pairs(d.recipes) do if r.name == "Kupferstreitaxt" then d.settings.wunsch = id end end
d.settings.menge = 1; d.settings.ansicht = "werk"
SlashCmdList.GUILDERP(""); SlashCmdList.GUILDERP(""); RunTimers()
realPrint("--- Werkstatt")
for _, z in ipairs(f.rechts.zeilen) do if z.shown then realPrint(string.format("   %-20s %s", strip(z.name.text), z.quelle.shown and strip(z.quelle.text) or "")) end end
realPrint("  Kasten: " .. strip(f.rechts.hinweis.text.text))
Click(f.rechts.karte.plan); RunTimers()
Click(f.rechts.hinweis.knopf); RunTimers()
Click(GuildERPBestellschein.senden); RunTimers()
Click(f.reiterBest); RunTimers()
realPrint("--- Bestellungen")
for _, sch in ipairs(f.best.spalten[2].scheine) do if sch.benutzt then
  for _, r in ipairs(sch.zeilen) do if r.shown then realPrint("     " .. strip(r.text.text) .. " | " .. strip(r.zusatz.text)) end end
  realPrint("     " .. strip(sch.wert.text))
end end
Click(f.reiterPlan); RunTimers()
realPrint("--- Planaufträge | " .. strip(f.plan.zahl.text))
for _, k in ipairs(f.plan.karten) do if k.benutzt then
  realPrint("  " .. strip(k.satz.text))
  for _, z in ipairs(k.zeilen) do if z.shown then realPrint(string.format("     %-20s %s", strip(z.name.text), strip(z.info.text))) end end
end end
