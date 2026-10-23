package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat = require("abyss_combat")
local Actor = require("abyss_actor")
local data = require("abyss_data")
local count = 0
local function eq(a, b) assert(a == b, "expected " .. tostring(b) .. ", got " .. tostring(a)) end
local function same(a, b)
    eq(type(a), type(b))
    if type(a) ~= "table" then eq(a, b); return end
    for k, v in pairs(a) do same(v, b[k]) end
    for k in pairs(b) do assert(a[k] ~= nil, "unexpected key " .. tostring(k)) end
end
local function test(name, run) run(); count = count + 1; print("ok status " .. count .. " - " .. name) end
local function battle(enemies)
    return Combat.new(data, { deck = { "strike", "defend", "bash" }, enemies = enemies or { "jaw_worm" }, seed = 42 })
end
local function status(actor, id, value) Combat.addStatus(actor, id, value) end

test("intensity and duration stack, nonstacking barricade stays one", function()
    local s = battle(); local p = s.player
    for _, id in ipairs({ "poison", "regen", "thorns", "weak", "frail", "vulnerable" }) do
        status(p, id, 2); status(p, id, 3); eq(p.statuses[id], 5)
    end
    status(p, "barricade", 8); status(p, "barricade", 9); eq(p.statuses.barricade, 1)
    status(p, "strength", 3); status(p, "strength", -5); eq(p.statuses.strength, -2)
    status(p, "dexterity", -3); eq(p.statuses.dexterity, -3)
end)

test("unknown status and invalid amounts fail atomically", function()
    local s = battle()
    for _, input in ipairs({ {"unknown", 1}, {"weak", -1}, {"poison", 0.5}, {"regen", "2"}, {"thorns", math.huge} }) do
        local before = Combat.copy(s)
        eq(pcall(status, s.player, input[1], input[2]), false)
        same(s, before)
    end
    status(s.player, "strength", 2147483647)
    local before = Combat.copy(s)
    eq(pcall(status, s.player, "strength", 2147483647), false); same(s, before)
end)

test("UI status view copies metadata, amounts and signed debuffs", function()
    local s = battle(); status(s.player, "strength", -2); status(s.player, "weak", 1)
    local view = Combat.statusView(s.player)
    eq(#view, 2); eq(view[1].id, "strength"); eq(view[1].amount, -2)
    eq(view[1].name, s.catalog.statuses.strength.name); eq(view[2].kind, "debuff")
    view[1].amount = 99; view[1].name = "changed"; view[2].decay = "none"
    eq(s.player.statuses.strength, -2); eq(s.catalog.statuses.weak.decay, "turn_end_minus_1")
    eq(Combat.statusView(s.enemies[1])[1], nil)
end)

test("strength weak vulnerable combine with only final rounding", function()
    local s = battle(); local p, e = s.player, s.enemies[1]
    status(p, "strength", 2); status(p, "weak", 1); status(e, "vulnerable", 1)
    eq(Combat.damage(s, p, e, 5), 7) -- (5+2)*.75*1.5 = 7.875
    status(p, "strength", -20)
    local hp = e.hp; eq(Combat.damage(s, p, e, 5), 0); eq(e.hp, hp)
end)

test("dexterity frail and negative dexterity floor block at zero", function()
    local s = battle(); local p = s.player
    status(p, "dexterity", 2); status(p, "frail", 1); Combat.block(s, p, 5); eq(p.block, 5)
    status(p, "dexterity", -20); Combat.block(s, p, 5); eq(p.block, 5)
    Combat.block(s, p, 4, true); eq(p.block, 9)
end)

test("large attack bases do not wrap in 32-bit modifier multiplication", function()
    local s = battle(); local p, e = s.player, s.enemies[1]
    status(p, "weak", 1)
    local hp = e.hp
    eq(Combat.damage(s, p, e, 100000000), hp); eq(e.hp, 0)
end)

test("attack modifiers crossing 32-bit range retain float results and final rounding", function()
    local s = battle(); local p, e = s.player, s.enemies[1]
    status(p, "weak", 1); status(e, "vulnerable", 1)
    e.hp = 3000000000.0
    eq(Combat.damage(s, p, e, 2147483647), 2415919102.0)
    eq(e.hp, 584080898.0)
end)

test("large block modifiers retain precision without permitting uncapped final state", function()
    local s = battle(); local p = s.player
    status(p, "dexterity", 2); status(p, "frail", 1)
    eq(Actor.blockAmount(s, p, 100000000), 75000001)
    -- Arithmetic-only hostile fixture: public status application now caps at 999.
    p.statuses.dexterity = 2147483647
    eq(Actor.blockAmount(s, p, 2147483647), 3221225470.0)
    eq(Actor.blockAmount(s, p, 2147483647, true), 2147483647)
    Combat.block(s, p, 2147483647); eq(p.block, 999)
    Combat.block(s, p, 2147483647, true); eq(p.block, 999)
end)

test("block gain caps both actors at 999 for ordinary and fixed effects", function()
    for _, enemy in ipairs({ false, true }) do
        for _, fixed in ipairs({ false, true }) do
            for _, row in ipairs({ {0, 5, 5}, {993, 5, 998}, {994, 5, 999},
                {998, 5, 999}, {999, 5, 999}, {999, 0, 999}, {998, -5, 998} }) do
                local s = battle(); local actor = enemy and s.enemies[1] or s.player
                actor.block = row[1]; Combat.block(s, actor, row[2], fixed)
                eq(actor.block, row[3])
            end
        end
    end
end)

test("block cap follows modifiers and final rounding rather than clamping the base", function()
    local s = battle(); local p = s.player
    status(p, "frail", 1); Combat.block(s, p, 1200); eq(p.block, 900)
    p.block = 995; status(p, "dexterity", 2)
    Combat.block(s, p, 5); eq(p.block, 999)
    p.block = 998; status(p, "dexterity", -20)
    Combat.block(s, p, 5); eq(p.block, 998)
    Combat.block(s, p, 5, true); eq(p.block, 999)
end)

test("capped block retains barricade and ordinary turn reset semantics", function()
    local s = battle(); local p = s.player
    status(p, "barricade", 1); Combat.block(s, p, 1000)
    Actor.startTurn(s, p); eq(p.block, 999)
    Actor.endTurn(s, p); eq(p.block, 999)
    p.statuses.barricade = 0; Actor.startTurn(s, p); eq(p.block, 0)
end)

test("existing defend card and enemy defend intent use the capped actor entry", function()
    local s = battle(); s.player.block = 998
    local uid
    for _, c in ipairs(s.hand) do if c.cardId == "defend" then uid = c.uid end end
    assert(uid); assert(Combat.play(s, uid)); eq(s.player.block, 999)
    local e = s.enemies[1]; e.block = 998; e.intentIndex = 2
    status(e, "barricade", 1)
    assert(Combat.endTurn(s)); eq(e.block, 999)
end)

test("debuff durations decay once at owner end and never below zero", function()
    local s = battle(); local p = s.player
    for _, id in ipairs({ "weak", "vulnerable", "frail" }) do status(p, id, 2) end
    Actor.startTurn(s, p); eq(p.statuses.weak, 2)
    Actor.endTurn(s, p)
    for _, id in ipairs({ "weak", "vulnerable", "frail" }) do eq(p.statuses[id], 1) end
    Actor.endTurn(s, p); Actor.endTurn(s, p); eq(p.statuses.weak, 0)
end)

test("timing and stacking are read from independent data definitions", function()
    local changed = Combat.copy(data)
    for _, d in ipairs(changed.statuses.statuses) do
        if d.id == "weak" then d.decay = "none" end
        if d.id == "vulnerable" then d.stack = "none" end
    end
    local s = Combat.new(changed)
    status(s.player, "weak", 2); status(s.player, "vulnerable", 8)
    Actor.endTurn(s, s.player); eq(s.player.statuses.weak, 2); eq(s.player.statuses.vulnerable, 0)
    eq(data.statuses.statuses[3].stack, "duration")
end)

test("poison bypasses block and all attack modifiers then decreases", function()
    local s = battle(); local p = s.player
    p.block = 40; status(p, "barricade", 1); status(p, "poison", 3)
    status(p, "vulnerable", 3); status(p, "strength", 9); status(p, "thorns", 7)
    local hp = p.hp; Actor.startTurn(s, p)
    eq(p.hp, hp - 3); eq(p.block, 40); eq(p.statuses.poison, 2)
    eq(s.events[#s.events].detail.status, "poison")
end)

test("lethal player start poison prevents refresh draw and actions", function()
    local s = battle(); s.player.hp = 2; status(s.player, "poison", 2)
    s.hand = {}; s.energy = 0
    local seed, draw, events = s.seed, #s.draw, #s.events
    Combat.startPlayerTurn(s)
    eq(s.phase, "defeat"); eq(#s.hand, 0); eq(#s.draw, draw); eq(s.seed, seed); eq(s.energy, 0)
    eq(s.player.statuses.poison, 1); eq(Combat.endTurn(s), false)
    eq(#s.events, events + 2) -- poison, defeat; no player_turn/draw event
end)

test("poison-killed enemy never attacks or advances and later enemies still act", function()
    local s = battle({ "jaw_worm", "jaw_worm" }); local first = s.enemies[1]
    first.hp = 1; status(first, "poison", 1)
    local hp = s.player.hp
    Combat.endTurn(s)
    eq(first.hp, 0); eq(first.intentIndex, 1); eq(s.player.hp, hp - 11)
    eq(s.enemies[2].jawLast, "jaw_worm_1"); assert(s.enemies[2].intentIndex ~= 1); eq(s.phase, "player")
end)

test("last enemy poison yields victory before intent and next player draw", function()
    local s = battle(); local e = s.enemies[1]; e.hp = 1; status(e, "poison", 2)
    local hp, turn = s.player.hp, s.turn
    Combat.endTurn(s)
    eq(s.phase, "victory"); eq(s.player.hp, hp); eq(s.turn, turn); eq(#s.hand, 0)
end)

test("regen heals at owner end capped by max hp then decays even at cap", function()
    local s = battle(); local p = s.player; p.hp = p.maxHp - 2
    status(p, "regen", 5); Actor.startTurn(s, p); eq(p.hp, p.maxHp - 2)
    Actor.endTurn(s, p); eq(p.hp, p.maxHp); eq(p.statuses.regen, 4)
    Actor.endTurn(s, p); eq(p.hp, p.maxHp); eq(p.statuses.regen, 3)
    p.hp = 0; Actor.endTurn(s, p); eq(p.hp, 0); eq(p.statuses.regen, 3)
end)

test("barricade retains block at owner start and absent barricade clears it", function()
    local s = battle(); local p, e = s.player, s.enemies[1]
    status(p, "barricade", 1); p.block = 17; e.block = 8
    Actor.startTurn(s, p); Actor.startTurn(s, e); eq(p.block, 17); eq(e.block, 0)
end)

test("temporary strength stacks and is removed only at its owner end", function()
    local s = battle(); local p = s.player
    status(p, "strength", -2); Combat.addTemporaryStrength(p, 3); Combat.addTemporaryStrength(p, 2)
    eq(p.statuses.strength, 3); eq(Combat.statusView(p)[1].temporary, 5)
    Actor.endTurn(s, s.enemies[1]); eq(p.statuses.strength, 3)
    status(p, "strength", 4); Actor.endTurn(s, p); eq(p.statuses.strength, 2); eq(p.temporaryStrength, 0)
    Actor.endTurn(s, p); eq(p.statuses.strength, 2)
    local before = Combat.copy(s); eq(pcall(Combat.addTemporaryStrength, p, -1), false); same(s, before)
end)

test("fully blocked positive attack still retaliates into block without modifiers or recursion", function()
    local s = battle(); local p, e = s.player, s.enemies[1]
    p.block = 40; e.block = 40; status(p, "thorns", 9); status(e, "thorns", 3)
    status(e, "strength", 50); status(p, "vulnerable", 2)
    local hp, enemyHp = p.hp, e.hp
    eq(Combat.damage(s, p, e, 6), 0)
    eq(p.hp, hp); eq(p.block, 37); eq(e.hp, enemyHp); eq(e.block, 34)
    eq(s.events[#s.events].detail.status, "thorns")
end)

test("thorns consumes full partial exact or absent block on either attacker", function()
    for _, enemyAttacks in ipairs({ false, true }) do
        for _, block in ipairs({ 5, 2, 3, 0 }) do
            local s = battle()
            local attacker = enemyAttacks and s.enemies[1] or s.player
            local defender = enemyAttacks and s.player or s.enemies[1]
            attacker.hp = 20; attacker.block = block
            status(attacker, "vulnerable", 2); status(attacker, "thorns", 7)
            status(defender, "thorns", 3); status(defender, "strength", 50); status(defender, "weak", 2)
            local hp, events = defender.hp, #s.events
            eq(Combat.damage(s, attacker, defender, 6), 6)
            eq(attacker.hp, 20 - math.max(0, 3 - block))
            eq(attacker.block, math.max(0, block - 3))
            eq(defender.hp, hp - 6); eq(#s.events, events + 2)
            local event = s.events[#s.events]
            same({kind=event.kind, detail=event.detail}, { kind = "status_damage", detail = {
                source = defender.id, target = attacker.id, status = "thorns",
                amount = math.max(0, 3 - block), blocked = math.min(block, 3) } })
            local frame = enemyAttacks and event.frame.enemies[1] or event.frame.player
            eq(frame.hp, attacker.hp); eq(frame.block, attacker.block)
        end
    end
end)

test("thorns consumes remaining block across multihits before HP", function()
    local s = battle(); local p, e = s.player, s.enemies[1]
    p.hp = 20; p.block = 5; status(e, "thorns", 3)
    local hp, events = e.hp, #s.events
    Combat.applyEffects(s, { { op = "damage", value = 1, times = 3 } }, p, e)
    eq(p.hp, 16); eq(p.block, 0); eq(e.hp, hp - 3); eq(e.statuses.thorns, 3)
    eq(#s.events, events + 6)
    eq(s.events[events + 2].detail.amount, 0)
    eq(s.events[events + 4].detail.amount, 1)
    eq(s.events[events + 6].detail.amount, 3)
end)

test("block absorbs thorns from a lethally hit defender without dropping retaliation", function()
    local s = battle(); local p, e = s.player, s.enemies[1]
    p.hp = 2; p.block = 3; e.hp = 1; status(e, "thorns", 2)
    local card
    for _, c in ipairs(s.hand) do if c.cardId == "strike" then card = c.uid end end
    assert(Combat.play(s, card, 1)); eq(p.hp, 2); eq(p.block, 1)
    eq(e.hp, 0); eq(s.phase, "victory")
end)

test("partial block still allows lethal thorns and stops remaining multihits", function()
    local s = battle(); local p, e = s.player, s.enemies[1]
    p.hp = 1; p.block = 2; status(e, "thorns", 3); local hp = e.hp
    Combat.applyEffects(s, { { op = "damage", value = 2, times = 3 }, { op = "block", value = 10 } }, p, e)
    eq(p.hp, 0); eq(e.hp, hp - 2); eq(p.block, 0)
    eq(s.events[#s.events].detail.amount, 1)
end)

test("zero damage attacks trigger thorns while fixed nonattack damage does not", function()
    local s = battle(); local p, e = s.player, s.enemies[1]; status(e, "thorns", 8)
    local hp = p.hp; Combat.damage(s, p, e, 0); eq(p.hp, hp - 8)
    Combat.damage(s, p, e, 5, true); eq(p.hp, hp - 8)
end)

test("lethal attack still retaliates and simultaneous deaths lose", function()
    local s = battle(); local p, e = s.player, s.enemies[1]
    p.hp = 2; e.hp = 1; status(e, "thorns", 2)
    local card
    for _, c in ipairs(s.hand) do if c.cardId == "strike" then card = c.uid end end
    assert(Combat.play(s, card, 1)); eq(p.hp, 0); eq(e.hp, 0); eq(s.phase, "defeat")
end)

test("thorns kills attacker before later multihits or effects", function()
    local s = battle(); local p, e = s.player, s.enemies[1]
    p.hp = 1; status(e, "thorns", 1); local hp = e.hp
    Combat.applyEffects(s, { { op = "damage", value = 2, times = 3 }, { op = "block", value = 10 } }, p, e)
    eq(p.hp, 0); eq(e.hp, hp - 2); eq(p.block, 0)
end)

test("each surviving multihit retaliates once without consuming thorns", function()
    local s = battle(); local p, e = s.player, s.enemies[1]
    status(e, "thorns", 2); local hp, enemyHp = p.hp, e.hp
    Combat.applyEffects(s, { { op = "damage", value = 1, times = 3 } }, p, e)
    eq(p.hp, hp - 6); eq(e.hp, enemyHp - 3); eq(e.statuses.thorns, 2)
end)

test("player regeneration occurs before enemy attack and temporary strength expires there", function()
    local s = battle(); local p = s.player; p.hp = p.maxHp - 5
    status(p, "regen", 3); Combat.addTemporaryStrength(p, 2)
    Combat.endTurn(s)
    eq(p.hp, p.maxHp - 5 + 3 - 11); eq(p.statuses.regen, 2); eq(p.statuses.strength, 0)
end)

test("temporary strength overflow rejects all related state changes", function()
    local s = battle(); Combat.addTemporaryStrength(s.player, 2147483647)
    local before = Combat.copy(s)
    eq(pcall(Combat.addTemporaryStrength, s.player, 2147483647), false); same(s, before)
end)

test("fresh battles do not share statuses temporary strength or definitions", function()
    local a, b = battle(), battle()
    status(a.player, "poison", 7); Combat.addTemporaryStrength(a.player, 3)
    a.catalog.statuses.poison.name = "changed"
    eq(b.player.statuses.poison, nil); eq(b.player.temporaryStrength, nil)
    eq(b.catalog.statuses.poison.name, "中毒")
    eq(data.statuses.statuses[6].name, "中毒")
end)

test("dead enemy attacker cannot regenerate or let later enemies act", function()
    local s = battle({ "jaw_worm", "jaw_worm" }); local e = s.enemies[1]
    e.hp = 1; status(e, "regen", 9); status(s.player, "thorns", 1)
    s.player.hp = 1
    Combat.endTurn(s)
    eq(e.hp, 0); eq(e.statuses.regen, 9); eq(e.intentIndex, 1)
    eq(s.enemies[2].intentIndex, 1); eq(s.phase, "defeat")
end)

test("thorns-killed enemy does not advance intent while surviving enemies continue", function()
    local s = battle({ "jaw_worm", "jaw_worm" }); local e = s.enemies[1]
    e.hp = 1; status(e, "regen", 9); status(s.player, "thorns", 1)
    local hp = s.player.hp
    Combat.endTurn(s)
    eq(e.hp, 0); eq(e.statuses.regen, 9); eq(e.intentIndex, 1)
    eq(s.enemies[2].jawLast, "jaw_worm_1"); assert(s.enemies[2].intentIndex ~= 1); eq(s.player.hp, hp - 22); eq(s.phase, "player")
end)

print("LUA_STATUSES_PASS " .. count)
