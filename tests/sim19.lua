dofile((arg[0]:gsub("sim19%.lua$", "")) .. "stubs.lua")
GetItemInfo = nil
C_Item = { GetItemIconByID = function(id) return "icon" .. id end }
dofile(arg[2])
PLAYER = { name = "Barlor", realm = "Classic Beta PvE", faction = "Alliance", class = "PALADIN", zone = "Eisenschmiede" }
assert(loadfile(arg[1]))()
Fire("PLAYER_LOGIN"); RunTimers()
SlashCmdList.GUILDERP(""); RunTimers()
local f = GuildERPFenster
SlashCmdList.GUILDERP("optionen"); RunTimers()
local OF = GuildERPOptionen
local reihe = OF.zeilen[#OF.zeilen]
local function zeig(t) local x = {} for i = 1, 4 do x[i] = reihe.zeilen[i].text.text end realPrint(t .. ": " .. table.concat(x, " | ")) end
zeig("Start")
Click(reihe.zeilen[3].runter); RunTimers(); zeig("Bestellungen runter")
Click(reihe.zeilen[1].hoch); RunTimers(); zeig("1 hoch (geht nicht)")
Click(reihe.zeilen[2].hoch); RunTimers(); zeig("Planaufträge hoch")
realPrint("gespeichert: " .. table.concat(GuildERPData.settings.optionen.reiter, ","))
realPrint("Fensterhöhe Optionen: " .. tostring(OF.h))
