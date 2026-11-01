package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Feedback = require("abyss_feedback")
local Combat = require("abyss_combat")
local Events = require("abyss_events")
local Data = require("abyss_data")
local Presentation = require("abyss_presentation")
local Theme = require("abyss_theme")

local firstCase, lastCase = ...
firstCase, lastCase = firstCase or 1, lastCase or math.huge
local cases, executed, failed = 0, 0, 0
local function test(name, fn)
    cases = cases + 1
    if cases < firstCase or cases > lastCase then return end
    executed = executed + 1
    local ok, err = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and "ok" or "not ok") .. " battle_life " .. cases .. " - " .. name
        .. (ok and "" or ": " .. tostring(err)))
end
local function same(actual, expected, path)
    if actual == expected then return end
    path = path or "battle"
    assert(type(actual) == type(expected), path .. " type changed")
    if type(expected) ~= "table" then
        assert(actual == expected, path .. " changed")
        return
    end
    for key, value in pairs(expected) do same(actual[key], value, path .. "." .. tostring(key)) end
    for key in pairs(actual) do assert(expected[key] ~= nil, path .. " gained " .. tostring(key)) end
end
local function snapshot(battle)
    -- Catalog/rules are immutable shared definitions, not mutable run state.
    -- Copy every mutable field, including RNG limbs, card instances and events.
    local mutable = {}
    for key, value in pairs(battle) do
        if key ~= "catalog" and key ~= "rules" and key ~= "sourcePools" then mutable[key] = value end
    end
    local result = Combat.copy(mutable)
    result.catalog, result.rules, result.sourcePools = battle.catalog, battle.rules, battle.sourcePools
    return result
end
local function find(list, name)
    for _, entry in ipairs(list) do
        if entry.name == name then return entry end
        local found = find(entry.children or {}, name)
        if found then return found end
    end
end
local function control(definition, inventory)
    local c = {name = definition.name, children = {}, visible = definition.visible ~= false,
        text = "", x = 0, y = 0, localScaleX = 1, localScaleY = 1}
    inventory[#inventory + 1] = c
    for _, child in ipairs(definition.children or {}) do c.children[child.name] = control(child, inventory) end
    function c:GetChild(name) return assert(self.children[name], self.name .. "/" .. name .. " missing") end
    function c:SetVisible(value) assert(type(value) == "boolean"); self.visible = value end
    function c:SetAnchoredPosition(x, y) self.x, self.y = x, y end
    function c:SetLocalScale(x, y, z) assert(z == 1); self.localScaleX, self.localScaleY = x, y end
    function c:SetImage(source, id) assert(source == "static" and type(id) == "number"); self.imageId = id end
    function c:SetAsLastSibling() end
    return c
end
local function harness(deck, enemies, fast)
    local h = {controls = {}, sounds = {}, seen = {}, sequence = {}, completions = {}}
    h.stage = control(assert(find(require("abyss_ui_layout"), "battlePanel")), h.controls)
    -- This isolated feedback harness exercises the explicit non-manager fallback.
    -- Use the current actor template; the full Host suites exercise dynamic ownership.
    dofile('tests/lua/support/feedback_raw_stage.lua')(h.stage,function(spec)return control(spec,h.controls)end)
    h.feedback = Feedback.new(h.stage, {
        imageSource = "static", color = function(r,g,b,a) return {r=r,g=g,b=b,a=a} end,
        sound = function(cue) h.sounds[#h.sounds + 1] = cue end,
    }, function()
        local entry = h.feedback.current
        h.seen[entry] = (h.seen[entry] or 0) + 1
        h.sequence[#h.sequence + 1] = entry
    end, function(reason) h.completions[#h.completions + 1] = reason or "ok" end)
    h.feedback:setFastMode(fast == true)
    h.battle = Combat.new(Data, {deck = deck, enemies = enemies or {"cultist", "cultist"}, seed = 119})
    function h:begin(command)
        local before, first = Events.frame(self.battle), #self.battle.events + 1
        assert(command(self.battle))
        self.expected = snapshot(self.battle)
        self.first = first
        self.feedback:begin(before, self.battle, first, Presentation, {0,-200})
    end
    function h:drain(dt)
        for _ = 1, 2000 do
            if not self.feedback.busy then
                -- Action gates and independent VFX have distinct clocks.
                for _ = 1, 4 do self.feedback:update(1) end
                same(self.battle, self.expected)
                return
            end
            self.feedback:update(dt or 0.05)
        end
        error("feedback action gate did not release")
    end
    function h:assertSourceOnce()
        local cursor = 0
        for index = self.first, #self.battle.events do
            local source = self.battle.events[index]
            assert(self.seen[source] == 1, "source event " .. index .. " omitted or repeated: " .. source.kind)
            while self.sequence[cursor + 1] ~= source do
                cursor = cursor + 1
                assert(cursor < #self.sequence, "source event order changed")
            end
            cursor = cursor + 1
        end
    end
    return h
end
local function playFirst(state) return Combat.play(state, state.hand[1].uid, 1) end
local function size(map) local n = 0; for _ in pairs(map or {}) do n = n + 1 end; return n end

test("background resume preserves every multi-enemy and multi-hit source event exactly once", function()
    local h = harness({"whirlwind"})
    h:begin(playFirst)
    local originalRandom = math.random
    math.random = function() error("presentation consumed gameplay randomness") end
    local ok, reason = pcall(function()
        while h.feedback.busy do
            local index = h.feedback.index
            h.feedback:update(60)
            assert(not h.feedback.busy or h.feedback.index == index + 1,
                "one resumed frame skipped visible actions")
        end
        h:drain()
    end)
    math.random = originalRandom
    assert(ok, reason)
    h:assertSourceOnce()
    assert(#h.completions == 1 and h.completions[1] == "ok")
    for _ = 1, 20 do h.feedback:update(60) end
    assert(#h.completions == 1, "settled updates repeated completion")
end)

test("zero-delta pause and normal resume cannot consume or replay a card command", function()
    local h = harness({"strike", "strike"})
    h:begin(playFirst)
    local index, current, heard = h.feedback.index, h.feedback.current, #h.sounds
    for _ = 1, 20 do h.feedback:update(0) end
    assert(h.feedback.index == index and h.feedback.current == current and #h.sounds == heard)
    h:drain()
    h:assertSourceOnce()
    h:begin(playFirst)
    h:drain()
    h:assertSourceOnce()
    assert(#h.completions == 2)
end)

test("cancel during enemy turn releases once and the next batch does not replay cancelled events", function()
    local h = harness({"defend", "strike"})
    h:begin(Combat.endTurn)
    for _ = 1, 100 do
        if h.feedback.current.kind == "intent" then break end
        h.feedback:update(0.05)
    end
    assert(h.feedback.current and h.feedback.current.kind == "intent")
    local cancelled = h.feedback.current
    h.feedback:cancel()
    h.feedback:cancel()
    assert(not h.feedback.busy and #h.completions == 1 and h.completions[1] == "cancelled")
    assert(size(h.feedback.effects) == 0 and size(h.feedback.poses) == 0 and size(h.feedback.dying) == 0)
    same(h.battle, h.expected)
    h:begin(playFirst)
    h:drain()
    h:assertSourceOnce()
    assert(h.seen[cancelled] == 1 and #h.completions == 2)
end)

test("simultaneous lethal hits keep source order and death cleanup through a resumed frame", function()
    local h = harness({"cleave"})
    for _, enemy in ipairs(h.battle.enemies) do enemy.hp = 1 end
    h:begin(playFirst)
    h:drain(60)
    h:assertSourceOnce()
    assert(h.battle.phase == "victory", "controlled area attack must win")
    assert(size(h.feedback.dying) == 0 and size(h.feedback.effects) == 0)
    for _, enemy in ipairs(h.battle.enemies) do assert(h.feedback.deaths[enemy.id]) end
    local deaths, deathCue = 0, Theme.deathSound.cultist or "enemy_die"
    for _, cue in ipairs(h.sounds) do if cue == deathCue then deaths = deaths + 1 end end
    assert(deaths == 1, "simultaneous death group repeats audio")
end)

test("repeated round-end and reshuffle batches reuse controls and release all transient maps", function()
    local deck = {}
    for _ = 1, 12 do deck[#deck + 1] = "defend" end
    local h = harness(deck, {"cultist", "cultist", "cultist"})
    h.battle.player.hp, h.battle.player.maxHp = 100000, 100000
    local inventory = {}
    for index, c in ipairs(h.controls) do inventory[index] = c end
    for _ = 1, 4 do
        h:begin(playFirst)
        h:drain(60)
        h:assertSourceOnce()
        h:begin(Combat.endTurn)
        h:drain(60)
        h:assertSourceOnce()
        assert(size(h.feedback.effects) == 0 and size(h.feedback.poses) == 0 and size(h.feedback.dying) == 0)
        assert(not h.feedback.queue and not h.feedback.current and not h.feedback.sweep and not h.feedback.dissolve)
        assert(#h.controls == #inventory, "event playback allocated another native control")
        for index, c in ipairs(inventory) do assert(h.controls[index] == c) end
        assert(h.stage.x == 0 and h.stage.y == 0, "screen shake did not settle")
    end
    assert(#h.completions == 8)
end)

test("normal and accelerated replay leave identical rules, events, destinations and random streams", function()
    local outputs = {}
    for mode = 1, 2 do
        local h = harness({"anger", "anger", "anger", "anger", "anger", "anger"}, {"cultist", "cultist"}, mode == 2)
        h.battle.player.hp, h.battle.player.maxHp = 10000, 10000
        for _ = 1, 2 do
            h:begin(playFirst)
            h:drain(mode == 2 and 60 or 0.025)
            h:assertSourceOnce()
            h:begin(Combat.endTurn)
            h:drain(mode == 2 and 60 or 0.025)
            h:assertSourceOnce()
        end
        outputs[mode] = snapshot(h.battle)
    end
    same(outputs[1], outputs[2])
end)

assert(executed > 0, "no battle life cases selected")
assert(failed == 0, tostring(failed) .. " battle life regression failures")
print("LUA_BATTLE_LIFE_REGRESSION_PASS " .. executed)
