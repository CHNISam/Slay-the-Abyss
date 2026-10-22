-- Offline VM contract check. Stubs verify lifecycle, not platform rendering/API support.
local live, created, destroyed, failAt = 0, 0, 0, nil
local function control()
    local c = {dead=false, calls={}}
    setmetatable(c, {__index=function(_, name)
        return function(self, ...)
            self.calls[name] = {...}
        end
    end})
    return c
end
Enum = {TextHorizontalAlignment={Left=1,Middle=2,Right=3}, TextVerticalAlignment={Top=1,Middle=2,Bottom=3},
    ImageSource={StaticReference=1}, ImageType={Stretch=1}, CursorEventType={CursorClick=1}}
Color = {FromRGBA=function(...) return {...} end}
printerr = function() end
game = {
    InstantiateClientUIControl=function(index, parent)
        assert(index == 901 or index == 902, 'must use actual bound templates, not image assets')
        assert(parent ~= nil)
        created = created + 1
        if failAt and created == failAt then return nil end
        live = live + 1
        return control()
    end,
    DestroyClientUIControl=function(c)
        assert(not c.dead, 'double destruction')
        c.dead = true
        live, destroyed = live - 1, destroyed + 1
    end,
}
local function loadCard(path, x, y, bound)
    local source = assert(CAPACITY_SOURCES[path])
    if bound then
        source = source:gsub('local IMAGE_PREFAB_ID = 0', 'local IMAGE_PREFAB_ID = 901', 1)
        source = source:gsub('local TEXTBOX_PREFAB_ID = 0', 'local TEXTBOX_PREFAB_ID = 902', 1)
    end
    source = source:gsub('local OFFSET_X = 0', 'local OFFSET_X = ' .. x, 1)
    source = source:gsub('local OFFSET_Y = 0', 'local OFFSET_Y = ' .. y, 1)
    local env = setmetatable({script={object=control()}}, {__index=_G})
    assert(load(source, path, 't', env))()
    return env
end
for _, fixture in ipairs({'reference', 'longest'}) do
    local path = 'art/spikes/card-capacity/' .. fixture .. '/card.lua'
    local card = loadCard(path, 180, -130, false)
    card.OnStart(); assert(live == 0, 'unbound template must fail closed')
    card = loadCard(path, 180, -130, true)
    created = 0
    card.OnStart(); assert(live == 15)
    assert(card.script.object.calls.SetAnchoredPosition[1] == 180 and card.script.object.calls.SetAnchoredPosition[2] == -130)
    card.OnStart(); assert(live == 15, 'restart must clear old instances')
    card.OnDestroy(); assert(live == 0)
    card.OnDestroy(); assert(live == 0, 'cleanup must be idempotent')
    created, failAt = 0, 7
    card.OnStart(); assert(live == 0, 'failed partial creation must clear all created instances')
    failAt = nil
end
for _, count in ipairs({0,1,5,10}) do
    local cards = {}
    for i=1,count do
        cards[i] = loadCard('art/spikes/card-capacity/reference/card.lua', 0, 0, true)
        cards[i].OnStart()
    end
    assert(live == count * 15)
    for _, card in ipairs(cards) do card.OnDestroy() end
    assert(live == 0)
end
local children = {Metrics={}, Status={}, Confirm={}}
local callback
function children.Confirm:AddCursorEventListener(_, fn) callback=fn end
script = {object={GetChild=function(_, name) return assert(children[name]) end}, EnableUpdate=function(self, enabled) self.updating=enabled end}
assert(load(CAPACITY_SOURCES['art/spikes/card-capacity/probe.lua'], 'probe', 't'))()
OnStart(); assert(script.updating)
OnUpdate(0); OnUpdate(-1)
for i=1,301 do OnUpdate(1/30) end
assert(not script.updating)
assert(children.Metrics.text:find('33.3', 1, true), 'mean and P95 should reflect fixture dt')
callback(); assert(children.Status.text == '点击通过')
local oldCallback = callback
OnDestroy(); children.Status.text = 'destroyed'; callback(); assert(children.Status.text == 'destroyed')
OnStart(); assert(script.updating and children.Metrics.text == '客户端帧间隔采样中（10秒）')
oldCallback(); assert(children.Status.text == 'destroyed', 'previous lifecycle callback remains inert after restart')
OnUpdate(0.5); assert(script.updating, 'restart resets old sampling window')
OnDestroy(); assert(not script.updating)
print('PASS capacity VM: 0/1/5/10 counts, template guard, offsets, restart, failure cleanup, destroy, independent click and 10-second dt')
