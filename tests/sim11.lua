-- Zwei Spieler (Barlor, Zwerg Pudel), je eigene Add-on-Instanz und eigene gespeicherte Daten.
-- lua51 sim10.lua <GuildERP.lua neu> <SV Barlor> <GuildERP.lua fuer Pudel>
dofile((arg[0]:gsub("sim11%.lua$", "")) .. "stubs.lua")
GetItemInfo = nil
C_Item = { GetItemIconByID = function(id) return "icon" .. id end }
dofile(arg[2])
local svBarlor = GuildERPData
GuildERPData = nil

local inst = {}
local inGruppe = false
local function neueInstanz(name, sv, taschen, datei)
    local env = setmetatable({}, { __index = _G })
    env.GuildERPData = sv
    env.SlashCmdList = {}
    env.UISpecialFrames = {}
    env.UnitName = function(u)
        if u == "player" then return name end
        if u == "party1" then return name == "Barlor" and "Zwerg" or "Barlor" end
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
            local art = text:sub(1, 1)
            ZAEHL[name .. ":" .. art] = (ZAEHL[name .. ":" .. art] or 0) + 1
            for _, andere in ipairs(inst) do
                if inGruppe then
                    andere.frame.scripts.OnEvent(andere.frame, "CHAT_MSG_ADDON", prefix, text, kanal, name .. (name == "Barlor" and " Rostbart" or " Pudelmuetze") .. "-ClassicBetaPvE")
                end
            end
            return 0
        end,
    }
    local chunk = assert(loadfile(datei or arg[1]))
    setfenv(chunk, env)
    chunk()
    local i = { name = name, env = env, frame = erster }
    table.insert(inst, i)
    return i
end
local function fire(i, ev, ...) i.frame.scripts.OnEvent(i.frame, ev, ...) end


ZAEHL = {}
C_Spell = { GetSpellName = function(id) return ({ [7457] = "Armschiene - Geringe Ausdauer", [7418] = "Armschiene - Geringe Gesundheit", [7771] = "Umhang - Geringer Schutz" })[id] end }
local fach = {}
for id, n in pairs(svBarlor.characters["Classic Beta PvE-Barlor"].bags) do table.insert(fach, { id, n }) end
local barlor = neueInstanz("Barlor", svBarlor, fach)
local svPudel = { characters = { ["Classic Beta PvE-Zwerg"] = { name = "Zwerg", faction = "Alliance",
    recipes = { ["Verzauberkunst"] = { [7457] = true, [7418] = true }, ["Schneiderei"] = { [2387] = true } } } },
  recipes = { [7457] = { name = "Armschiene - Geringe Ausdauer", profession = "Verzauberkunst", reagents = { { itemID = 10940, count = 2 }, { itemID = 10938, count = 1 } } },
              [7418] = { name = "Armschiene - Geringe Gesundheit", profession = "Verzauberkunst", reagents = { { itemID = 10940, count = 1 } } },
              [2387] = { name = "Leinenhemd", profession = "Schneiderei", itemID = 2576, reagents = { { itemID = 2996, count = 1 } } } } }
local pudel = neueInstanz("Zwerg", svPudel, { { 10940, 3 } }, arg[3])
fire(barlor, "PLAYER_LOGIN"); fire(pudel, "PLAYER_LOGIN"); RunTimers()
-- Barlor bestellt offline etwas
barlor.env.SlashCmdList.GUILDERP(""); RunTimers()
local f = barlor.env.GuildERPFenster
local d = barlor.env.GuildERPData
for id, r in pairs(d.recipes) do if r.name == "Kupferstreitaxt" then d.settings.wunsch = id end end
d.settings.menge = 1; d.settings.ansicht = "werk"
barlor.env.SlashCmdList.GUILDERP(""); barlor.env.SlashCmdList.GUILDERP(""); RunTimers()
Click(f.rechts.hinweis.knopf); RunTimers(); Click(barlor.env.GuildERPBestellschein.senden); RunTimers()
realPrint("=== Gruppe bilden")
inGruppe = true
fire(barlor, "GROUP_ROSTER_UPDATE"); fire(pudel, "GROUP_ROSTER_UPDATE"); RunTimers(); RunTimers()

local function strip(t) return (tostring(t or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " / ")) end
local function voll(i) local c for k, v in pairs(i.env.GuildERPData.characters) do if v.name == i.name then c = v end end return c and c.voll end
realPrint("Volle Namen gelernt: Barlor=" .. tostring(voll(barlor)) .. "  Zwerg=" .. tostring(voll(pudel)))
local pd = pudel.env.GuildERPData
realPrint("Barlor kennt Katalog von: " .. table.concat((function() local t = {} for n in pairs(d.fremd) do t[#t+1] = n end return t end)(), ", "))
-- Barlor bestellt aus dem Katalog
Click(f.reiterKat); RunTimers()
local Kt = f.kat
d.settings.katBeruf = "Verzauberkunst"; d.settings.katRezept = 7457
Click(f.reiterKat); RunTimers()
local F = Kt.rechts.form
realPrint("--- Bestellfeld: an=" .. strip(F.an.text.text) .. " | Zutaten=" .. strip(F.mats.text.text) .. " | " .. strip(F.hinweis.text))
Click(F.an); RunTimers()
for _, z in ipairs(barlor.env.GuildERPAuswahl.zeilen) do if z.shown then realPrint("   Bei wem: " .. strip(z.text.text) .. " | " .. strip(z.rechts.text)) end end
barlor.env.GuildERPAuswahl:Hide()
F.notiz:SetText("für meinen Paladin")
Click(F.knopf); RunTimers(); RunTimers()
realPrint("Ansicht nach Bestellen: " .. d.settings.ansicht)
for _, sch in ipairs(f.best.spalten[2].scheine) do if sch.benutzt then
  realPrint("  Barlor: " .. strip(sch.titel.text) .. " / " .. strip(sch.unter.text))
  for _, r in ipairs(sch.zeilen) do if r.shown then realPrint("     " .. strip(r.text.text) .. " | " .. strip(r.chip.text) .. " | " .. strip(r.zusatz.text)) end end
end end
-- bei Zwerg: Popup
local H = pudel.env.GuildERPHinweis
realPrint("--- Popup bei Zwerg: " .. (H and H.shown and (strip(H.titel.text) .. " | " .. strip(H.text.text) .. " | " .. strip(H.unter.text)) or "KEINS"))
Click(H.ansehen); RunTimers()
local pf = pudel.env.GuildERPFenster
local liefer
for _, sch in ipairs(pf.best.spalten[1].scheine) do if sch.benutzt then
  realPrint("  Zwerg sieht: " .. strip(sch.titel.text) .. " / " .. strip(sch.unter.text) .. " | Fuss: " .. strip(sch.fuss.text))
  for _, r in ipairs(sch.zeilen) do if r.shown then
    realPrint("     " .. strip(r.text.text) .. " | " .. strip(r.chip.text) .. " | " .. strip(r.zusatz.text) .. (r.k1.shown and (" [" .. r.k1.text .. "]") or ""))
    if r.k1.shown then liefer = r.k1 end
  end end
end end
Click(liefer); RunTimers()
local zs = pudel.env.GuildERPZusage
realPrint("  Zusage-Fenster: " .. strip(zs.frage.text) .. " | Weg " .. zs.weg.text.text .. " | Plan-Haken " .. tostring(zs.plan.shown) .. "/" .. tostring(zs.plan:GetChecked()) .. " | " .. strip(zs.planUnter.text))
Click(zs.senden); RunTimers(); RunTimers()
-- Zwerg: Planauftrag
Click(pf.reiterPlan); RunTimers()
for _, k in ipairs(pf.plan.karten) do if k.benutzt then
  realPrint("--- Zwerg Plan: " .. strip(k.name.text) .. " | " .. strip(k.unter.text) .. " | " .. strip(k.satz.text))
  for _, z in ipairs(k.zeilen) do if z.shown then realPrint("     " .. strip(z.name.text) .. " " .. strip(z.zahl.text) .. " | " .. strip(z.info.text)) end end
end end
-- Barlor sieht Zusage
Click(f.reiterBest); RunTimers()
for _, sch in ipairs(f.best.spalten[2].scheine) do if sch.benutzt then
  for _, r in ipairs(sch.zeilen) do if r.shown then realPrint("  Barlor sieht: " .. strip(r.text.text) .. " | " .. strip(r.chip.text) .. " | " .. strip(r.zusatz.text)) end end
end end
-- Zwerg storniert den Planauftrag
realPrint("=== Zwerg storniert Planauftrag")
Click(pf.reiterPlan); RunTimers()
Click(pf.plan.karten[1].storno); RunTimers()
local W = pudel.env.GuildERPStorno
realPrint("  Dialog: " .. strip(W.titel.text) .. " | " .. strip(W.unter.text))
for _, p in ipairs(W.punkte) do if p.shown then realPrint("   [" .. (p:GetChecked() and "x" or " ") .. "] " .. strip(p.text.text) .. " -- " .. strip(p.unter.text)) end end
for _, t in ipairs(W.infos) do if t.shown then realPrint("   " .. strip(t.text)) end end
Click(W.ok); RunTimers(); RunTimers()
local BH = barlor.env.GuildERPHinweis
realPrint("  Popup bei Barlor: " .. (BH and BH.shown and (strip(BH.titel.text) .. " | " .. strip(BH.text.text) .. " | " .. strip(BH.unter.text)) or "KEINS"))
local np = 0 for _ in pairs(pd.plans) do np = np + 1 end
realPrint("  Zwerg hat noch Planaufträge: " .. np)
-- nochmal zusagen, dann storniert Barlor
realPrint("=== Zwerg sagt erneut zu, Barlor storniert die Bestellung")
Click(pf.reiterBest); RunTimers()
for _, sch in ipairs(pf.best.spalten[1].scheine) do if sch.benutzt then for _, r in ipairs(sch.zeilen) do if r.shown and r.k1.shown then Click(r.k1) end end end end
RunTimers(); Click(zs.senden); RunTimers(); RunTimers()
Click(f.reiterBest); RunTimers()
for _, sch in ipairs(f.best.spalten[2].scheine) do if sch.benutzt then Click(sch.k2) end end
RunTimers()
realPrint("  Dialog Barlor: " .. strip(barlor.env.GuildERPStorno.titel.text))
for _, p in ipairs(barlor.env.GuildERPStorno.punkte) do if p.shown then realPrint("   [" .. (p:GetChecked() and "x" or " ") .. "] " .. strip(p.text.text) .. " -- " .. strip(p.unter.text)) end end
Click(barlor.env.GuildERPStorno.ok); RunTimers(); RunTimers()
realPrint("  Popup bei Zwerg: " .. (H.shown and (strip(H.titel.text) .. " | " .. strip(H.text.text) .. " | " .. strip(H.unter.text)) or "KEINS"))
Click(pf.reiterBest); RunTimers()
for _, sch in ipairs(pf.best.spalten[1].scheine) do if sch.benutzt then
  realPrint("  Zwerg sieht: " .. strip(sch.titel.text) .. " | Fuss: " .. strip(sch.fuss.text) .. " | Knopf " .. tostring(sch.k1.shown and sch.k1.text))
  for _, r in ipairs(sch.zeilen) do if r.shown then realPrint("     " .. strip(r.text.text) .. " | " .. strip(r.chip.text) .. " | " .. strip(r.zusatz.text)) end end
end end
Click(pf.reiterPlan); RunTimers()
local k = pf.plan.karten[1]
realPrint("  Plan-Banner bei Zwerg: " .. tostring(k.banner.shown) .. " | " .. strip(k.banner.text.text))
Click(k.banner.behalten); RunTimers()
realPrint("  nach Behalten: Banner " .. tostring(pf.plan.karten[1].banner.shown) .. " | " .. strip(pf.plan.karten[1].unter.text))
-- Tooltip-Test Bestellzeile
GameTooltip = CreateFrame("Frame", "GameTooltip"); local tt = {}
GameTooltip.SetOwner = function() tt = {} end; GameTooltip.AddLine = function(_, t) table.insert(tt, t) end
GameTooltip.SetHyperlink = function(_, l) table.insert(tt, "LINK " .. l) end
GameTooltip.SetSpellByID = function(_, id) table.insert(tt, "SPELL " .. id) end
GameTooltip.Show = function() end
pudel.env.GameTooltip = GameTooltip
Click(pf.reiterBest); RunTimers()
for _, sch in ipairs(pf.best.spalten[1].scheine) do if sch.benutzt then for _, r in ipairs(sch.zeilen) do if r.shown then
  r.scripts.OnEnter(r); realPrint("  Tooltip " .. strip(r.text.text) .. ": " .. table.concat(tt, " | "))
end end end end
