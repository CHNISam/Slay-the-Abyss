package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Feedback = require("abyss_feedback")
local Combat = require("abyss_combat")
local Events = require("abyss_events")
local Data = require("abyss_data")
local Theme = require("abyss_theme")
local Presentation = require("abyss_presentation")
local T, S = Theme.motion, Theme.space

-- Drives the production adapter against the generated native tree with a recording audio spy.
local images = 0
local function control(definition)
    local c = { name = definition.name, visible = definition.visible ~= false, children = {}, text = "", x = 0, y = 0,
        localScaleX = 1, localScaleY = 1 }
    for _, entry in ipairs(definition.children or {}) do c.children[entry.name] = control(entry) end
    function c:GetChild(key) return assert(self.children[key], "unknown control " .. self.name .. "/" .. key) end
    function c:SetVisible(value) assert(type(value) == "boolean") self.visible = value end
    function c:SetAnchoredPosition(x, y) self.x, self.y = x, y end
    function c:SetLocalScale(x, y) self.localScaleX, self.localScaleY = x, y end
    function c:SetImage(source, id) assert(source == "static" and type(id) == "number") images = images + 1 self.imageId = id end
    function c:SetAsLastSibling() end
    return c
end
local function find(entries, name)
    for _, entry in ipairs(entries) do
        if entry.name == name then return entry end
        local found = find(entry.children or {}, name)
        if found then return found end
    end
end
local function harness(deck, enemies, prepare)
    local stage = control(assert(find(require("abyss_ui_layout"), "battlePanel")))
    local h = {stage = stage, sounds = {}, completed = {}}
    h.feedback = Feedback.new(stage, {imageSource = "static", color = function(r, g, b, a) return {r = r, g = g, b = b, a = a} end,
        sound = function(cue) h.sounds[#h.sounds + 1] = cue end}, function() end,
        function(failure) h.completed[#h.completed + 1] = failure or "ok" end)
    h.battle = Combat.new(Data, {deck = deck, enemies = enemies, seed = 11})
    if prepare then
        local original = {}
        for i, enemy in ipairs(h.battle.enemies) do original[i] = enemy.intents end
        prepare(h.battle)
        -- Custom feedback-only intents must not retain an unrelated production policy.
        for i, enemy in ipairs(h.battle.enemies) do
            if enemy.intents ~= original[i] then enemy.ai, enemy.intentIndex = nil, 1 end
        end
    end
    function h.run(command)
        local before, first = Events.frame(h.battle), #h.battle.events + 1
        assert(command(h.battle))
        h.feedback:begin(before, h.battle, first, Presentation, {0, -200})
    end
    function h.play(target) h.run(function(s) return Combat.play(s, s.hand[1].uid, target or 1) end) end
    -- Advance in small frames until a step matches; returns frames spent and their total time.
    function h.until_(match, allowEnd)
        local dt = 0.01
        local frames, time = 0, 0
        for _ = 1, 2000 do
            local entry = h.feedback.current
            if entry and match(entry) then return frames, time end
            if not h.feedback.busy then
                if allowEnd then return frames, time end
                error("queue ended before match")
            end
            h.feedback:update(dt) frames, time = frames + 1, time + dt
        end
        error("never matched")
    end
    function h.drain(each)
        for _ = 1, 4000 do
            if not h.feedback.busy and next(h.feedback.effects) == nil and next(h.feedback.poses) == nil and next(h.feedback.dying) == nil then return end
            h.feedback:update(0.01) if each then each() end
        end
        error("feedback never settled")
    end
    function h.portrait(name) return stage:GetChild(name):GetChild("portrait") end
    function h.part(name, part) return stage:GetChild(name):GetChild(part) end
    return h
end
local function kind(k) return function(entry) return entry.kind == k end end
local function near(a, b) return math.abs(a - b) < 1e-6 end
local function count(list, value) local c = 0 for _, v in ipairs(list) do if v == value then c = c + 1 end end return c end
local tests, failed = 0, 0
local function test(name, fn)
    tests = tests + 1
    local ok, err = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and "ok" or "not ok") .. " feedback_polish " .. tests .. " - " .. name .. (ok and "" or ": " .. tostring(err)))
end
local function intent(effects, id) return {{id = id or "scripted", kind = "attack", effects = effects}} end

test("normal attack: card lifts then lands on contact, hit-stop holds the knockback and the cue fires at contact", function()
    local h = harness({"strike"}, {"jaw_worm"})
    h.play()
    h.feedback:update(0.01)
    local card = h.stage:GetChild("feedback"):GetChild("playedCard")
    assert(card.y > -200 and card.localScaleX > 1, "card gathers upward before it travels")
    assert(h.portrait("hero").x < 0, "traveler draws back during anticipation")
    assert(count(h.sounds, "hit") == 0, "no impact cue before contact")
    h.until_(kind("damage"))
    assert(near(card.x, h.feedback.flight.tx) and near(card.y, h.feedback.flight.ty), "card arrives at the target on the contact frame")
    assert(near(h.portrait("enemy1").x, S.m) and near(h.portrait("hero").x, S.l))
    assert(h.sounds[#h.sounds] == "hit")
    local impact = h.part("enemy1", "impact")
    assert(impact.visible and impact.localScaleX > impact.localScaleY, "normal hit is a horizontal shard streak")
    assert(near(h.part("enemy1", "floating").localScaleX, 1.5))
    h.feedback:update(T.hitStop / 2)
    assert(near(h.portrait("enemy1").x, S.m), "knockback is held during hit-stop")
    local _, held = h.until_(function(e) return e.kind ~= "damage" end, true)
    assert(held + T.hitStop / 2 >= T.base + T.hitStop - 0.011, "step length includes the hit-stop")
    assert(h.stage.x == 0, "a normal hit on an enemy does not shake the screen")
    h.drain()
    assert(h.portrait("enemy1").x == 0 and h.portrait("hero").x == 0 and h.stage.x == 0)
end)

test("heavy attack: uniform shard burst, larger knockback and number, screen shake and longer hold", function()
    local h = harness({"bludgeon"}, {"jaw_worm"}, function(s) s.enemies[1].hp, s.enemies[1].maxHp = 80, 80 end)
    h.play() h.until_(kind("damage"))
    local impact = h.part("enemy1", "impact")
    assert(near(impact.localScaleX, impact.localScaleY), "heavy hit bursts instead of streaking")
    assert(near(h.portrait("enemy1").x, S.l) and near(h.part("enemy1", "floating").localScaleX, 2))
    local shook = false
    local _, held = h.until_(function(e) shook = shook or h.stage.x ~= 0 return e.kind ~= "damage" end, true)
    assert(shook and held >= T.base + T.hitStopHeavy - 0.011)
end)

test("multi-hit: each strike re-lunges and alternates shard orientation and number drift", function()
    local h = harness({"twin_strike"}, {"jaw_worm"})
    h.play() h.until_(kind("damage"))
    local first = h.feedback.current
    local impact, floating = h.part("enemy1", "impact"), h.part("enemy1", "floating")
    assert(impact.localScaleX > impact.localScaleY and floating.x < 0)
    assert(near(h.portrait("hero").x, S.l))
    h.until_(function(e) return e.kind == "damage" and e ~= first end)
    assert(impact.localScaleY > impact.localScaleX and floating.x > 0, "second strike crosses the first")
    assert(near(h.portrait("hero").x, S.l), "traveler strikes again")
    assert(count(h.sounds, "hit") == 2)
end)

test("area attack: one ripple across the row, one sweep, one cue; deaths wait for the sweep without rewinding HP", function()
    local h = harness({"cleave"}, {"jaw_worm", "jaw_worm", "jaw_worm"}, function(s) s.enemies[1].hp = 1 s.enemies[2].hp = 2 end)
    h.play()
    local kinds = {}
    for _, e in ipairs(h.feedback.queue) do kinds[#kinds + 1] = e.kind end
    assert(table.concat(kinds, ",") == "play,damage,damage,damage,death,death", table.concat(kinds, ","))
    h.until_(kind("damage"))
    assert(h.stage:GetChild("feedback"):GetChild("sweep").visible)
    local frames = h.until_(function(e) return e == h.feedback.queue[4] end)
    assert(frames == 2, "remaining targets are hit on consecutive frames")
    for i = 1, 3 do
        local impact = h.part("enemy" .. i, "impact")
        assert(impact.visible and impact.localScaleX > 1 and near(impact.localScaleY, 0.2), "flat shockwave on enemy" .. i)
    end
    h.until_(kind("death"))
    assert(h.feedback.shadow.enemies[3].hp == h.battle.enemies[3].hp, "deferred death uses the latest frame")
    h.feedback:update(0.01)
    assert(h.feedback.current.kind == "death" and h.feedback.current.detail.target == h.battle.enemies[2].id, "simultaneous kills collapse together")
    assert(count(h.sounds, "hit") == 1 and count(h.sounds, "enemy_die") == 1)
    h.drain()
    assert(not h.stage:GetChild("enemy1").visible and not h.stage:GetChild("enemy2").visible)
end)

test("block gain crystallises in with a block icon pop and cue", function()
    local h = harness({"defend"}, {"jaw_worm"})
    h.play() h.until_(kind("block"))
    local shield = h.part("hero", "shield")
    assert(shield.visible and shield.localScaleX > 1 and h.part("hero", "blockIcon").localScaleX > 1)
    assert(h.sounds[#h.sounds] == "block_gain")
    h.drain()
    assert(h.part("hero", "blockIcon").localScaleX == 1 and not shield.visible)
end)

test("enemy action: banner, windup, lunge on contact, fully blocked hit shudders without shake, then recover", function()
    local h = harness({"strike"}, {"jaw_worm"}, function(s) s.player.block = 20 s.enemies[1].intents = intent({{op = "damage", value = 6}}) end)
    h.run(Combat.endTurn)
    assert(h.feedback.current.kind == "enemy_turn" and h.sounds[1] == "turn")
    h.until_(kind("intent"))
    h.feedback:update(T.enemyActionGap * (1 - T.anticipation))
    assert(near(h.portrait("enemy1").x, S.m), "enemy pulls back before it strikes")
    h.until_(kind("damage"))
    assert(h.portrait("enemy1").x < -S.m and h.sounds[#h.sounds] == "block_hit", "enemy lunges on contact")
    local wobbled = false
    h.until_(function(e) wobbled = wobbled or h.part("hero", "shield").x ~= 0 assert(h.stage.x == 0) return e.kind ~= "damage" end, true)
    assert(wobbled, "shield shudders on a held block")
    h.drain()
    assert(h.portrait("enemy1").x == 0 and h.feedback.shadow.player.hp == h.battle.player.hp)
    local order = table.concat(h.sounds, ",")
    assert(order:find("turn,block_hit", 1, true) and order:sub(-4) == "turn", order)
end)

test("partial block shatters the shield before HP damage and shakes the screen", function()
    local h = harness({"strike"}, {"jaw_worm"}, function(s) s.player.block = 2 s.enemies[1].intents = intent({{op = "damage", value = 9}}) end)
    h.run(Combat.endTurn) h.until_(kind("damage"))
    assert(h.sounds[#h.sounds] == "hurt")
    h.feedback:update(T.fast / 2)
    local shield = h.part("hero", "shield")
    assert(shield.localScaleX > 1 and shield.imageColor.a < 255, "shield breaks outward and fades")
    assert(h.stage.x ~= 0 or h.portrait("hero").x < 0)
end)

test("non-attack intent rises instead of pulling back", function()
    local h = harness({"strike"}, {"jaw_worm"}, function(s) s.enemies[1].intents = {{id = "guard", kind = "defend", effects = {{op = "block", value = 5}}}} end)
    h.run(Combat.endTurn) h.until_(kind("intent"))
    h.feedback:update(T.enemyActionGap * (1 - T.anticipation))
    assert(h.portrait("enemy1").x == 0 and h.portrait("enemy1").localScaleX > 1)
end)

test("poison and thorns: status icon pulse, no hit-stop; poison never knocks back", function()
    local h = harness({"strike"}, {"jaw_worm"}, function(s) Combat.addStatus(s.enemies[1], "poison", 3) s.enemies[1].intents = {{id = "guard", kind = "defend", effects = {{op = "block", value = 5}}}} end)
    h.run(Combat.endTurn) h.until_(kind("status_damage"))
    assert(h.part("enemy1", "impact").imageId == Theme.icon.status.poison)
    local _, held = h.until_(function(e) assert(h.portrait("enemy1").x == 0) return e.kind ~= "status_damage" end, true)
    assert(held < T.base + T.hitStop - 0.011, "damage over time has no hit-stop")
    h = harness({"strike"}, {"jaw_worm"}, function(s) Combat.addStatus(s.enemies[1], "thorns", 3) end)
    h.play() h.until_(kind("status_damage"))
    assert(h.part("hero", "impact").imageId == Theme.icon.status.thorns)
    assert(h.part("hero", "floating").text:find("荆棘", 1, true) and h.sounds[#h.sounds] == "hurt")
end)

test("status application stamps its icon and drifts by polarity", function()
    local h = harness({"bash"}, {"jaw_worm"})
    h.play() h.until_(kind("status"))
    local impact = h.part("enemy1", "impact")
    assert(impact.imageId == Theme.icon.status.vulnerable and impact.localScaleX > 1, "icon stamps in oversized")
    for _ = 1, 15 do h.feedback:update(0.01) end
    assert(impact.visible and impact.y < 0, "debuffs press downward")
end)

test("killing blow: heavy hold, then the enemy gleams, collapses and is hidden", function()
    local h = harness({"strike"}, {"jaw_worm"}, function(s) s.enemies[1].hp = 3 end)
    h.play() h.until_(kind("damage"))
    local _, held = h.until_(kind("death"))
    assert(held >= T.base + T.hitStopHeavy - 0.011)
    h.feedback:update(T.slow / 2)
    local portrait = h.portrait("enemy1")
    assert(portrait.localScaleY < 1 and portrait.y < 0 and h.part("enemy1", "impact").visible)
    h.drain()
    assert(not h.stage:GetChild("enemy1").visible and count(h.sounds, "enemy_die") == 1)
    assert(table.concat(h.sounds, ","):find("hit,enemy_die,victory", 1, true), "death lands before the victory cue")
end)

test("frame cost: no image swaps while effects settle, and cancel restores every pose", function()
    local h = harness({"twin_strike"}, {"jaw_worm"})
    h.play() h.until_(kind("damage"))
    local swaps = images
    h.feedback:update(0.01) h.feedback:update(0.01)
    assert(images == swaps, "image ids change only on steps")
    h.feedback:cancel()
    assert(h.completed[1] == "cancelled" and #h.completed == 1)
    for _, name in ipairs({"hero", "enemy1"}) do
        local p = h.portrait(name)
        assert(p.x == 0 and p.y == 0 and p.localScaleX == 1 and h.part(name, "impact").localScaleX == 1)
    end
    assert(h.stage.x == 0 and not h.stage:GetChild("feedback"):GetChild("sweep").visible)
    assert(next(h.feedback.poses) == nil and next(h.feedback.dying) == nil)
    h.feedback:update(0.1)
    assert(#h.completed == 1)
end)

test("an effect failure mid-hit-stop releases once and leaves no pose or shake behind", function()
    local h = harness({"bludgeon"}, {"jaw_worm"}, function(s) s.enemies[1].hp, s.enemies[1].maxHp = 80, 80 end)
    h.play() h.until_(kind("damage"))
    h.part("enemy1", "shield").SetVisible = function() error("INJECTED_SHIELD_FAILURE") end
    h.feedback:update(0.01)
    assert(not h.feedback.busy and #h.completed == 1 and h.completed[1]:find("INJECTED_SHIELD_FAILURE", 1, true))
    assert(h.stage.x == 0 and h.portrait("hero").x == 0 and h.portrait("enemy1").x == 0)
end)

assert(failed == 0, failed .. " feedback polish tests failed")
print("LUA_FEEDBACK_POLISH_PASS " .. tests)
