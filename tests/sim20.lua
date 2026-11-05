dofile((arg[0]:gsub("sim20%.lua$", "")) .. "stubs.lua")
GetItemInfo = nil
C_Item = { GetItemIconByID = function(id) return "icon" .. id end }
dofile(arg[2])
PLAYER = { name = arg[3] or "Herr", realm = "Classic Beta PvE", faction = "Alliance", class = "WARRIOR", zone = "Eisenschmiede" }
assert(loadfile(arg[1]))()
Fire("PLAYER_LOGIN"); RunTimers()
local d = GuildERPData
local n = 0 for _, p in pairs(d.plans) do n = n + 1 realPrint("Plan: " .. tostring(p.rezeptID) .. " wer=" .. tostring(p.wer)) end
d.settings.ansicht = "plan"
SlashCmdList.GUILDERP(""); RunTimers()
local f = GuildERPFenster
local a = f.plan
local function zeig(t)
  local k = 0 for _, x in ipairs(a.karten) do if x.benutzt then k = k + 1 end end
  local kopf = a.koepfe and a.koepfe[1]
  realPrint(t .. ": zahl='" .. a.zahl.text .. "' leer=" .. tostring(a.leer.shown) .. " '" .. a.leer.text .. "' karten=" .. k
    .. " kopf=" .. tostring(kopf and kopf.benutzt and (kopf.text.text .. " (" .. kopf.zahl.text .. ")")) .. " reiter='" .. f.reiterPlan.text.text .. "'")
end
zeig(PLAYER.name)
if a.koepfe and a.koepfe[1] and a.koepfe[1].benutzt then Click(a.koepfe[1]); RunTimers(); zeig("aufgeklappt"); Click(a.koepfe[1]); RunTimers(); zeig("wieder zu") end
