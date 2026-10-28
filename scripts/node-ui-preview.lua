-- Offline evidence only: drives abyss_node_ui over real Run/Map/Nodes states on the
-- generated native tree and prints each screen's resolved control state as JSON.
-- It does not prove platform fonts, picture library art or touch behaviour.
local UI, Nodes = require("abyss_node_ui"), require("abyss_nodes")
local Run, Map, Combat = require("abyss_run"), require("abyss_map"), require("abyss_combat")
local data = require("abyss_data")
local Presentation = require("abyss_presentation")
local Layout = require("abyss_ui_layout")

local function findSpec(list, name)
    for _, spec in ipairs(list) do
        if spec.name == name then return spec end
        local found = spec.children and findSpec(spec.children, name)
        if found then return found end
    end
end
local function control(spec,parent)
    local c = { spec = spec, parent=parent, children = {}, order = {}, visible = spec.visible ~= false,
        text = spec.text and spec.text.content or "", imageId = spec.image }
    function c:GetChild(key) return self.children[key] end
    function c:SetVisible(value) self.visible = value end
    function c:SetLocalScale(x,y) self.scale={x,y} end
    function c:SetAnchoredPosition(x,y) self.position={x,y} end
    function c:SetSizeDelta(w,h) self.size={w,h} end
    function c:SetImage(_, id) self.imageId = id end
    c.listeners={}
    function c:AddCursorEventListener(event, callback)
        self.listeners[event]=callback
        if event=='click' then self.click=callback end
    end
    for _, item in ipairs(spec.children or {}) do
        c.children[item.name] = control(item,c)
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
    return { name = spec.name, kind = spec.kind, position = c.position or spec.position or { 0, 0 }, size = c.size or spec.size, scale = c.scale,
        visible = c.visible, image = c.imageId, colour = hex(c.imageColor) or spec.colour,
        text = spec.text and { content = c.text, fontSize = spec.text.fontSize, minFontSize = spec.text.minFontSize,
            colour = hex(c.fontColor) or spec.text.colour, align = spec.text.align, valign = spec.text.valign } or nil,
        children = children }
end
local function entered(kind, source, prepare)
    source = source or data
    local run, map = Run.new(source, 42), Map.generate(source, 42)
    while true do
        local choices = Map.available(map)
        for _, node in ipairs(choices) do
            if node.type == kind then
                if prepare then prepare(run) end
                assert(Nodes.enter(run, map, node.id)) return run, map
            end
        end
        assert(Map.choose(map, choices[1].id))
    end
end
local function scene(kind, source, prepare, mobile, enhanced)
    local run, map = entered(kind, source, prepare)
    local root = control(findSpec(Layout, "nodePanel"))
    local ui = UI.new(root, run, map, Presentation, "click", nil,
        { color = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end, imageSource = "static",
          touchScreen=function()return mobile==true end,
          enhancedRooms=enhanced==true,
          cursorEvents={CursorEnter='enter',CursorExit='exit',CursorDown='down',CursorUp='up',CursorEndDrag='endDrag'} })
    ui:setVisible(true)
    return ui, root
end
local function midRun(run) run.hp, run.gold = 62, 99 end
local scenes = {}
local function capture(name, root) scenes[#scenes + 1] = { name = name, tree = dump(root) } end

local ui,root=scene('shop',nil,function(run)run.gold=10000 end)
capture('shop-all',root)
root:GetChild('shopView'):GetChild('card1'):GetChild('hit').listeners.enter({})
ui:update(.2);capture('shop-hover',root)
ui,root=scene('shop',nil,function(run)run.gold=10000 end,true)
assert(ui:press('shopView/card6'));ui:update(.2);capture('shop-touch',root)
ui,root=scene('treasure',nil,midRun,false,true)
capture('chest-closed',root);assert(ui:press('treasureView/chest'))
ui:update(.045);capture('chest-shake',root)
ui:update(.345);capture('chest-burst',root)
ui:update(1);capture('chest-rewards',root)
ui,root=scene('camp',nil,function(run)run.hp=20 end,false,true)
capture('camp-new',root);assert(ui:press('campView/rest'))
ui:update(.5);capture('camp-heal',root)
ui:update(2);capture('camp-rest-result',root)
ui,root=scene('camp',nil,midRun,false,true)
assert(ui:press('campView/forge'));capture('forge-grid',root)
assert(ui:press('pickerView/forgeGrid/card1'));capture('forge-preview',root)
assert(ui:press('confirm'));ui:update(.4);capture('forge-impact',root)
ui:update(2);capture('forge-done',root)

ui, root = scene("shop", nil, midRun)
assert(ui:press("shopView/card1"))
capture("shop", root)
ui:press("shopView/card4") -- unaffordable: explained, not charged
capture("shop-refused", root)
ui.run.gold = 300 ui:render() assert(ui:press("shopView/removal") and ui:press("pickerView/card1"))
capture("shop-remove", root)
assert(ui:press("confirm"))
capture("shop-removed", root)

ui, root = scene("camp", nil, midRun)
capture("camp", root)
assert(ui:press("campView/forge") and ui:press("pickerView/card6"))
capture("forge", root)
assert(ui:press("confirm"))
capture("forge-result", root)
ui, root = scene("camp", nil, midRun)
assert(ui:press("campView/rest"))
capture("camp-rest", root)

local cleric = Combat.copy(data) cleric.rules.events.encounterId = "cleric"
ui, root = scene("event", cleric, function(run) run.hp, run.gold = 41, 40 end)
capture("event-cleric", root)
assert(ui:press("eventView/option1"))
capture("event-result", root)
local purifier = Combat.copy(data);purifier.rules.events.encounterId='purifier'
ui, root = scene("event", purifier, midRun)
capture("event-purifier", root)

ui, root = scene("treasure", nil, midRun)
capture("treasure", root)
assert(ui:press("treasureView/chest"))
capture("treasure-open", root)
print(encode(scenes))
