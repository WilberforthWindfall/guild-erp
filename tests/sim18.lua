dofile((arg[0]:gsub("sim18%.lua$", "")) .. "stubs.lua")
GetItemInfo = nil
C_Item = { GetItemIconByID = function(id) return "icon" .. id end }
dofile(arg[2])
PLAYER = { name = "Barlor", realm = "Classic Beta PvE", faction = "Alliance", class = "PALADIN", zone = "Eisenschmiede" }
local PN = { "Schmiedekunst", "Bergbau", nil, "Angeln", "Kochkunst" }
GetProfessions = function() return 1, 2, nil, 4, 5 end
GetProfessionInfo = function(i) return PN[i], "tex", 1, 1, 0, 0, 2900 + i end
assert(loadfile(arg[1]))()
Fire("PLAYER_LOGIN"); RunTimers()
local c = GuildERPData.characters["Classic Beta PvE-Barlor"]
local t = {} for b in pairs(c.recipes) do t[#t+1] = b end table.sort(t)
realPrint("Barlor Berufe nach Login: " .. table.concat(t, ", "))
for _, l in ipairs(printed) do if l:find("entfernt") then realPrint("  Chat: " .. l) end end
-- verlinktes Fenster (anderer Spieler) darf nichts speichern
C_TradeSkillUI.IsTradeSkillLinked = function() return true end
TRADE = { beruf = "Schneiderei", rezepte = { { id = 2387, name = "Leinenhemd", item = 2576, reagents = { { 2996, 1 } } } } }
Fire("TRADE_SKILL_SHOW"); RunTimers()
realPrint("Nach verlinktem Schneiderei-Fenster: Schneiderei bei Barlor = " .. tostring(c.recipes["Schneiderei"] ~= nil) .. " | " .. tostring(GuildERPData.diagnostics.fremdesFenster))
-- eigenes Fenster eines nicht gelernten Hauptberufs (z. B. NPC-Ansicht ohne Kennung)
C_TradeSkillUI.IsTradeSkillLinked = function() return false end
Fire("TRADE_SKILL_SHOW"); RunTimers()
realPrint("Nicht gelernter Hauptberuf: Schneiderei bei Barlor = " .. tostring(c.recipes["Schneiderei"] ~= nil) .. " | " .. tostring(GuildERPData.diagnostics.fremdesFenster))
-- eigenes Schmiedekunst-Fenster wird weiter gelesen
TRADE = { beruf = "Schmiedekunst", rezepte = { { id = 2662, name = "Kupferkettenhose", item = 2852, reagents = { { 2840, 4 } } } } }
Fire("TRADE_SKILL_SHOW"); RunTimers()
local n = 0 for _ in pairs(c.recipes["Schmiedekunst"]) do n = n + 1 end
realPrint("Eigenes Schmiedekunst-Fenster gelesen: " .. n .. " Rezept(e)")
-- Katalog Verzauberkunst: Zwergs Rezepte sichtbar?
SlashCmdList.GUILDERP(""); RunTimers()
local f = GuildERPFenster
GuildERPData.settings.katBeruf = "Verzauberkunst"; GuildERPData.settings.ansicht = "kat"
SlashCmdList.GUILDERP(""); SlashCmdList.GUILDERP(""); RunTimers()
local L = f.kat.links
realPrint("Katalog Verzauberkunst: " .. tostring(L.beruf.text.text) .. " | " .. tostring(L.beruf.rechts.text))
