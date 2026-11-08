-- 1.6.2 Planauftrag: Herstellen, mit Bestellung verknuepfen, Geliefert, erledigt; Rezeptbuch herstellbar
-- lua51 sim29.lua <GuildERP.lua> <GuildERP-SV von Barlor>
dofile((arg[0]:gsub("sim29%.lua$", "")) .. "stubs.lua")
GetItemInfo = nil
C_Item = { GetItemIconByID = function(id) return "icon" .. id end }
dofile(arg[2])
local svBarlor = GuildERPData
GuildERPData = nil

local inst = {}
local inGruppe = false
local function neueInstanz(name, sv, taschen)
    local env = setmetatable({}, { __index = _G })
    env.GuildERPData = sv
    env.SlashCmdList = {}
    env.UISpecialFrames = {}
    env.UnitName = function(u)
        if u == "player" then return name end
        if u == "party1" then return name == "Barlor" and "Zwerg Pudel" or "Barlor" end
    end
    env.GetRealmName = function() return "Classic Beta PvE" end
    env.UnitFactionGroup = function() return "Alliance" end
    env.IsInGroup = function() return inGruppe end
    env.IsInRaid = function() return false end
    env.GetNumGroupMembers = function() return inGruppe and 1 or 0 end
    env.Ambiguate = function(n) return n end
    env.C_Container = {
        GetContainerNumSlots = function(b) return b == 0 and #taschen or 0 end,
        GetContainerItemInfo = function(b, s) local e = taschen[s]; if b == 0 and e then return { itemID = e[1], stackCount = e[2] } end end,
    }
    local erster
    env.CreateFrame = function(...)
        local fr = CreateFrame(...)
        local _, nm = ...
        if nm then env[nm] = fr end
        erster = erster or fr
        return fr
    end
    env.print = function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end realPrint("  [" .. name .. "] " .. table.concat(t, " ")) end
    env.C_ChatInfo = {
        RegisterAddonMessagePrefix = function() return true end,
        SendAddonMessage = function(prefix, text, kanal)
            assert(#text <= 255, "Nachricht zu lang: " .. #text)
            for _, andere in ipairs(inst) do
                if andere.name ~= name and inGruppe then
                    andere.frame.scripts.OnEvent(andere.frame, "CHAT_MSG_ADDON", prefix, text, kanal, name)
                end
            end
            return 0
        end,
    }
    local chunk = assert(loadfile(arg[1]))
    setfenv(chunk, env)
    chunk()
    local i = { name = name, env = env, frame = erster }
    table.insert(inst, i)
    return i
end
local function fire(i, ev, ...) i.frame.scripts.OnEvent(i.frame, ev, ...) end
local fehler = 0
local function pruefe(ok, text)
  if ok then realPrint("  ok: " .. text) else fehler = fehler + 1; realPrint("  FALSCH: " .. text) end
end
local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " / ")) end

-- Rezept, das Barlor kennt
local c = svBarlor.characters["Classic Beta PvE-Barlor"]
local rid, beruf
for b, ids in pairs(c.recipes or {}) do for id in pairs(ids) do
  local r = svBarlor.recipes[id]
  if r and r.reagents and r.itemID and r.name == "Kupferrute" then rid, beruf = id, b end end end
local r = svBarlor.recipes[rid]
realPrint("  Rezept: " .. r.name .. " (" .. rid .. "), Zutaten " .. #r.reagents)
-- Taschen: genug fuer 2, Bank fuer 1 weitere
c.bags, c.bank = {}, {}
for _, z in ipairs(r.reagents) do c.bags[z.itemID] = z.count * 2; c.bank[z.itemID] = z.count end
-- Bestellung von Pudel an die Gruppe, schon empfangen
svBarlor.orders = {}
svBarlor.orders["Zwerg-1-1"] = { id = "Zwerg-1-1", von = "Zwerg Pudel", an = "", fuer = "", notiz = "", at = 1000,
  kopfRev = 1000, status = "offen", zeilen = { { itemID = r.itemID, rezeptID = rid, n = 2, zusagen = {} } } }
svBarlor.plans = { [rid] = { id = "Barlor-P1", rezeptID = rid, menge = 1, wer = "Barlor", at = 1000, fuer = {} } }
svBarlor.settings.ansicht = "plan"
local tasche = {}
for id, n in pairs(c.bags) do table.insert(tasche, { id, n }) end
local barlor = neueInstanz("Barlor", svBarlor, tasche)
fire(barlor, "PLAYER_LOGIN"); RunTimers()
local d = barlor.env.GuildERPData
barlor.env.SlashCmdList.GUILDERP(""); RunTimers()
local f = barlor.env.GuildERPFenster
Click(f.reiterPlan); RunTimers()
local function karte()
  for _, k in ipairs(f.plan.karten) do if k.benutzt and k.shown then return k end end
end
local k = karte()
pruefe(k and k.machen.shown, "Knopf Herstellen da: " .. tostring(k and k.machen.text))
pruefe(k and k.fuerBox.shown and k.fuerBox.wahl.shown, "Auswahl 'Mit Bestellung verknüpfen' da")
Click(k.fuerBox.wahl); RunTimers()
local eintrag
for _, z in ipairs(barlor.env.GuildERPAuswahl.zeilen) do if z.shown and strip(z.text.text):find("Kupferrute", 1, true) then eintrag = z end end
pruefe(eintrag ~= nil, "Pudels Bestellung in der Auswahl")
Click(eintrag); RunTimers()
local plan = d.plans[rid]
local o = d.orders["Zwerg-1-1"]
pruefe(plan.fuer["Zwerg-1-1"] and plan.menge == 3, "verknüpft, Menge jetzt " .. tostring(plan.menge))
local mz
for wer, s in pairs(o.zeilen[1].zusagen) do mz = s end
pruefe(mz and mz.n == 2 and not mz.g, "Zusage 2 bei der Bestellung")
k = karte()
pruefe(k.machen.text == "Herstellen (3×)", "Knopf: " .. tostring(k.machen.text))
local zeile = k.fuerBox.zeilen[1]
realPrint("  Zeile: " .. strip(zeile.text.text) .. " | " .. strip(zeile.unter.text))
pruefe(zeile.shown and zeile.knopf.shown, "Knopf Geliefert da")
pruefe(not k.fuerBox.wahl.shown, "keine weitere Bestellung zum Verknüpfen")
Click(zeile.knopf); RunTimers()
for wer, s in pairs(o.zeilen[1].zusagen) do mz = s end
pruefe(mz.g, "als geliefert vermerkt")
k = karte()
pruefe(k.fuerBox.fertig.shown, "Knopf 'Planauftrag erledigt' da")
Click(k.fuerBox.fertig); RunTimers()
pruefe(d.plans[rid] == nil, "Planauftrag erledigt")

-- Rezeptbuch: herstellbar 2 (3)
d.settings.ansicht = "werk"; d.settings.wunsch = rid; d.settings.beruf = beruf; d.settings.zu = {}
barlor.env.SlashCmdList.GUILDERP(""); barlor.env.SlashCmdList.GUILDERP(""); RunTimers()
local rechts
for _, z in ipairs(f.links.zeilen) do if z.shown and strip(z.name.text) == r.name then rechts = strip(z.rechts.text); realPrint("  Tip: " .. strip(z.tip)) end end
local soll = (2 * (r.numMade or 1)) .. " (" .. (3 * (r.numMade or 1)) .. ")"
pruefe(rechts and rechts:find(soll, 1, true) == 1, "Rezeptbuch rechts: " .. tostring(rechts) .. " (soll " .. soll .. ")")
realPrint("Fehler: " .. fehler)
if fehler > 0 then os.exit(1) end
