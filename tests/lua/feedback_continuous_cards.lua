local testStart=dofile('tests/lua/support/game_ui_fixture.lua').start
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local F = dofile("tests/lua/support/game_ui_fixture.lua")
local Run = require("abyss_run")
local Theme = require("abyss_theme")
local tests, failed = 0, 0
local function test(name, fn)
    tests = tests + 1
    local ok, err = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and "ok" or "not ok") .. " feedback_continuous_cards " .. tests .. " - " .. name .. (ok and "" or ": " .. tostring(err)))
end
local function same(a, b)
    assert(type(a) == type(b), "state type changed")
    if type(a) ~= "table" then assert(a == b, "state value changed") return end
    for k, v in pairs(b) do same(a[k], v) end
    for k in pairs(a) do assert(b[k] ~= nil, "unexpected state field") end
end
local function setup(deck, data, combatOptions, fastMode)
    data = data or F.Data
    local sounds = {}
    local host, root = F.fixture(data, nil, nil, nil, nil, function(cue) sounds[#sounds + 1] = cue end)
    -- The official host now owns this setting and syncs it before every command.
    -- Configure at the title instead of letting perform overwrite a lower-level flag.
    if fastMode ~= nil then assert(host:setFastMode(fastMode)) end
    assert(testStart(host))
    assert(Run.startCombat(host.run, "cultist_solo"))
    -- Controlled deck, ordinary Run.play via the actual host card/target controls.
    local options = {deck = deck or {"strike", "defend", "strike"}, enemies = {"cultist", "cultist"}, seed = 11}
    for key, value in pairs(combatOptions or {}) do options[key] = value end
    host.run.combat = F.Combat.new(data, options)
    host:refresh()
    return host, root:GetChild("battlePanel"), sounds
end
local function play(host, panel, id, target)
    local ui, battle = host.battleUI, host.run.combat
    local slot
    for i, card in ipairs(battle.hand) do if card.cardId == id then slot = i break end end
    assert(slot, "missing controlled card " .. id)
    panel:GetChild("card" .. slot):GetChild("hit").click()
    assert(ui.selected == battle.hand[slot].uid, "ordinary card selection failed")
    if target then panel:GetChild("enemy" .. target):GetChild("hit").click()
    else ui:playSelected() end
    assert(ui.busy and ui.feedback.busy, "the successful command owns the action gate")
end
local function release(host)
    for _ = 1, 100 do
        if not host.battleUI.busy then return end
        host:update(0.01)
    end
    error("card action did not release input")
end
local function count(list, cue)
    local n = 0
    for _, value in ipairs(list) do if value == cue then n = n + 1 end end
    return n
end

test("the next card keeps a previous target's nonblocking VFX without replaying its hit", function()
    local host, panel, sounds = setup()
    local ui, battle = host.battleUI, host.run.combat
    play(host, panel, "strike", 1)
    release(host)
    local firstId = battle.enemies[1].id
    local effect = assert(ui.feedback.effects[firstId], "input should resume before the damage VFX ends")
    local age = effect.age
    assert(age < Theme.motion.damagePop, "the floating number still has a visible tail")
    assert(panel:GetChild("endTurn").interactable, "the normal input gate has reopened")
    assert(count(sounds, "hit") == 1)
    play(host, panel, "defend")
    assert(ui.feedback.effects[firstId] == effect, "a second card must not cancel an unrelated unfinished effect")
    assert(effect.age == age, "starting the next batch must not rewind a VFX clock")
    host:update(0.01)
    assert(effect.age > age, "the existing VFX continues while the next card is playing")
    assert(panel:GetChild("enemy1"):GetChild("floating").visible)
    assert(count(sounds, "hit") == 1, "retaining an effect must not replay its audio")
    release(host)
    local committed = F.Combat.copy(battle)
    for _ = 1, 100 do host:update(0.01) end
    assert(next(ui.feedback.effects) == nil and next(ui.feedback.poses) == nil)
    assert(not ui.busy and not ui.feedback.busy)
    assert(count(sounds, "hit") == 1)
    same(battle, committed)
end)

test("successive targets retain independent VFX clocks and drain normally", function()
    local host, panel, sounds = setup()
    local ui, battle = host.battleUI, host.run.combat
    play(host, panel, "strike", 1)
    release(host)
    local id1, id2 = battle.enemies[1].id, battle.enemies[2].id
    local first = assert(ui.feedback.effects[id1])
    play(host, panel, "strike", 2)
    assert(ui.feedback.effects[id1] == first)
    for _ = 1, 40 do
        if ui.feedback.effects[id2] then break end
        host:update(0.01)
    end
    local second = assert(ui.feedback.effects[id2])
    assert(ui.feedback.effects[id1] == first and first.age > second.age)
    assert(count(sounds, "hit") == 2)
    release(host)
    for _ = 1, 100 do host:update(0.01) end
    assert(next(ui.feedback.effects) == nil)
    assert(not panel:GetChild("enemy1"):GetChild("floating").visible)
    assert(not panel:GetChild("enemy2"):GetChild("floating").visible)
end)

test("cancelling or replacing the battle clears retained VFX and does not leak sounds", function()
    local host, panel, sounds = setup()
    local ui = host.battleUI
    play(host, panel, "strike", 1)
    release(host)
    assert(next(ui.feedback.effects) ~= nil)
    ui.feedback:cancel()
    assert(next(ui.feedback.effects) == nil and next(ui.feedback.poses) == nil)
    assert(not panel:GetChild("enemy1"):GetChild("floating").visible)
    play(host, panel, "strike", 2)
    release(host)
    assert(next(ui.feedback.effects) ~= nil)
    host.run.combat = F.Combat.new(F.Data, {deck = {"defend"}, enemies = {"cultist"}, seed = 12})
    host:refresh()
    host:update(0.01)
    assert(next(ui.feedback.effects) == nil and next(ui.feedback.poses) == nil)
    local heard = #sounds
    for _ = 1, 20 do host:update(0.05) end
    assert(#sounds == heard, "old battle effects never replay")
end)

local function damageWait(host, finalAreaTarget)
    local feedback = host.battleUI.feedback
    for _ = 1, 100 do
        if feedback.current and feedback.current.kind == "damage"
            and (not finalAreaTarget or feedback.current.detail.target == finalAreaTarget) then break end
        assert(feedback.busy, "action gate released before the expected damage")
        host:update(0.01)
    end
    local current, elapsed = feedback.current, 0
    assert(current and current.kind == "damage", "damage step was never reached")
    for _ = 1, 100 do
        if not feedback.busy or feedback.current ~= current then return elapsed end
        host:update(0.01)
        elapsed = elapsed + 0.01
    end
    error("damage step never finished")
end
local function durationNear(actual, expected)
    assert(actual >= expected - 0.000001 and actual <= expected + 0.010001,
        "source action duration " .. expected .. ", observed " .. actual)
end

test("DamageAction waits 0.1 plus normal-only 0.1, independently of the visual hit-stop", function()
    for _, fast in ipairs({false, true}) do
        for _, id in ipairs({"strike", "bludgeon"}) do
            local host, panel = setup({id}, nil, nil, fast)
            local feedback = host.battleUI.feedback
            feedback:setFastMode(fast)
            play(host, panel, id, 1)
            durationNear(damageWait(host), fast and 0.1 or 0.2)
            assert(not host.battleUI.busy and next(feedback.effects) ~= nil,
                "input resumes while the independent VFX finishes")
            assert(feedback.effects[host.run.combat.enemies[1].id].stop ==
                (id == "bludgeon" and Theme.motion.hitStopHeavy or Theme.motion.hitStop),
                "source waits must preserve the approved visual stop")
        end
    end
end)

test("a speed change takes effect on the next command rather than truncating an active action", function()
    -- Test the adapter's snapshot contract independently of the host's separate
    -- menu/busy authorization, covered by game_ui_battle_speed*.lua.
    local root = F.Viewport.apply(F.control({children = F.Layout}), 1280, 720)
    local feedback = require("abyss_feedback").new(root:GetChild("battlePanel"), {
        imageSource = "static", color = function(r,g,b,a) return {r=r,g=g,b=b,a=a} end,
    }, function() end, function() end)
    local battle = F.Combat.new(F.Data, {deck = {"strike", "strike"}, enemies = {"cultist", "cultist"}, seed = 11})
    local host = {battleUI = {feedback = feedback}}
    function host:update(dt) feedback:update(dt) end
    local function command(target)
        local before, first = require("abyss_events").frame(battle), #battle.events + 1
        assert(F.Combat.play(battle, battle.hand[1].uid, target))
        feedback:begin(before, battle, first, F.Presentation)
    end
    command(1)
    feedback:setFastMode(true)
    durationNear(damageWait(host), 0.2)
    command(2)
    durationNear(damageWait(host), 0.1)
    assert(not pcall(function() feedback:setFastMode("fast") end), "mode must be boolean")
    assert(feedback.fastMode == true)
end)

test("DamageAllEnemiesAction keeps its 0.25 base and only removes the normal post-wait", function()
    for _, fast in ipairs({false, true}) do
        local host, panel, sounds = setup({"cleave"}, nil, nil, fast)
        host.battleUI.feedback:setFastMode(fast)
        play(host, panel, "cleave")
        durationNear(damageWait(host, host.run.combat.enemies[2].id), fast and 0.25 or 0.35)
        assert(count(sounds, "hit") == 1, "an area action still emits one contact cue")
    end
end)

test("Whirlwind keeps each source isFast area action and contact cue instead of collapsing all rounds", function()
    for _, fast in ipairs({false, true}) do
        local host, panel, sounds = setup({"whirlwind"}, nil, nil, fast)
        local feedback = host.battleUI.feedback
        feedback:setFastMode(fast)
        play(host, panel, "whirlwind")
        for _ = 1, 3 do
            durationNear(damageWait(host, host.run.combat.enemies[2].id), fast and 0.1 or 0.2)
        end
        assert(count(sounds, "hit") == 3, "three area passes each produce one cue")
        assert(not feedback.busy and host.run.combat.energy == 0)
    end
end)

test("Brilliance, Flechettes and Barrage preserve source superFast DamageAction flags in normal mode", function()
    local watcher = require("abyss_watcher_attack_cards").withCards(require("abyss_watcher_cards").withFoundationCards(F.Data))
    local silent = require("abyss_silent_tactics_cards").withCardDefinitions(F.Data)
    local defect = require("abyss_defect_utility_cards").withCards(require("abyss_defect_cards").withFoundationCards(F.Data))
    for _, spec in ipairs({{"brilliance", watcher}, {"flechettes", silent}, {"barrage", defect}}) do
        local id, data = spec[1], spec[2]
        local host, panel = setup({id, "defend", "defend"}, data, id == "barrage" and {orbSlots = 3, orbRandomSeed = "17"} or nil)
        if id == "barrage" then
            assert(require("abyss_orbs").channel(host.run.combat, "frost", F.Combat))
            assert(require("abyss_orbs").channel(host.run.combat, "plasma", F.Combat))
            host:refresh()
        end
        play(host, panel, id, 1)
        durationNear(damageWait(host), 0.1)
        if id ~= "brilliance" then durationNear(damageWait(host), 0.1) end
        assert(not host.battleUI.busy)
    end
end)

test("Bludgeon's source pre-damage WaitAction lasts 0.8 normally and clamps to 0.1 in fast mode", function()
    for _, fast in ipairs({false, true}) do
        local host, panel, sounds = setup({"bludgeon"}, nil, nil, fast)
        local ui, battle = host.battleUI, host.run.combat
        local hp = battle.enemies[1].hp
        local initialEvents = #battle.events
        ui.feedback:setFastMode(fast)
        play(host, panel, "bludgeon", 1)
        local events, committed = battle.events, F.Combat.copy(battle)
        assert(#events == initialEvents + 2 and events[initialEvents + 1].kind == "play" and events[initialEvents + 2].kind == "damage",
            "the presentation wait does not add a core action or event")
        for _ = 1, 100 do
            if ui.feedback.current and ui.feedback.current.kind == "action_wait" then break end
            assert(ui.feedback.busy, "the source pre-damage WaitAction is missing")
            host:update(0.01)
        end
        assert(ui.feedback.current and ui.feedback.current.kind == "action_wait")
        local elapsed = 0
        while ui.feedback.current.kind == "action_wait" do
            assert(ui.busy and ui.displayBattle.enemies[1].hp == hp,
                "the source pre-damage wait must display the before-damage frame")
            assert(count(sounds, "hit_heavy") == 0, "the damage contact cue has not fired")
            host:update(0.01)
            elapsed = elapsed + 0.01
            assert(elapsed < 1, "source wait failed to complete")
        end
        durationNear(elapsed, fast and 0.1 or 0.8)
        assert(ui.feedback.current.kind == "damage" and ui.displayBattle.enemies[1].hp == hp - 32)
        assert(count(sounds, "hit_heavy") == 1)
        same(battle, committed)
        release(host)
        assert(battle.events == events and #events == 0, "normal host consumption still happens once")
    end
end)

assert(failed == 0, failed .. " continuous-card feedback tests failed")
print("LUA_FEEDBACK_CONTINUOUS_CARDS_PASS " .. tests)
