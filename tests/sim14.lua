-- 0.3 mit echten Daten: lua51 sim5.lua <GuildERP.lua> <GuildERP-SV> <FD-SV>
dofile((arg[0]:gsub("sim14%.lua$", "")) .. "stubs.lua")
GetItemInfo = nil
C_Item = { GetItemIconByID = function(id) return "icon" .. id end, GetItemInfoInstant = function(id) return id, "Rüstung", (id % 3 == 0 and "Platte" or id % 3 == 1 and "Kette" or "Handwerkswaren") end }
dofile(arg[2]); if arg[3] ~= "x" then dofile(arg[3]) end
PLAYER = { name = "Barlor", realm = "Classic Beta PvE", faction = "Alliance", class = "PALADIN", zone = "Eisenschmiede" }
local fach = {}
for id, n in pairs(GuildERPData.characters["Classic Beta PvE-Barlor"].bags) do table.insert(fach, { id, n }) end
CONTAINERS = { [0] = fach }
assert(loadfile(arg[1]))()
Fire("PLAYER_LOGIN"); RunTimers()
SlashCmdList.GUILDERP(""); RunTimers()
local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " / ")) end
local f = GuildERPFenster
local L = f.links
local function zeige(t)
  realPrint("=== " .. t)
  local dinge = {}
  for _, k in ipairs(L.koepfe) do if k.benutzt then table.insert(dinge, {0, "KOPF " .. strip(k.text.text) .. " [" .. k.rechts.text .. "]", k}) end end
  for _, k in ipairs(L.gkoepfe or {}) do if k.benutzt then table.insert(dinge, {0, "  GRUPPE " .. k.text.text .. " (" .. k.zahl.text .. ") " .. tostring(k.pfeil.texture), k}) end end
  for _, z in ipairs(L.zeilen) do if z.benutzt then table.insert(dinge, {0, "      " .. strip(z.name.text), z}) end end
  for _, d in ipairs(dinge) do realPrint(d[2]) end
end
Click(L.handwerk); RunTimers()
for _, z in ipairs(GuildERPAuswahl.zeilen) do if z.shown and z.text.text == "Schmiedekunst" then Click(z) end end
RunTimers(); zeige("Schmiedekunst, zu")
for _, k in ipairs(L.gkoepfe) do if k.benutzt and k.text.text == "Platte" then Click(k) end end
RunTimers(); zeige("Platte auf")
L.suche:SetText("kupfer"); if L.suche.scripts and L.suche.scripts.OnTextChanged then L.suche.scripts.OnTextChanged(L.suche, true) end; RunTimers(); zeige("Suche kupfer")
