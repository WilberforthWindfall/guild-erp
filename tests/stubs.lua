-- Minimal-Attrappe der WoW-Schnittstelle fuer Tests (Lua 5.1)
local timers = {}
C_Timer = { After = function(t, fn) table.insert(timers, fn) end }
function RunTimers()
    local n = 0
    while #timers > 0 and n < 500 do
        local fn = table.remove(timers, 1)
        fn()
        n = n + 1
    end
end
function time() return 1792200000 + (NOW_OFFSET or 0) end
date = os.date
strtrim = function(s) return (string.gsub(s, "^%s*(.-)%s*$", "%1")) end
printed = {}
local realprint = print
print = function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end table.insert(printed, table.concat(t, " ")) end
realPrint = realprint

UISpecialFrames = {}
UIParent = {}
SlashCmdList = {}
BackdropTemplateMixin = {}

local function newObj(kind)
    local o = { kind = kind, shown = true, scripts = {}, points = {}, w = 0, h = 0, text = "" }
    local mt = {}
    mt.__index = function(t, k)
        if type(k) ~= "string" or not k:match("^%u") then return nil end
        return function(self, ...)
            local args = { ... }
            if k == "SetText" then self.text = args[1] and tostring(args[1]) or "" return end
            if k == "GetText" then return self.text end
            if k == "Show" then self.shown = true return end
            if k == "Hide" then self.shown = false if self.scripts.OnHide then self.scripts.OnHide(self) end return end
            if k == "SetShown" then self.shown = args[1] and true or false return end
            if k == "IsShown" then return self.shown end
            if k == "SetScript" then self.scripts[args[1]] = args[2] return end
            if k == "GetScript" then return self.scripts[args[1]] end
            if k == "CreateTexture" then local x = newObj("Texture") return x end
            if k == "CreateFontString" then local x = newObj("FontString") return x end
            if k == "SetSize" then self.w, self.h = args[1], args[2] return end
            if k == "SetWidth" then self.w = args[1] return end
            if k == "SetHeight" then self.h = args[1] return end
            if k == "GetHeight" then return self.h end
            if k == "GetWidth" then return self.w end
            if k == "GetStringHeight" then local _, n = string.gsub(self.text or "", "\n", "") return 12 * (n + 1) end
            if k == "GetStringWidth" then return #(self.text or "") * 6 end
            if k == "GetPoint" then return "CENTER", nil, "CENTER", 10, 20 end
            if k == "SetTexture" then self.texture = args[1] return end
            if k == "SetChecked" then self.checked = args[1] and true or false return end
            if k == "GetChecked" then return self.checked end
            if k == "SetVertexColor" then self.color = args return end
            if k == "SetColorTexture" then self.color = args return end
            return nil
        end
    end
    return setmetatable(o, mt)
end
allFrames = {}
function CreateFrame(kind, name, parent, template)
    local f = newObj(kind)
    f.name, f.parent, f.template = name, parent, template
    if name then _G[name] = f end
    table.insert(allFrames, f)
    return f
end
function Click(b, ...) assert(b.scripts.OnClick, "kein OnClick") b.scripts.OnClick(b, ...) end

-- Spieler
PLAYER = { name = "Barlor", realm = "Forever", faction = "Alliance", class = "PALADIN", zone = "Eisenschmiede" }
function UnitName(u) if u == "player" then return PLAYER.name end if u == "npc" then return NPC_NAME end end
function GetRealmName() return PLAYER.realm end
function UnitFactionGroup(u) if u == "player" then return PLAYER.faction end if u == "npc" then return NPC_FACTION end end
function UnitClass() return "Paladin", PLAYER.class end
function UnitLevel() return 26 end
function UnitExists(u) return u == "npc" and NPC_NAME ~= nil end
function UnitReaction() return 4 end
function GetRealZoneText() return PLAYER.zone end
function IsShiftKeyDown() return false end
NUM_BAG_SLOTS = 4; NUM_BANKBAGSLOTS = 6; BANK_CONTAINER = -1

ITEMS = {
    [2840] = "Kupferbarren", [2770] = "Kupfererz", [2320] = "Grober Faden",
    [2851] = "Kupferkettengürtel", [2589] = "Leinenstoff", [2996] = "Leinenballen", [2318] = "Leichtes Leder",
}
function GetItemInfo(id) return ITEMS[id] end
C_Item = { GetItemIconByID = function(id) return "icon" .. id end }

-- Taschen/Bank: CONTAINERS[beutel] = { {id, n}, ... }
CONTAINERS = {}
C_Container = {
    GetContainerNumSlots = function(b) return CONTAINERS[b] and #CONTAINERS[b] or 0 end,
    GetContainerItemInfo = function(b, s)
        local e = CONTAINERS[b] and CONTAINERS[b][s]
        if e and e[1] then return { itemID = e[1], stackCount = e[2], hyperlink = ITEMS[e[1]] and ("|cffffffff|Hitem:" .. e[1] .. "::|h[" .. ITEMS[e[1]] .. "]|h|r") or nil } end
        return nil
    end,
}

-- Berufefenster: TRADE = { beruf = "Schmiedekunst", rezepte = { {id, name, item, made, reagents={{id,n}}} } }
TRADE = nil
SCHEMATIC = true
C_TradeSkillUI = {
    GetAllRecipeIDs = function() local t = {} for _, r in ipairs(TRADE and TRADE.rezepte or {}) do table.insert(t, r.id) end return t end,
    GetTradeSkillLineForRecipe = function(id) return 164, TRADE.beruf end,
    GetRecipeInfo = function(id) for _, r in ipairs(TRADE.rezepte) do if r.id == id then return { name = r.name, learned = r.learned ~= false, icon = "ricon", categoryID = r.kat } end end end,
    GetCategoryInfo = function(id) return KATS and KATS[id] and { name = KATS[id] } or nil end,
    GetRecipeOutputItemData = function(id) for _, r in ipairs(TRADE.rezepte) do if r.id == id then return { itemID = r.item } end end end,
    GetRecipeNumItemsProduced = function(id) for _, r in ipairs(TRADE.rezepte) do if r.id == id then return r.made or 1, r.made or 1 end end end,
    GetRecipeNumReagents = function(id) for _, r in ipairs(TRADE.rezepte) do if r.id == id then return #r.reagents end end end,
    GetRecipeReagentInfo = function(id, i) for _, r in ipairs(TRADE.rezepte) do if r.id == id then local z = r.reagents[i] return ITEMS[z[1]], "zicon", z[2], 0 end end end,
    GetRecipeReagentItemLink = function(id, i) for _, r in ipairs(TRADE.rezepte) do if r.id == id then return "|Hitem:" .. r.reagents[i][1] .. ":0|h" end end end,
}
-- Haendler
MERCHANT = {}
function GetMerchantNumItems() return #MERCHANT end
function GetMerchantItemLink(i) return "|Hitem:" .. MERCHANT[i][1] .. "|h" end
function GetMerchantItemInfo(i) return ITEMS[MERCHANT[i][1]], "t", MERCHANT[i][2], MERCHANT[i][3] or 1 end
function GetCoinTextureString(k) return k .. "k" end

function Fire(event, ...)
    for _, f in ipairs(allFrames) do
        if f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end
