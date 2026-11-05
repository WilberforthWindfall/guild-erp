-- Zwei Spieler (Barlor, Zwerg Pudel), je eigene Add-on-Instanz und eigene gespeicherte Daten.
-- lua51 sim7.lua <GuildERP.lua> <GuildERP-SV von Barlor>
dofile((arg[0]:gsub("sim8%.lua$", "")) .. "stubs.lua")
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

local fach = {}
for id, n in pairs(svBarlor.characters["Classic Beta PvE-Barlor"].bags) do table.insert(fach, { id, n }) end
local barlor = neueInstanz("Barlor", svBarlor, fach)
-- Pudel hat Schwachen Fluxus (3466) und Rauen Stein (2835) dabei
local pudel = neueInstanz("Zwerg Pudel", nil, { { 2880, 5 }, { 2835, 10 } })
fire(barlor, "PLAYER_LOGIN"); fire(pudel, "PLAYER_LOGIN"); RunTimers()


local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " / ")) end
barlor.env.SlashCmdList.GUILDERP(""); RunTimers()
local f = barlor.env.GuildERPFenster
local d = barlor.env.GuildERPData
local axt
for id, r in pairs(d.recipes) do if r.name == "Kupferstreitaxt" then axt = id end end
d.settings.wunsch = axt; d.settings.menge = 1; d.settings.ansicht = "werk"
barlor.env.SlashCmdList.GUILDERP(""); barlor.env.SlashCmdList.GUILDERP(""); RunTimers()
local function werkstatt(titel)
  realPrint("--- Werkstatt " .. titel)
  local k = f.rechts.karte
  realPrint("  Karte: " .. strip(k.name.text) .. " | Knopf " .. tostring(k.plan.shown and k.plan.text) .. " | Schild: " .. strip(k.schild.text))
  local b = f.rechts.bereit
  local zl = {}
  for _, st in ipairs({"tasche","gruen","blau","gelb","rot"}) do if b.zaehler[st].shown ~= false then table.insert(zl, b.zaehler[st].text) end end
  realPrint("  " .. strip(b.text.text) .. " | " .. table.concat(zl, ", "))
  for _, z in ipairs(f.rechts.zeilen) do if z.shown then
    realPrint(string.format("   %-20s %-8s %s%s", strip(z.name.text), strip(z.zahl.text), z.quelle.shown and strip(z.quelle.text) or "", z.bestellen.shown and "  [Bestellen]" or ""))
  end end
  local h = f.rechts.hinweis
  realPrint("  Kasten: " .. strip(h.text.text) .. " | Knopf: " .. tostring(h.knopf.shown and h.knopf.text))
end
werkstatt("vor Vormerken")
Click(f.rechts.karte.plan); RunTimers()
werkstatt("nach Vormerken")
-- Rest bestellen: alle Grundzutaten
Click(f.rechts.hinweis.knopf); RunTimers()
local s = barlor.env.GuildERPBestellschein
for i, z in ipairs(s.zeilen) do if z.shown then realPrint(string.format("  Schein %d: [%s] %s x%s", i, z.haken.checked and "x" or " ", z.name.text, z.menge.text)) end end
Click(s.senden); RunTimers()
for _, o in pairs(d.orders) do if o.status == "offen" then realPrint("  Bestellung plan=" .. tostring(o.plan)) end end

inGruppe = true
fire(barlor, "GROUP_ROSTER_UPDATE"); fire(pudel, "GROUP_ROSTER_UPDATE"); RunTimers()
-- Pudel sagt zu: Kupfererz 1 per Post, Rauer Stein 2 direkt (nur teilweise)
local po
for _, o in pairs(pudel.env.GuildERPData.orders) do if o.status == "offen" then po = o end end
realPrint("  Pudel hat Bestellung, plan=" .. tostring(po.plan))
pudel.env.GuildERPData.settings = pudel.env.GuildERPData.settings or {}
for _, z in ipairs(po.zeilen) do realPrint("   Zeile " .. z.itemID .. " x" .. z.n) end
-- Zusagen ueber die echte Funktion (gleich wie Knopf)
local function pB() return pudel.env end
local Bp
-- B ist lokal; Zusage via UI
pudel.env.SlashCmdList.GUILDERP(""); RunTimers()
local pf = pudel.env.GuildERPFenster
Click(pf.reiterBest); RunTimers()
local function zusage(itemName, menge, wegText)
  local id = ({ Kupfererz = 2770, ["Rauer Stein"] = 2835 })[itemName]
  for _, sch in ipairs(pf.best.spalten[1].scheine) do if sch.benutzt then for zi, r in ipairs(sch.zeilen) do
    if r.shown and r.k1.shown and po.zeilen[zi] and po.zeilen[zi].itemID == id then
      Click(r.k1); RunTimers()
      local zs = pudel.env.GuildERPZusage
      zs.wert = menge
      -- Menge per Minus-Knopf auf Ziel
      local function zahl() return tonumber((zs.menge.text or "0"):match("%d+")) end
      local guard = 0
      while zahl() > menge and guard < 50 do Click(zs.minus); guard = guard + 1 end
      Click(zs.weg); RunTimers()
      for _, z in ipairs(pudel.env.GuildERPAuswahl.zeilen) do if z.shown and z.text.text == wegText then Click(z) end end
      realPrint("   Pudel sagt zu: " .. zs.menge.text .. " " .. itemName .. ", " .. zs.weg.text.text)
      Click(zs.senden); RunTimers()
      return
    end
  end end end
  realPrint("   !! Zeile nicht gefunden: " .. itemName)
end
for id, n in pairs({}) do end
zusage("Kupfererz", 1, "Per Post")
zusage("Rauer Stein", 2, "Direkt handeln")
Click(f.reiterWerk); RunTimers()
werkstatt("nach Zusagen")
-- Planauftraege-Reiter
Click(f.reiterPlan); RunTimers()
local function plaene(titel)
  realPrint("--- Planaufträge " .. titel .. " | Reiter: " .. strip(f.reiterPlan.text.text) .. " | " .. tostring(f.plan.zahl.text))
  for _, k in ipairs(f.plan.karten) do if k.benutzt then
    realPrint("  " .. strip(k.name.text) .. " | " .. strip(k.unter.text))
    realPrint("  " .. strip(k.satz.text))
    for _, z in ipairs(k.zeilen) do if z.shown then
      realPrint(string.format("     %-20s %-8s %s", strip(z.name.text), strip(z.zahl.text), strip(z.info.text)))
    end end
  end end
end
plaene("aufgeklappt")
-- Unter-Zutat zuklappen (Kupferbarren)
for _, z in ipairs(f.plan.karten[1].zeilen) do if z.shown and z.schluessel and strip(z.name.text) == "Kupferbarren" then Click(z) end end
RunTimers()
plaene("Kupferbarren zugeklappt")
for _, z in ipairs(f.plan.karten[1].zeilen) do if z.shown and z.schluessel and strip(z.name.text) == "Kupferbarren" then Click(z) end end
RunTimers()
-- Auftragsnetz
Click(f.plan.karten[1].netz); RunTimers()
local n = barlor.env.GuildERPNetz
realPrint("--- Auftragsnetz: " .. strip(n.unter.text) .. " shown=" .. tostring(n.shown))
for _, k in ipairs(n.kacheln) do if k.benutzt then
  local p = k.points and k.points[#k.points]; if p and p.x then p = {nil,nil,nil,p.x,p.y} end
  realPrint(string.format("  [%s,%s] h=%s %-20s %-8s %s", tostring(p and p[4]), tostring(p and p[5]), tostring(k.h), strip(k.name.text), strip(k.zahl.text), strip(k.info.text)))
end end
local zs = 0 for _, s in ipairs(n.striche) do if s.benutzt then zs = zs + 1 end end
realPrint("  Linien: " .. zs)
Click(n.werkstatt); RunTimers()
realPrint("  nach Werkstatt-Knopf: Netz shown=" .. tostring(n.shown) .. " ansicht=" .. d.settings.ansicht)
Click(f.reiterPlan); RunTimers()
Click(f.plan.karten[1].kopf); RunTimers()
plaene("zugeklappt")
-- Pudel liefert Kupfererz -> blau verschwindet (zaehlt erst, wenn in der Tasche)
Click(pf.reiterBest); RunTimers()
for _, sch in ipairs(pf.best.spalten[1].scheine) do if sch.benutzt then for zi2, r in ipairs(sch.zeilen) do
  if r.shown and r.k2.shown and po.zeilen[zi2] and po.zeilen[zi2].itemID == 2770 then Click(r.k2) end end end end
RunTimers()
Click(f.plan.karten[1].werkstatt); RunTimers()
werkstatt("nach Lieferung Kupfererz, über 'In der Werkstatt öffnen'")
-- Rest bestellen nochmal
local h = f.rechts.hinweis
if h.knopf.shown then Click(h.knopf); RunTimers()
  for i, z in ipairs(s.zeilen) do if z.shown then realPrint(string.format("  Schein2 %d: [%s] %s x%s", i, z.haken.checked and "x" or " ", z.name.text, z.menge.text)) end end
  s:Hide()
end
-- Erledigt
Click(f.rechts.karte.plan); RunTimers()
werkstatt("nach Erledigt")
Click(f.reiterPlan); RunTimers()
realPrint("Plan-Leer: " .. tostring(f.plan.leer.shown) .. " | Reiter: " .. strip(f.reiterPlan.text.text))
