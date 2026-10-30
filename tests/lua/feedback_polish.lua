package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Feedback = require("abyss_feedback")
local F = dofile("tests/lua/support/game_ui_fixture.lua")
local Surfaces = require("abyss_monster_surfaces")
local EnemyView = require("abyss_battle_enemy_view")
local Combat = require("abyss_combat")
local Events = require("abyss_events")
local Data = require("abyss_data")
local Theme = require("abyss_theme")
local Presentation = require("abyss_presentation")
local T, S = Theme.motion, Theme.space

-- Drives the production adapter against the generated native tree with a recording audio spy.
local images = 0
local function trackImages(box)
    local original=box.SetImage
    box.SetImage=function(self,...) images=images+1;return original(self,...)end
    for _,child in pairs(box.children)do trackImages(child)end
    return box
end
local function control(definition)return trackImages(F.control(definition))end
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
    local platform=F.withMonsterActors({imageSource="static", color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end,
        sound=function(cue)h.sounds[#h.sounds+1]=cue end})
    local instantiate=platform.monsterActors.instantiate
    platform.monsterActors.instantiate=function(...)return trackImages(instantiate(...))end
    h.surfaces=Surfaces.new(stage,platform)
    h.boxes={}
    local function present(frame)
        local rows=EnemyView.slots(frame,h.feedback)
        h.surfaces:select(rows,h.battle)
        h.surfaces:each(function(box,slot,entry)
            h.boxes[entry.id]=box
            box:SetVisible(true)
            local x,_,_,_,y=EnemyView.position(#rows,slot,entry.actor)
            box:SetAnchoredPosition(x,y)
        end)
    end
    present(h.battle)
    h.feedback=Feedback.new(stage,platform,present,function(failure)h.completed[#h.completed+1]=failure or "ok"end)
    function h.box(name)
        local index=name:match('^enemy(%d+)$')
        if not index then return assert(stage:GetChild(name))end
        return assert(h.boxes[assert(h.battle.enemies[tonumber(index)]).id])
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
    function h.portrait(name) return assert(h.box(name).children.portrait) end
    function h.part(name, part) return assert(h.box(name).children[part]) end
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
    assert(near(card.x, h.feedback.flight.tx) and near(card.y, h.feedback.flight.ty - h.feedback.flight.stop) and h.feedback.flight.stop > 0, "card strikes just below the target face on the contact frame (STS-style, not plastered on portrait)")
    assert(near(h.portrait("enemy1").x, S.m) and near(h.portrait("hero").x, S.l))
    assert(h.sounds[#h.sounds] == "hit")
    local impact = h.part("enemy1", "impact")
    assert(impact.visible and impact.localScaleX > impact.localScaleY, "normal hit is a horizontal shard streak")
    assert(near(h.part("enemy1", "floating").localScaleX, 1.5))
    h.feedback:update(T.hitStop / 2)
    assert(near(h.portrait("enemy1").x, S.m), "knockback is held during hit-stop")
    local _, held = h.until_(function(e) return e.kind ~= "damage" end, true)
    local gate = held + T.hitStop / 2
    assert(gate >= 0.2 - 0.011 and gate <= 0.2 + 0.011, "DamageAction and its normal post-wait total 0.2; visual hit-stop adds no action delay")
    assert(h.stage.x == 0, "a normal hit on an enemy does not shake the screen")
    h.drain()
    assert(h.portrait("enemy1").x == 0 and h.portrait("hero").x == 0 and h.stage.x == 0)
end)

test("heavy attack: uniform shard burst, larger knockback and number, screen shake and longer visual hold", function()
    local h = harness({"bludgeon"}, {"jaw_worm"}, function(s) s.enemies[1].hp, s.enemies[1].maxHp = 80, 80 end)
    h.play() h.until_(kind("damage"))
    assert(h.sounds[#h.sounds] == "hit_heavy", "one heavy contact cue, not a second layered hit")
    local impact = h.part("enemy1", "impact")
    assert(near(impact.localScaleX, impact.localScaleY), "heavy hit bursts instead of streaking")
    assert(near(h.portrait("enemy1").x, S.l) and near(h.part("enemy1", "floating").localScaleX, 2))
    assert(impact.imageId == Theme.image.glow and near(impact.localScaleX, 2), "heavy contact opens with a 2x white FlashAtkImg-style flash")
    local shards, recoiled = false, false
    local shook = false
    local _, held = h.until_(function(e) shook = shook or h.stage.x ~= 0
        shards = shards or (impact.visible and impact.imageId == Theme.image.shards and impact.localScaleX > 1)
        recoiled = recoiled or h.portrait("enemy1").x < -0.5
        return e.kind ~= "damage" end, true)
    assert(shards, "flash hands off to an outward shard burst on the same pooled control")
    assert(recoiled, "heavy knockback swings elastically past home before settling")
    assert(shook and held >= 0.2 - 0.011 and held <= 0.2 + 0.011,
        "heavy visual hold does not extend the fixed DamageAction/post-wait gate")
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
    assert(not h.box("enemy1").visible and not h.box("enemy2").visible)
end)

test("block gain crystallises in with a block icon pop and cue", function()
    local h = harness({"defend"}, {"jaw_worm"})
    h.play() h.until_(kind("block"))
    local shield = h.part("hero", "shield")
    assert(shield.visible and shield.localScaleX > 1)
    for _, name in ipairs({"blockEdge", "blockIcon", "block"}) do
        local part = h.part("hero", name)
        assert(part.localScaleX == 1 and part.localScaleY > 1, "badge pops vertically without expanding into HP")
    end
    assert(h.sounds[#h.sounds] == "block_gain")
    h.drain()
    assert(not shield.visible)
    for _, name in ipairs({"blockEdge", "blockIcon", "block"}) do
        local part = h.part("hero", name)
        assert(part.localScaleX == 1 and part.localScaleY == 1, "all badge parts reset after the pop")
    end
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
    assert(order:find("turn,action_jaw_worm,block_hit", 1, true) and order:sub(-4) == "turn", order)
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

test("killing blow: fixed action hold and independent source alpha death without shrink or sink", function()
    local h = harness({"strike"}, {"jaw_worm"}, function(s) s.enemies[1].hp = 3 end)
    h.play() h.until_(kind("damage"))
    local dying=assert(h.feedback.dying[h.battle.enemies[1].id], "lethal frame starts source die")
    assert(dying.lifetime==1.8, "normal source death retains its independent 1.8-second lifetime")
    local _, held = h.until_(kind("death"))
    assert(held >= 0.2 - 0.011 and held <= 0.2 + 0.011,
        "a lethal visual hold does not extend the fixed DamageAction/post-wait gate")
    h.feedback:update(T.slow / 2)
    local portrait = h.portrait("enemy1")
    assert(portrait.localScaleY == 1 and portrait.y == 0, "source monster death never shrinks or sinks")
    assert(portrait.imageColor.a < 255 and portrait.imageColor.a >= 0, "source TintEffect alpha advances independently")
    h.drain()
    assert(not h.box("enemy1").visible and count(h.sounds, "enemy_die") == 1)
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

test("deaths match enemy material without random draws or additional voices", function()
    for _, item in ipairs({{"cultist", "enemy_die_human"}, {"acid_slime_s", "enemy_die_magic"},
        {"sentry", "enemy_die_metal"}, {"gremlin_nob", "enemy_die_large"}, {"jaw_worm", "enemy_die"}}) do
        local h = harness({"strike"}, {item[1]}, function(s) s.enemies[1].hp = 1 end)
        h.play(); h.drain()
        local deaths = 0
        for _, cue in ipairs(h.sounds) do if cue:find("enemy_die", 1, true) then deaths = deaths + 1 assert(cue == item[2]) end end
        assert(deaths == 1)
    end
end)
test("one actor voice per action survives multi-hit and buff effects without per-hit yelling", function()
    local h = harness({"strike"}, {"jaw_worm"}, function(s)
        s.player.hp = 80
        s.enemies[1].intents = intent({{op="damage",value=1},{op="damage",value=1},{op="block",value=5}})
    end)
    h.run(Combat.endTurn); h.drain()
    assert(count(h.sounds, "action_jaw_worm") == 1 and count(h.sounds, "hurt") == 2)
    local firstVoice, firstContact
    for i, cue in ipairs(h.sounds) do
        if cue == "action_jaw_worm" then firstVoice = i end
        if cue == "hurt" and not firstContact then firstContact = i end
    end
    assert(firstVoice < firstContact)
    h = harness({"strike"}, {"jaw_worm"}, function(s)
        s.enemies[1].intents = {{id="buff",kind="defend",effects={{op="block",value=5}}}}
    end)
    h.run(Combat.endTurn); h.drain()
    assert(count(h.sounds, "action_jaw_worm") == 1, "same actor keeps its sound for a non-attack action")
end)
test("voice identity follows each monster and sleeping or stunned actors stay silent", function()
    local h = harness({"strike"}, {"jaw_worm", "cultist"})
    h.run(Combat.endTurn); h.drain()
    assert(count(h.sounds, "action_jaw_worm") == 1 and count(h.sounds, "action_cultist") == 1)
    for _, k in ipairs({"sleep", "stunned"}) do
        h = harness({"strike"}, {"jaw_worm"}, function(s)
            s.enemies[1].intents = {{id="silent",kind=k,effects={}}}
        end)
        h.run(Combat.endTurn); h.drain()
        assert(count(h.sounds, "action_jaw_worm") == 0)
    end
end)
test("player uses one stable action sound across attack and skill cards", function()
    for _, card in ipairs({"strike", "defend", "inflame", "twin_strike", "cleave"}) do
        local h = harness({card}, {"jaw_worm"})
        h.play(); h.drain()
        assert(count(h.sounds, "player_action") == 1)
        assert(count(h.sounds, "card_play") == 0, "do not layer a second generic card sound over the actor")
    end
end)
assert(failed == 0, failed .. " feedback polish tests failed")
print("LUA_FEEDBACK_POLISH_PASS " .. tests)
