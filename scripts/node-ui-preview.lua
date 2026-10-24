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
local function control(spec)
    local c = { spec = spec, children = {}, order = {}, visible = spec.visible ~= false,
        text = spec.text and spec.text.content or "", imageId = spec.image }
    function c:GetChild(key) return self.children[key] end
    function c:SetVisible(value) self.visible = value end
    function c:SetLocalScale() end -- snapshot renderer records resting geometry only
    function c:SetImage(_, id) self.imageId = id end
    function c:AddCursorEventListener(_, callback) self.click = callback end
    for _, item in ipairs(spec.children or {}) do
        c.children[item.name] = control(item)
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
    return { name = spec.name, kind = spec.kind, position = spec.position or { 0, 0 }, size = spec.size,
        visible = c.visible, image = c.imageId, colour = hex(c.imageColor) or spec.colour,
        text = spec.text and { content = c.text, fontSize = spec.text.fontSize, minFontSize = spec.text.minFontSize,
            colour = hex(c.fontColor) or spec.text.colour } or nil,
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
local function scene(kind, source, prepare)
    local run, map = entered(kind, source, prepare)
    local root = control(findSpec(Layout, "nodePanel"))
    local ui = UI.new(root, run, map, Presentation, "click", nil,
        { color = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end, imageSource = "static" })
    ui:setVisible(true)
    return ui, root
end
local function midRun(run) run.hp, run.gold = 62, 99 end
local scenes = {}
local function capture(name, root) scenes[#scenes + 1] = { name = name, tree = dump(root) } end

local ui, root = scene("shop", nil, midRun)
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
