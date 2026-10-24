-- Offline evidence only: drives abyss_battle_ui over real Combat states on the generated
-- native battle tree (ABYSS_TEST_LAYOUT) and prints each scene's resolved controls as JSON.
-- It does not prove platform fonts, picture library art or touch behaviour.
local UI, Combat, Run = require("abyss_battle_ui"), require("abyss_combat"), require("abyss_run")
local Data, Presentation = require("abyss_data"), require("abyss_presentation")

local Control = {}
function Control:GetChild(key) return assert(self.children[key], "unknown control " .. self.name .. "/" .. key) end
function Control:SetVisible(value) self.visible = value end
function Control:AddCursorEventListener(event, fn) self.listeners[event] = fn end
function Control:SetAnchoredPosition(x, y) self.x, self.y = x, y end
function Control:SetSizeDelta(x, y) self.w, self.h = x, y end
function Control:SetLocalScale(x, y) self.sx, self.sy = x, y end
function Control:SetImage(_, id) self.imageId = id end
function Control:SetAsLastSibling()
    local siblings = self.parent and self.parent.order
    if not siblings then return end
    for i, item in ipairs(siblings) do if item == self then table.remove(siblings, i) break end end
    siblings[#siblings + 1] = self
end
local function control(spec, parent)
    local c = setmetatable({ spec = spec, name = spec.name, parent = parent, children = {}, order = {}, listeners = {},
        visible = spec.visible ~= false, text = spec.text and spec.text.content or "", imageId = spec.image,
        x = spec.position and spec.position[1] or 0, y = spec.position and spec.position[2] or 0,
        w = spec.size and spec.size[1], h = spec.size and spec.size[2] }, { __index = Control })
    for _, item in ipairs(spec.children or {}) do
        c.children[item.name] = control(item, c)
        c.order[#c.order + 1] = c.children[item.name]
    end
    return c
end
local function hex(value)
    if type(value) ~= "table" then return value end
    return string.format("#%02X%02X%02X%02X", value.r, value.g, value.b, value.a or 255)
end
local function encode(value)
    local kind = type(value)
    if kind == "string" then
        return '"' .. value:gsub('[%c"\\]', function(ch)
            return ({ ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n" })[ch] or string.format("\\u%04x", ch:byte())
        end) .. '"'
    elseif kind == "number" or kind == "boolean" then return tostring(value)
    elseif kind == "nil" then return "null" end
    local parts = {}
    if #value > 0 or next(value) == nil then
        for _, item in ipairs(value) do parts[#parts + 1] = encode(item) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do parts[#parts + 1] = encode(key) .. ":" .. encode(value[key]) end
    return "{" .. table.concat(parts, ",") .. "}"
end
local function dump(c)
    local spec, children = c.spec, {}
    for _, item in ipairs(c.order) do if item.visible then children[#children + 1] = dump(item) end end
    return { name = spec.name, kind = spec.kind, position = { c.x, c.y }, size = { c.w, c.h },
        scale = c.sx and { c.sx, c.sy } or spec.scale, rotation = c.localRotationZ or spec.rotation,
        image = c.imageId, colour = hex(c.imageColor) or spec.colour, opacity = spec.opacity,
        text = spec.text and { content = c.text, fontSize = spec.text.fontSize, minFontSize = spec.text.minFontSize,
            align = spec.text.align, colour = hex(c.fontColor) or spec.text.colour } or nil,
        children = children }
end

local function setup(enemies, deck)
    local root = control({ name = "root", size = { 1280, 720 }, children = assert(ABYSS_TEST_LAYOUT).controls })
    local stage = root:GetChild("stage")
    local ui = UI.new(root, Data, Presentation, "click", { imageSource = "static",
        cursorEvents={CursorDown='down',CursorDrag='drag',CursorUp='up',CursorEndDrag='endDrag'},
        color = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end })
    ui:resize(1280, 720)
    ui.run = Run.new(Data, 42)
    assert(Run.startCombat(ui.run, "cultist_solo"))
    ui.run.combat = Combat.new(Data, { deck = deck or { "bash", "strike", "strike", "defend", "defend" }, enemies = enemies })
    ui:render()
    return ui, stage
end
-- Pin an enemy's next move without touching any rule: the same fixture shape the UI tests use.
local function intent(enemy, kind, effects)
    enemy.ai, enemy.intentIndex = nil, 1
    enemy.intents = { { id = "preview_" .. kind, kind = kind, effects = effects } }
end
local scenes = {}
local function capture(name, stage) scenes[#scenes + 1] = { name = name, tree = dump(stage) } end
local function click(box) assert(box.listeners.click, box.name .. " has no click")({ touchId = 7 }) end

-- 1. Five enemies, one of every intent family, player under Vulnerable/Weak.
local ui, stage = setup({ "jaw_worm", "acid_slime_m", "cultist", "fat_gremlin", "lagavulin" })
local s = ui.run.combat
Combat.addStatus(s.enemies[1], "strength", 3)
intent(s.enemies[1], "attack", { { op = "damage", value = 5, times = 2 } })
intent(s.enemies[2], "attack", { { op = "damage", value = 7 }, { op = "applyStatus", status = "weak", value = 1 } })
intent(s.enemies[3], "buff", { { op = "gainStatus", status = "ritual", value = 3 } })
intent(s.enemies[4], "defend", { { op = "block", value = 6 }, { op = "gainStatus", status = "strength", value = 2 } })
Combat.addStatus(s.player, "vulnerable", 2) Combat.addStatus(s.player, "weak", 1)
Combat.addTemporaryStrength(s.player, 2)
Combat.addStatus(s.enemies[2], "poison", 4) Combat.addStatus(s.enemies[1], "vulnerable", 1)
ui:render()
capture("intents", stage)
click(stage:GetChild("enemy2"):GetChild("intentHit"))
capture("intent-compound", stage)
click(stage:GetChild("statusInfo"):GetChild("hit"))
click(stage:GetChild("hero"):GetChild("hit"))
capture("hero-status", stage)
click(stage:GetChild("statusInfo"):GetChild("hit"))
click(stage:GetChild("enemy1"):GetChild("intentHit"))
capture("intent-attack", stage)

-- 2. A crowded unit: every status reachable across pages.
ui, stage = setup({ "cultist", "guardian" })
s = ui.run.combat
for _, id in ipairs({ "strength", "dexterity", "thorns", "regen", "artifact", "barricade", "ritual" }) do Combat.addStatus(s.enemies[2], id, 3) end
for _, id in ipairs({ "vulnerable", "weak", "frail", "poison" }) do Combat.addStatus(s.enemies[2], id, 2) end
s.enemies[2].block = 12
ui:render()
capture("crowded-row", stage)
click(stage:GetChild("enemy2"):GetChild("statusRow"):GetChild("hit"))
capture("crowded-page1", stage)
click(stage:GetChild("statusInfo"):GetChild("page"))
capture("crowded-page2", stage)

-- 3. Long condition text and the looter's steal intent.
ui, stage = setup({ "looter" })
s = ui.run.combat
Combat.addStatus(s.enemies[1], "curl_up", 7)
ui:render()
click(stage:GetChild("enemy1"):GetChild("statusRow"):GetChild("hit"))
capture("long-text", stage)
click(stage:GetChild("statusInfo"):GetChild("hit"))
click(stage:GetChild("enemy1"):GetChild("intentHit"))
capture("intent-steal", stage)

-- 4. Card keywords explain, they do not apply.
ui, stage = setup({ "cultist" }, { "bash", "strike", "defend" })
s = ui.run.combat
local slot
for i, card in ipairs(s.hand) do if card.cardId == "bash" then slot = i end end
assert(ui:openHelp(ui:cardHelpSpec(slot), stage:GetChild("card" .. slot):GetChild("hit"), true))
capture("card-keyword", stage)

-- Dynamic-value QA: real core states, offline evidence only.
for _,scene in ipairs({
    {'value-neutral',{}}, {'value-frail',{frail=1}}, {'value-dexterity',{dexterity=3}},
    {'value-weak',{weak=1}}, {'value-mixed',{strength=-1,dexterity=2}},
}) do
    ui,stage=setup({'jaw_worm','cultist'},{'strike','defend','iron_wave','twin_strike','body_slam'})
    s=ui.run.combat
    for id,n in pairs(scene[2]) do Combat.addStatus(s.player,id,n) end
    ui:render() capture(scene[1],stage)
end
ui,stage=setup({'jaw_worm','cultist'},{'strike','strike','defend'})
s=ui.run.combat Combat.addStatus(s.enemies[2],'vulnerable',1)
local slot
for i,card in ipairs(s.hand) do if card.cardId=='strike' then slot=i break end end
local card=stage:GetChild('card'..slot)
local function event(kind,x,y)
    card:GetChild('hit').listeners[kind]({touchId=7,GetUIPos=function()return 640+x,360+y end})
end
event('down',card.x,card.y) event('drag',require('abyss_theme').layout.enemyRow.xTo,require('abyss_theme').layout.enemyRow.y)
capture('value-aim',stage)
event('endDrag',card.x,-350) ui:render() capture('value-cancel',stage)
ui,stage=setup({'cultist'},{'iron_wave','iron_wave','iron_wave','iron_wave','iron_wave'})
s=ui.run.combat
-- Reuse legal instances to stress ten slots; this is a layout fixture, not a gameplay path.
for i=6,10 do s.hand[i]=Combat.copy(s.hand[i-5]); s.hand[i].uid='value_fixture_'..i end
Combat.addStatus(s.player,'strength',-1) Combat.addStatus(s.player,'dexterity',2)
ui:render() capture('value-ten',stage)
ui.selected=s.hand[1].uid ui:render() capture('value-ten-selected',stage)
print(encode(scenes))
