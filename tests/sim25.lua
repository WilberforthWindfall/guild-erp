-- Fehlerschutz (ab 1.4): Fehler werden gesammelt statt ein Fehlerfenster zu oeffnen.
-- lua51 sim25.lua <GuildERP.lua> <GuildERP-SV>
dofile((arg[0]:gsub("sim25%.lua$", "")) .. "stubs.lua")
GERP_STRENG = false -- hier wollen wir das Verhalten bei den Spielern sehen
GetItemInfo = nil
C_Item = { GetItemIconByID = function(id) return "icon" .. id end }
dofile(arg[2])
PLAYER = { name = "Barlor", realm = "Classic Beta PvE", faction = "Alliance", class = "PALADIN", zone = "Eisenschmiede" }
local d = GuildERPData
d.diagnostics = d.diagnostics or {}
d.diagnostics.fehler = { { ort = "alt", text = "aus alter Version", n = 1, at = 1, version = "1.3" } }
d.diagnostics.fehlerVersion = "1.3"
assert(loadfile(arg[1]))()
Fire("PLAYER_LOGIN"); RunTimers()
assert(d.diagnostics.fehler == nil, "Fehler aelterer Versionen muessen beim Start verschwinden")

local function fehler() return d.diagnostics.fehler or {} end
local function chat(text)
    local n = 0
    for _, t in ipairs(printed) do
        if string.find(t, text, 1, true) then n = n + 1 end
    end
    return n
end

-- Fehler im Ereignis: kommt nicht beim Spiel an, wird gesammelt
local echt = GetMerchantNumItems
GetMerchantNumItems = function() error("kaputter Haendler") end
Fire("MERCHANT_SHOW"); RunTimers() -- Zeitgeber
assert(#fehler() >= 1, "Fehler im Zeitgeber nicht gesammelt")
assert(string.find(fehler()[1].text, "kaputter Haendler", 1, true), "Text fehlt: " .. tostring(fehler()[1].text))
assert(chat("Kleiner Fehler im Add-on") == 1, "Hinweis im Chat fehlt")
Fire("MERCHANT_SHOW"); RunTimers()
assert(chat("Kleiner Fehler im Add-on") == 1, "Hinweis darf pro Sitzung nur einmal kommen")
local summe = 0
for _, e in ipairs(fehler()) do
    summe = summe + e.n
    assert(e.version and e.at, "Eintrag unvollstaendig")
end
assert(#fehler() <= 2 and summe >= 2, "gleiche Fehler zaehlen statt vermehren")
GetMerchantNumItems = echt

-- Fehler im Befehl und im Klick
local strtrimEcht = strtrim
strtrim = function() error("kaputter Befehl") end
SlashCmdList.GUILDERP("") -- darf nicht durchschlagen
strtrim = strtrimEcht
local gefunden = false
for _, e in ipairs(fehler()) do
    if e.ort == "Befehl" then gefunden = true end
end
assert(gefunden, "Fehler im Befehl nicht gesammelt")

SlashCmdList.GUILDERP(""); RunTimers()
local f = GuildERPFenster
assert(f and f.scripts, "Fenster fehlt")
local knopf = f.links.handwerk
local alt = knopf.scripts.OnClick
assert(alt, "Knopf ohne Klick")
Click(knopf) -- normaler Klick geht weiter
RunTimers()
knopf:SetScript("OnClick", function() error("kaputter Klick") end)
Click(knopf)
gefunden = false
for _, e in ipairs(fehler()) do
    if string.find(e.text, "kaputter Klick", 1, true) then gefunden = (e.ort == "OnClick") end
end
assert(gefunden, "Fehler im Klick nicht gesammelt")

-- die Liste bleibt begrenzt
for i = 1, 40 do
    knopf:SetScript("OnClick", function() error("Fehler Nummer " .. i) end)
    Click(knopf)
end
assert(#fehler() == 20, "Liste nicht begrenzt: " .. #fehler())
assert(string.find(fehler()[20].text, "Fehler Nummer 40", 1, true), "neueste Fehler muessen bleiben")

-- /gerp info zeigt sie, und das Add-on arbeitet danach normal weiter
SlashCmdList.GUILDERP("info")
assert(chat("Fehler seit dieser Version: 20") == 1, "/gerp info zeigt die Fehler nicht")
assert(chat("Fehler Nummer 40") >= 1, "/gerp info zeigt den neuesten Fehler nicht")
d.settings.beruf = nil
SlashCmdList.GUILDERP(""); SlashCmdList.GUILDERP(""); RunTimers()
assert(f.shown, "Fenster reagiert nicht mehr")
realPrint("Fehlerschutz ok")
