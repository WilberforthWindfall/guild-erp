-- Standalone (ab 1.4): Guild ERP sammelt Lehrer, Haendler und Beute selbst, ganz ohne Reisefuehrer.
-- lua51 sim23.lua <GuildERP.lua> <GuildERP-SV>
dofile((arg[0]:gsub("sim23%.lua$", "")) .. "stubs.lua")
GetItemInfo = nil
local KLASSE = { [9001] = 9, [9002] = 9, [9003] = 7, [9004] = 9 } -- 9 = Rezept
C_Item = {
    GetItemIconByID = function(id) return "icon" .. id end,
    GetItemInfoInstant = function(link)
        local id = tonumber(string.match(tostring(link), "item:(%d+)"))
        return id, nil, nil, nil, nil, KLASSE[id]
    end,
}
dofile(arg[2])
assert(ForeverDashboardData == nil, "der Test soll ohne Reisefuehrer laufen")
PLAYER = { name = "Barlor", realm = "Classic Beta PvE", faction = "Alliance", class = "PALADIN", zone = "Eisenschmiede" }

-- Lehrer
local LEHRER = {
    { "Rüstung", "header" },
    { "Testrezept Lehrer", nil, "available", req = { "Schmiedekunst", 75 }, kosten = 500 },
    { "Testrezept Beschreibung", "unavailable", nil, tip = "Benötigt Schmiedekunst (90)", kosten = 700 }, -- Art an 2. Stelle
    { "Klassenzauber", nil, "available" },
    { "Testrezept Horde", nil, "available", req = { "Lederverarbeitung", 10 } },
}
function GetNumTrainerServices() return #LEHRER end
function GetTrainerServiceInfo(i) return LEHRER[i][1], LEHRER[i][2], LEHRER[i][3] end
function GetTrainerServiceSkillReq(i) local r = LEHRER[i].req if r then return r[1], r[2] end end
function GetTrainerServiceCost(i) return LEHRER[i].kosten end
local filterGeaendert = false
function SetTrainerServiceTypeFilter() filterGeaendert = true end

-- Haendler und Beute
local NAMEN = { [9001] = "Pläne: Testrezept Händler", [9002] = "Muster: Fremdes Rezept", [9003] = "Waffe: Kein Rezept",
    [9004] = "Pläne: Testrezept Beute" }
local TIP = { [9001] = "Benötigt Schmiedekunst (110)", [9002] = "Requires Lederverarbeitung (20)",
    [9003] = "Benötigt Schmiedekunst (1)", [9004] = "Benötigt Schmiedekunst (125)" }
local function link(id) return "|cffffffff|Hitem:" .. id .. "::|h[" .. NAMEN[id] .. "]|h|r" end
local function tip(id) return { lines = { { leftText = NAMEN[id] }, { leftText = TIP[id] } } } end
local LADEN, BEUTE = { 9001, 9003 }, { 9003, 9004 }
function GetMerchantNumItems() return #LADEN end
function GetMerchantItemLink(i) return link(LADEN[i]) end
function GetMerchantItemInfo(i) return NAMEN[LADEN[i]], "t", 1200, 1 end
function GetNumLootItems() return #BEUTE end
function GetLootSlotLink(i) return link(BEUTE[i]) end
function GetLootSlotInfo(i) return "t", NAMEN[BEUTE[i]] end
function GetLootSourceInfo() return "Creature-0-1-2-3-4-5" end
function UnitGUID(u) return u == "target" and "Creature-0-1-2-3-4-5" or nil end
C_TooltipInfo = {
    GetMerchantItem = function(i) return tip(LADEN[i]) end,
    GetLootItem = function(i) return tip(BEUTE[i]) end,
    GetTrainerService = function(i)
        return { lines = { { leftText = LEHRER[i][1] }, LEHRER[i].tip and { leftText = LEHRER[i].tip } or nil } }
    end,
}
local UnitNameEcht = UnitName
function UnitName(u) if u == "target" then return "Defias-Schmied" end return UnitNameEcht(u) end

assert(loadfile(arg[1]))()
Fire("PLAYER_LOGIN"); RunTimers()
local d = GuildERPData
local function zahl(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
local function eine(rezept)
    assert(d.quellen[rezept], "fehlt: " .. rezept)
    assert(#d.quellen[rezept] == 1, "doppelt: " .. rezept)
    return d.quellen[rezept][1]
end

NPC_NAME, NPC_FACTION = "Testlehrer", "Alliance"
Fire("TRAINER_SHOW"); Fire("TRAINER_UPDATE"); Fire("TRAINER_UPDATE"); RunTimers()
local q = eine("Testrezept Lehrer")
assert(q.art == "Lehrer" and q.wer == "Testlehrer" and q.zone == "Eisenschmiede" and q.kosten == 500 and q.skill == 75
    and q.beruf == "Schmiedekunst" and q.fraktion == "Alliance", "Lehrer-Quelle falsch")
assert(eine("Testrezept Beschreibung").skill == 90, "Fertigkeit aus der Beschreibung fehlt")
assert(not d.quellen["Klassenzauber"], "Klassenzauber darf nicht gemerkt werden")
assert(not d.quellen["Rüstung"], "Ueberschrift darf nicht gemerkt werden")
assert(not filterGeaendert, "Filter im Lehrerfenster darf nicht veraendert werden")

NPC_NAME, NPC_FACTION = "Testhändler", "Alliance"
Fire("MERCHANT_SHOW"); RunTimers()
q = eine("Testrezept Händler")
assert(q.art == "Händler" and q.kosten == 1200 and q.skill == 110, "Haendler-Quelle falsch")
assert(not d.quellen["Kein Rezept"], "nur Rezept-Gegenstaende merken")

NPC_NAME, NPC_FACTION = nil, nil
function UnitIsDead() return true end
Fire("LOOT_OPENED"); RunTimers()
q = eine("Testrezept Beute")
assert(q.art == "Beute" and q.wer == "Defias-Schmied" and q.fraktion == nil and q.skill == 125, "Beute-Quelle falsch")

-- noch einmal alles: nichts wird doppelt, nichts neu gemeldet
local vorher = zahl(d.quellen)
local gemeldet = #printed
NPC_NAME, NPC_FACTION = "Testlehrer", "Alliance"
Fire("TRAINER_SHOW"); RunTimers()
NPC_NAME, NPC_FACTION = nil, nil
Fire("LOOT_OPENED"); RunTimers()
assert(zahl(d.quellen) == vorher, "Wiederholung hat Quellen vermehrt")
eine("Testrezept Lehrer"); eine("Testrezept Beute")
assert(#printed == gemeldet, "Wiederholung hat im Chat gemeldet")

-- Anzeige: alles erscheint unter "Noch nicht gelernt", ohne Reisefuehrer. Horde-Quelle ist unsichtbar.
d.quellen["Testrezept Horde"] = { { art = "Lehrer", wer = "Ork", zone = "Orgrimmar", beruf = "Schmiedekunst", fraktion = "Horde" } }
d.settings.beruf = "Schmiedekunst"
d.settings.grauOffen = true
d.settings.ansicht = nil
d.settings.wunsch = "g:Schmiedekunst:Testrezept Beute"
SlashCmdList.GUILDERP(""); RunTimers()
local f = GuildERPFenster
local kopf
for _, k in ipairs(f.links.koepfe) do
    if k.benutzt and string.find(k.text.text, "Noch nicht gelernt", 1, true) then kopf = k end
end
assert(kopf, "Bereich 'Noch nicht gelernt' fehlt ohne Reisefuehrer")
assert(kopf.rechts.text == "4, Quelle gesehen", "Zahl falsch (Horde darf nicht mitzaehlen): " .. kopf.rechts.text)
local text = f.rechts.lernen.text.text
assert(string.find(text, "Beute: Defias-Schmied", 1, true) and string.find(text, "ab Fertigkeit 125", 1, true),
    "Quelle wird rechts nicht gezeigt: " .. text)

-- Was ein eigener Charakter schon kann, gehoert nicht mehr in die Liste
d.recipes[999001] = { name = "Testrezept Beute", profession = "Schmiedekunst", reagents = {} }
d.characters["Classic Beta PvE-Barlor"].recipes["Schmiedekunst"] = d.characters["Classic Beta PvE-Barlor"].recipes["Schmiedekunst"] or {}
d.characters["Classic Beta PvE-Barlor"].recipes["Schmiedekunst"][999001] = true
d.settings.wunsch = nil
SlashCmdList.GUILDERP(""); SlashCmdList.GUILDERP(""); RunTimers()
for _, k in ipairs(f.links.koepfe) do
    if k.benutzt and string.find(k.text.text, "Noch nicht gelernt", 1, true) then
        assert(k.rechts.text == "3, Quelle gesehen", "gelerntes Rezept steht noch da: " .. k.rechts.text)
    end
end
realPrint("Standalone-Quellen ok: " .. zahl(d.quellen) .. " Rezepte")
