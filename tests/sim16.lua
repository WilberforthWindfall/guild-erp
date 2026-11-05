-- 0.3 mit echten Daten: lua51 sim5.lua <GuildERP.lua> <GuildERP-SV> <FD-SV>
dofile((arg[0]:gsub("sim16%.lua$", "")) .. "stubs.lua")
GetItemInfo = nil
C_Item = { GetItemIconByID = function(id) return "icon" .. id end }
dofile(arg[2]); if arg[3] ~= "x" then dofile(arg[3]) end
PLAYER = { name = "Barlor", realm = "Classic Beta PvE", faction = "Alliance", class = "PALADIN", zone = "Eisenschmiede" }
local fach = {}
for id, n in pairs(GuildERPData.characters["Classic Beta PvE-Barlor"].bags) do table.insert(fach, { id, n }) end
CONTAINERS = { [0] = fach }
assert(loadfile(arg[1]))()
Fire("PLAYER_LOGIN"); RunTimers()
SlashCmdList.GUILDERP(""); RunTimers()
local tf = CreateFrame("Frame", "TradeSkillFrame")
local t1 = tf:CreateTexture(nil, "BACKGROUND"); t1.GetAtlas = function() return "Professions-Header" end
local kid = CreateFrame("Frame", "TradeSkillFrameKopf", tf)
local fs = kid:CreateFontString(nil, "OVERLAY", "GameFontNormal"); fs:SetText("Waffensteine")
tf.GetRegions = function() return t1 end
tf.GetChildren = function() return kid end
kid.GetRegions = function() return fs end
kid.GetChildren = function() end
t1.GetObjectType = function() return "Texture" end
fs.GetObjectType = function() return "FontString" end
SlashCmdList.GUILDERP("optik"); RunTimers()
local o = GuildERPData.diagnostics.optik
realPrint("fenster=" .. o.fenster .. " teile=" .. #o.teile)
for _, e in ipairs(o.teile) do local t = {} for k, v in pairs(e) do t[#t+1] = k .. "=" .. tostring(v) end table.sort(t) realPrint("  " .. table.concat(t, " ")) end
