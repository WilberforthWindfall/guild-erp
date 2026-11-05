dofile((arg[0]:gsub("sim6%.lua$", "")) .. "stubs.lua")
GetItemInfo = nil
C_Item = { GetItemIconByID = function(id) return "icon" .. id end }
dofile(arg[2])
PLAYER = { name = "Barlor", realm = "Classic Beta PvE", faction = "Alliance", class = "PALADIN", zone = "Eisenschmiede" }
local fach = {}
for id, n in pairs(GuildERPData.characters["Classic Beta PvE-Barlor"].bags) do table.insert(fach, { id, n }) end
CONTAINERS = { [0] = fach }
assert(loadfile(arg[1]))()
Fire("PLAYER_LOGIN"); RunTimers()
SlashCmdList.GUILDERP(""); RunTimers()
local f = GuildERPFenster
local L, R = f.links, f.rechts
Click(L.handwerk); RunTimers()
for _, z in ipairs(GuildERPAuswahl.zeilen) do if z.shown and z.text.text == "Schmiedekunst" then Click(z) end end
RunTimers()
for _, z in ipairs(L.zeilen) do if z.benutzt and z.name.text:find("Raue bronzene Gamaschen") then Click(z) end end
RunTimers(); Click(R.auftrag.plus); RunTimers()
realPrint("Menge " .. R.auftrag.menge.text .. " | Kasten: " .. R.hinweis.text.text:gsub("\n", " / ") .. " | Knopf sichtbar: " .. tostring(R.hinweis.knopf.shown))
-- Klassisches Berufefenster nachbilden (noch zu)
TradeSkillFrame = CreateFrame("Frame"); TradeSkillFrame:Hide()
local liste = { { "Rüstung", "header" }, { "Kupferner Kettengürtel", "easy" }, { "Raue bronzene Gamaschen", "medium" } }
function GetNumTradeSkills() return #liste end
function GetTradeSkillInfo(i) return liste[i][1], liste[i][2] end
local gewaehlt; function TradeSkillFrame_SetSelection(i) gewaehlt = i end
TradeSkillInputBox = CreateFrame("EditBox"); local zahl; TradeSkillInputBox.SetNumber = function(self, n) zahl = n end
Click(R.hinweis.knopf); RunTimers()
for _, p in ipairs(printed) do if p:find("Öffne jetzt") then realPrint("CHAT: " .. p) end end
-- Spieler oeffnet das Fenster selbst
TradeSkillFrame:Show(); Fire("TRADE_SKILL_SHOW"); RunTimers()
realPrint("Gewählt: " .. tostring(gewaehlt) .. " (erwartet 3), Anzahl: " .. tostring(zahl) .. " (erwartet 2)")
realPrint("Diagnose: " .. tostring(GuildERPData.diagnostics.berufefenster))
-- Moderner Weg: OpenRecipe vorhanden und Fenster oeffnet sich
TradeSkillFrame:Hide(); gewaehlt, zahl = nil, nil
ProfessionsFrame = CreateFrame("Frame"); ProfessionsFrame:Hide()
local box = CreateFrame("EditBox"); local wert; box.SetValue = function(self, v) wert = v end
ProfessionsFrame.CraftingPage = { CreateMultipleInputBox = box }
local geoeffnet; C_TradeSkillUI.OpenRecipe = function(id) geoeffnet = id; ProfessionsFrame:Show() end
Click(R.hinweis.knopf); RunTimers()
realPrint("Modern: OpenRecipe(" .. tostring(geoeffnet) .. "), Anzahl-Feld: " .. tostring(wert) .. " | " .. tostring(GuildERPData.diagnostics.berufefenster))
