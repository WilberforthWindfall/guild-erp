dofile((arg[0]:gsub("sim21%.lua$", "")) .. "stubs.lua")
GetItemInfo = nil
C_Item = { GetItemIconByID = function(id) return "icon" .. id end }
dofile(arg[2])
local d = GuildERPData
d.characters["Classic Beta PvE-Ork"] = { name = "Ork", voll = "Ork Grimm", faction = "Horde", recipes = { ["Alchemie"] = { [2330] = true } } }
d.recipes[2330] = { name = "Schwacher Heiltrank", profession = "Alchemie", itemID = 118, reagents = {} }
d.plans[2330] = { id = "Ork-P1", rezeptID = 2330, menge = 2, wer = "Ork", at = 1 }
PLAYER = { name = "Herr", realm = "Classic Beta PvE", faction = "Alliance", class = "WARRIOR", zone = "Eisenschmiede" }
assert(loadfile(arg[1]))()
Fire("PLAYER_LOGIN"); RunTimers()
d.settings.ansicht = "plan"; SlashCmdList.GUILDERP(""); RunTimers()
local f = GuildERPFenster
realPrint("Allianz/Herr Plan-Übersicht: " .. f.plan.zahl.text)
d.settings.ansicht = "kat"; d.settings.katBeruf = "Alchemie"; SlashCmdList.GUILDERP(""); SlashCmdList.GUILDERP(""); RunTimers()
realPrint("Allianz Katalog Beruf: " .. tostring(f.kat.links.beruf.text.text))
