-- Real starting stats/deck/AI and a naturally earned Fire Potion reach a lethal
-- potion transaction. Only the post-reward failure is injected; no combat or
-- random results are replaced. This is offline coverage, not platform evidence.
package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local Run, Combat, Random, Data = require('abyss_run'), require('abyss_combat'),
    require('abyss_sts_random'), require('abyss_data')
local passed, failed = 0, 0
local function test(name, fn)
    local ok, reason = pcall(fn)
    if ok then passed = passed + 1; print('PASS ' .. name)
    else failed = failed + 1; print('FAIL ' .. name .. ': ' .. tostring(reason)) end
end
local function same(a, b)
    assert(type(a) == type(b), 'changed value type')
    if type(a) ~= 'table' then assert(a == b, 'changed value'); return end
    for key, value in pairs(a) do same(value, b[key]) end
    for key in pairs(b) do assert(a[key] ~= nil, 'added field: ' .. tostring(key)) end
end
local function unchanged(root)
    local saved = {}
    local function visit(value)
        if type(value) ~= 'table' or saved[value] then return end
        local fields = {}; saved[value] = fields
        for key, child in pairs(value) do fields[key] = child; visit(child) end
    end
    visit(root)
    return function()
        for value, fields in pairs(saved) do
            for key, child in pairs(fields) do
                assert(value[key] == child, 'changed reference/value: ' .. tostring(key))
            end
            for key in pairs(value) do assert(fields[key] ~= nil, 'added field: ' .. tostring(key)) end
        end
    end
end
local function playOneCommand(run)
    local selected
    for _, card in ipairs(run.combat.hand) do
        if Combat.canPlay(run.combat, card.uid, 1) then
            if not selected or Combat.cardDefinition(run.combat, card).type == 'attack' then selected = card end
        end
    end
    if selected then assert(Run.play(run, selected.uid, 1)) else assert(Run.endTurn(run)) end
end
local cached
local function beforeLethalPotion()
    if cached then return Combat.copy(cached) end
    local run = Run.new(Data, 4)
    assert(run.hp == 80 and run.gold == 99 and #run.deck == 10)
    assert(Run.startCombat(run, 'cultist_solo'))
    for _ = 1, 150 do
        if run.phase ~= 'combat' then break end
        playOneCommand(run)
    end
    assert(run.phase == 'reward' and run.rewards.potion.id == 'fire_potion')
    assert(Run.claimPotionReward(run)); assert(Run.claimCardReward(run, 0))
    assert(Run.startCombat(run, 'cultist_solo'))
    for _ = 1, 150 do
        if run.combat.enemies[1].hp <= 20 then break end
        playOneCommand(run); assert(run.phase == 'combat')
    end
    assert(run.combat.enemies[1].hp == 18 and run.potions[1] == 'fire_potion')
    assert(run.shopRng.potion.counter == 3 and run.potionChanceModifier == -10)
    cached = run
    return Combat.copy(run)
end

test('lethal potion commits the new reward stream exactly once on success', function()
    local run = beforeLethalPotion()
    local merchant, card = Random.snapshot(run.shopRng.merchant), Random.snapshot(run.shopRng.card)
    local gold, nextUid = run.gold, run.nextDeckUid
    assert(Run.usePotion(run, 1, 1))
    assert(run.phase == 'reward' and run.potions[1] == nil and run.combat.enemies[1].hp == 0)
    assert(run.gold == gold + 15 and run.nextDeckUid == nextUid and #run.deck == 10)
    assert(run.rewards.potion.id == 'fire_potion' and not run.rewards.potion.resolved)
    assert(run.potionChanceModifier == -20)
    -- Recorded from the verified unmodified provider for seed 4: the second
    -- reward consumes drop, rarity and supported-pool draws, not zero or six.
    same(Random.snapshot(run.shopRng.potion), {
        words = {'c75cd73704de29da', 'c976c2013784576d'}, counter = 6,
    })
    same(Random.snapshot(run.shopRng.merchant), merchant)
    same(Random.snapshot(run.shopRng.card), card)
    local check = unchanged(run)
    local ok, reason = Run.usePotion(run, 1, 1)
    assert(not ok and reason == 'not_in_combat'); check()
end)

for _, mode in ipairs({'throw', 'reject'}) do
    test('post-reward ' .. mode .. ' preserves the live potion stream and every existing reference', function()
        local run = beforeLethalPotion()
        local before, check = Combat.copy(run), unchanged(run)
        local finish = Run.finishCombat
        Run.finishCombat = function(candidate)
            assert(finish(candidate)) -- Execute the real reward/RNG commit first.
            if mode == 'throw' then error('injected post-reward failure') end
            return false, 'injected_post_reward_rejection'
        end
        local called, ok, reason = pcall(Run.usePotion, run, 1, 1)
        Run.finishCombat = finish -- Restore even if the command throws unexpectedly.
        assert(called and not ok and reason == 'potion_effect_failed')
        same(run, before); check()
        assert(run.shopRng.potion.counter == 3 and run.potionChanceModifier == -10)
        -- A refused attempt must not poison the next legitimate attempt.
        assert(Run.usePotion(run, 1, 1))
        assert(run.phase == 'reward' and run.potions[1] == nil)
        assert(run.shopRng.potion.counter == 6 and run.potionChanceModifier == -20)
    end)
end
test('legacy run without shopRng keeps a failed initialization private and can retry', function()
    local run = beforeLethalPotion()
    -- Explicit old-run shape fixture; the earned bottle and real combat stay intact.
    run.shopRng, run.potionChanceModifier = nil, nil
    local before, check = Combat.copy(run), unchanged(run)
    local finish = Run.finishCombat
    Run.finishCombat = function(candidate)
        assert(finish(candidate))
        error('injected first-stream reward failure')
    end
    local called, ok, reason = pcall(Run.usePotion, run, 1, 1)
    Run.finishCombat = finish
    assert(called and not ok and reason == 'potion_effect_failed')
    same(run, before); check(); assert(run.shopRng == nil)
    assert(Run.usePotion(run, 1, 1))
    assert(run.phase == 'reward' and run.potions[1] == nil)
    assert(run.shopRng.potion.counter == 3 and run.potionChanceModifier == -10)
    assert(run.shopRng.merchant.counter == 0 and run.shopRng.card.counter == 0)
end)
print('LUA_POTION_REWARD_ATOMIC ' .. passed .. ' passed; ' .. failed .. ' failed')
assert(failed == 0, 'Potion reward transaction failures: ' .. failed)
