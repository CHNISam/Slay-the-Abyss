package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat, Actors = require("abyss_combat"), require("abyss_actor")
local Effects = require("abyss_effects")
local Events, Data = require("abyss_events"), require("abyss_data")
local Feedback, Presentation = require("abyss_feedback"), require("abyss_presentation")
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local Surfaces=require('abyss_monster_surfaces')
local EnemyView=require('abyss_battle_enemy_view')

-- Fixed community Barricade.use omits ApplyPower when already held. These are
-- constructed sufficient-energy fixtures, not natural acquisition or PC certification.
local count, failed = 0, 0
local function equal(actual, expected, label)
    local bothNaN = type(actual) == "number" and type(expected) == "number" and actual ~= actual and expected ~= expected
    assert(actual == expected or bothNaN, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function test(name, fn)
    count = count + 1
    local ok, reason = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and "ok" or "not ok") .. " barricade_repeat " .. count .. " - " .. name .. (ok and "" or ": " .. tostring(reason)))
end
local function battle(first, second)
    local deck = {{cardId="barricade", upgraded=first}}
    if second ~= nil then deck[2] = {cardId="barricade", upgraded=second} end
    local s = Combat.new(Data, {seed=42, deck=deck, enemies={"cultist"}})
    s.energy = 6
    return s
end
local function gone(s, card)
    for _, pile in ipairs({"hand", "draw", "discard", "exhaust"}) do
        for _, instance in ipairs(s[pile]) do assert(instance.uid ~= card.uid, "used Power remained in " .. pile) end
    end
end
local function unchangedAfter(s)
    local saved = {}
    local function visit(t)
        if type(t) ~= "table" or saved[t] then return end
        local values = {}; saved[t] = values
        for k, v in pairs(t) do values[k] = v; visit(k); visit(v) end
    end
    visit(s)
    return function()
        for original, values in pairs(saved) do
            for k, v in pairs(values) do equal(original[k], v, "original key " .. tostring(k)) end
            for k, v in pairs(original) do equal(v, values[k], "unexpected key " .. tostring(k)) end
        end
    end
end
local function rejected(s, pattern)
    local card = s.hand[1]
    assert(Combat.canPlay(s, card.uid), "failure must occur after canPlay")
    local check = unchangedAfter(s)
    local ok, reason = pcall(Combat.play, s, card.uid)
    equal(ok, false, "rule error"); assert(tostring(reason):find(pattern, 1, true), tostring(reason))
    check()
end

for _, first in ipairs({false, true}) do
for _, second in ipairs({false, true}) do
    test("real first/repeat Power " .. tostring(first) .. "/" .. tostring(second) .. " pays each cost without a second status event", function()
        local s = battle(first, second)
        -- Shuffle is real; select the requested upgrade order by card identity.
        local a, b
        for _, card in ipairs(s.hand) do
            if not a and card.upgraded == first then a = card else b = card end
        end
        local player, statuses, hand, events = s.player, s.player.statuses, s.hand, s.events
        local hp, seed, initial = player.hp, s.seed, #events
        s.player.block = 17
        assert(Combat.play(s, a.uid)); gone(s, a)
        equal(s.energy, first and 4 or 3); equal(statuses.barricade, 1)
        equal(#events, initial + 2); equal(events[initial+1].kind, "play")
        local gained = events[initial+2]
        equal(gained.kind, "status"); equal(gained.detail.status, "barricade"); equal(gained.detail.amount, 1)
        equal(gained.frame.player.statuses.barricade, 1); equal(gained.frame.player.block, 17)
        local n = #events
        assert(Combat.canPlay(s, b.uid)); assert(Combat.play(s, b.uid)); gone(s, b)
        equal(s.energy, 6 - (first and 2 or 3) - (second and 2 or 3))
        equal(#events, n + 1, "repeat only emits play"); equal(events[n+1].kind, "play")
        equal(events[n+1].detail.uid, b.uid); equal(events[n+1].frame.player.statuses.barricade, 1)
        equal(s.player, player); equal(s.player.statuses, statuses); equal(s.hand, hand); equal(s.events, events)
        equal(#s.hand, 0); equal(#s.draw, 0); equal(#s.discard, 0); equal(#s.exhaust, 0)
        equal(statuses.barricade, 1); equal(player.block, 17); equal(player.hp, hp); equal(s.seed, seed)
        assert(Combat.endTurn(s)) -- Cultist's first turn only buffs; Block must survive the real turn boundary.
        equal(player.block, 17); equal(statuses.barricade, 1); equal(s.energy, 3)
        gone(s, a); gone(s, b); equal(gained.frame.player.statuses.barricade, 1)
    end)
end
end

-- Actual generated control names, with platform-only drawing/audio recording.
local function control(definition)
    local c = {name=definition.name, children={}, text="", visible=definition.visible ~= false}
    for _, child in ipairs(definition.children or {}) do c.children[child.name] = control(child) end
    function c:GetChild(key) return assert(self.children[key], "unknown control " .. self.name .. "/" .. key) end
    function c:SetVisible(v) assert(type(v) == "boolean"); self.visible = v end
    function c:SetAnchoredPosition(x, y) self.x, self.y = x, y end
    function c:SetLocalScale(x, y) self.localScaleX, self.localScaleY = x, y end
    function c:SetImage(source, id) assert(source == "static" and type(id) == "number"); self.imageId = id end
    function c:SetAsLastSibling() end
    return c
end
local function find(entries, name)
    for _, entry in ipairs(entries) do
        if entry.name == name then return entry end
        local found = find(entry.children or {}, name); if found then return found end
    end
end
for _, upgraded in ipairs({false, true}) do
    test("production feedback " .. tostring(upgraded) .. " keeps first status cue and never replays zero-layer feedback", function()
        local s, statusCues, completed, observed = battle(upgraded, upgraded), 0, 0, {}
        local stage = control(assert(find(require("abyss_ui_layout"), "battlePanel")))
        local platform=F.withMonsterActors({imageSource="static", color=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end,
            sound=function(cue) if cue == "status" then statusCues = statusCues + 1 end end})
        local surfaces=Surfaces.new(stage,platform)
        surfaces:select(EnemyView.slots(s),s)
        surfaces:each(function(box)box:SetVisible(true)end)
        local feedback = Feedback.new(stage,platform,function() end,
            function(failure) assert(not failure, tostring(failure)); completed = completed + 1 end)
        local function play()
            local before, first = Events.frame(s), #s.events + 1
            assert(Combat.play(s, s.hand[1].uid))
            feedback:begin(before, s, first, Presentation, {0, -200})
            for _ = 1, 2000 do
                feedback:update(0.01)
                local text = stage:GetChild("hero"):GetChild("floating").text
                if text ~= "" then observed[text] = true end
                if not feedback.busy and next(feedback.effects) == nil and next(feedback.poses) == nil then return end
            end
            error("feedback did not finish")
        end
        play(); equal(statusCues, 1); equal(completed, 1)
        assert(observed[s.catalog.statuses.barricade.name .. " ＋1"], "first application feedback absent")
        play(); equal(statusCues, 1, "repeat status audio"); equal(completed, 2)
        equal(observed[s.catalog.statuses.barricade.name .. " ＋0"], nil, "repeat zero-layer text")
    end)
    test("repeat " .. tostring(upgraded) .. " still rejects insufficient energy without mutation", function()
        local s = battle(upgraded); Combat.addStatus(s.player, "barricade", 1)
        s.energy = upgraded and 1 or 2
        local check = unchangedAfter(s)
        local ok, reason = Combat.play(s, s.hand[1].uid)
        equal(ok, false); equal(reason, "insufficient_energy"); check()
    end)
    test("invalid repeat values " .. tostring(upgraded) .. " still throw and restore all references", function()
        for _, value in ipairs({"1", false, {}, 0/0, math.huge, -math.huge, -1, 0.5, 2147483648, -2147483648}) do
            local s = battle(upgraded); Combat.addStatus(s.player, "barricade", 1)
            s.catalog.cards.barricade.effects[1].value = value
            rejected(s, "invalid status amount")
        end
        local s = battle(upgraded); Combat.addStatus(s.player, "barricade", 1)
        s.catalog.cards.barricade.effects[1].value = nil
        rejected(s, "invalid status amount")
    end)
end

test("valid int32 amount and corrupt old stack still reject overflow before applying the nonstacking cap", function()
    for _, fixture in ipairs({{old=1, value=2147483647}, {old=2147483647, value=1}}) do
        local s = battle(false); s.player.statuses.barricade = fixture.old
        s.catalog.cards.barricade.effects[1].value = fixture.value
        rejected(s, "status stack overflow")
    end
end)
test("an error after a skipped repeat restores earlier Block, energy, card and events in place", function()
    local s = battle(false); Combat.addStatus(s.player, "barricade", 1)
    s.catalog.cards.barricade.effects = {{op="block", value=8}, {op="energy", value=2},
        {op="gainStatus", status="barricade", value=1}, {op="gainStatus", status="missing", value=1}}
    rejected(s, "unknown status: missing")
end)
test("an absent status definition still rejects an apparent repeat", function()
    local s = battle(false); s.player.statuses.barricade = 1
    s.catalog.statuses.barricade = nil
    rejected(s, "unknown status: barricade")
end)
-- Controlled post-construction definitions, not shipped data. The old Effects
-- branch forwarded to Actors.applyPower; keep that behavior outside stack=none.
local function changedDefinition(definition)
    local s = battle(false); s.player.statuses.barricade = 1
    s.player.statusDefinitions = Combat.copy(s.player.statusDefinitions)
    s.player.statusDefinitions.barricade = definition
    return s
end
local function applyRepeatedEffect(s)
    return Effects.apply(Combat, s, {{op="gainStatus", status="barricade", value=1}}, s.player)
end
test("non-none table definitions preserve old Actor stacking and status feedback", function()
    for _, stack in ipairs({"intensity", "add"}) do
        -- Catalog shape is normalized by Combat.new, so take its actual definition.
        local definition = Combat.copy(battle(false).player.statusDefinitions.barricade)
        definition.stack = stack
        for _, apply in ipairs({function(s) return Actors.applyPower(s, s.player, "barricade", 1, s.player) end, applyRepeatedEffect}) do
            local s = changedDefinition(definition); local n = #s.events
            apply(s)
            equal(s.player.statuses.barricade, 2); equal(#s.events, n+1)
            equal(s.events[n+1].kind, "status"); equal(s.events[n+1].detail.amount, 1)
            equal(s.events[n+1].frame.player.statuses.barricade, 2)
        end
    end
end)
test("numeric definitions and non-table containers preserve the original Actor error", function()
    for _, fixture in ipairs({{}, {replaceContainer=true, value=0}, {replaceContainer=true, value=true},
        {replaceContainer=true, value=false}, {replaceContainer=true, value="bad"}, {replaceContainer=true}}) do
        local original, candidate = changedDefinition(0), changedDefinition(0)
        if fixture.replaceContainer then
            original.player.statusDefinitions, candidate.player.statusDefinitions = fixture.value, fixture.value
        end
        local originalCheck, candidateCheck = unchangedAfter(original), unchangedAfter(candidate)
        local oldOk, oldError = pcall(Actors.applyPower, original, original.player, "barricade", 1, original.player)
        local newOk, newError = pcall(applyRepeatedEffect, candidate)
        equal(oldOk, false); equal(newOk, false); equal(newError, oldError)
        originalCheck(); candidateCheck()
    end
end)
test("string definitions preserve old Actor stacking rather than pretending they are a nonstacking Power", function()
    for _, apply in ipairs({function(s) return Actors.applyPower(s, s.player, "barricade", 1, s.player) end, applyRepeatedEffect}) do
        local s = changedDefinition("bad"); local n = #s.events
        apply(s)
        equal(s.player.statuses.barricade, 2); equal(#s.events, n+1)
        equal(s.events[n+1].kind, "status"); equal(s.events[n+1].detail.amount, 1)
        equal(s.events[n+1].frame.player.statuses.barricade, 2)
    end
end)
test("explicit zero Barricade and a stored zero retain original status-event semantics", function()
    for _, old in ipairs({0, 1}) do
        local s = battle(false); s.player.statuses.barricade = old
        s.catalog.cards.barricade.effects[1].value = 0
        local first = #s.events + 1
        assert(Combat.play(s, s.hand[1].uid))
        equal(#s.events, first + 1); equal(s.events[first+1].detail.amount, 0)
        equal(s.player.statuses.barricade, old)
    end
    local s = battle(false); s.player.statuses.barricade = 0
    local first = #s.events + 1; assert(Combat.play(s, s.hand[1].uid))
    equal(s.events[first+1].detail.amount, 1); equal(s.player.statuses.barricade, 1)
end)
test("direct Actor application and applyStatus retain their zero-delta event contract", function()
    local s = battle(false); Combat.addStatus(s.player, "barricade", 1)
    local n = #s.events; assert(Actors.applyPower(s, s.player, "barricade", 1, s.player))
    equal(#s.events, n+1); equal(s.events[n+1].detail.amount, 0)
    Combat.applyEffects(s, {{op="applyStatus", status="barricade", value=1}}, s.player, s.player)
    equal(#s.events, n+2); equal(s.events[n+2].detail.amount, 0)
end)
test("zero signed and ordinary debuff applications still spend Artifact while positive Barricade does not", function()
    for _, status in ipairs({"strength", "dexterity", "weak"}) do
        local s = battle(false); Combat.addStatus(s.player, "artifact", 1)
        local n = #s.events
        Combat.applyEffects(s, {{op="gainStatus", status=status, value=0}}, s.player)
        equal(s.player.statuses.artifact, 0); equal(#s.events, n+1)
        equal(s.events[n+1].detail.status, "artifact"); equal(s.events[n+1].detail.blockedStatus, status)
        equal(s.player.statuses[status], nil)
    end
    local s = battle(false, true); Combat.addStatus(s.player, "artifact", 1)
    assert(Combat.play(s, s.hand[1].uid)); assert(Combat.play(s, s.hand[1].uid))
    equal(s.player.statuses.artifact, 1)
end)
test("zero signed Power without Artifact still emits a status frame", function()
    local s = battle(false); local n = #s.events
    Combat.applyEffects(s, {{op="gainStatus", status="strength", value=0}}, s.player)
    equal(#s.events, n+1); equal(s.events[n+1].detail.amount, 0); equal(s.player.statuses.strength, 0)
end)

if failed > 0 then error(failed .. " barricade repeat tests failed") end
print("LUA_BARRICADE_REPEAT_PASS " .. count)
