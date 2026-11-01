package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local Combat = require('abyss_combat')
local data = require('abyss_data')
local count, failed = 0, 0
local proofCase = ''
local function equal(actual, expected, name)
    assert(actual == expected, '[ABYSS_ASSERT M1:' .. proofCase .. '] ' .. (name or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function test(name, run)
    proofCase = name
    count = count + 1
    local ok, reason = pcall(run)
    if ok then print('ok ' .. count .. ' - ' .. name)
    else failed = failed + 1; print('not ok ' .. count .. ' - ' .. name .. ': ' .. tostring(reason)) end
end
local function battle(card, enemies)
    return Combat.new(data, { deck = { card }, enemies = enemies, seed = 42 })
end
-- Retain every original table and every key/value, including catalog aliases,
-- card instances, event details, enemy intents and all otherwise read-only data.
local function unchangedAfter(state)
    local saved = {}
    local function visit(t)
        if type(t) ~= 'table' or saved[t] then return end
        local values = {}; saved[t] = values
        for k, v in pairs(t) do values[k] = v; visit(k); visit(v) end
    end
    visit(state)
    return function()
        for original, values in pairs(saved) do
            for k, v in pairs(values) do equal(original[k], v, 'original key ' .. tostring(k)) end
            for k, v in pairs(original) do equal(v, values[k], 'unexpected key ' .. tostring(k)) end
        end
    end
end
local function rejected(state, target, pattern)
    local uid = state.hand[1].uid
    assert(Combat.canPlay(state, uid, target), 'failure must occur after canPlay')
    local check = unchangedAfter(state)
    local ok, reason = pcall(Combat.play, state, uid, target)
    equal(ok, false, 'must preserve thrown-error convention')
    assert(tostring(reason):find(pattern, 1, true), tostring(reason))
    check()
end

test('real inflame overflow preserves every value and reference', function()
    local s = battle('inflame')
    -- Hostile-state fixture: the public status API now clamps signed stats to 999.
    s.player.statuses.strength = 2147483647
    rejected(s, nil, 'status stack overflow')
end)

test('real upgraded inflame overflow remains atomic', function()
    local s = Combat.new(data, { deck = {{cardId = 'inflame', upgraded = true}}, seed = 42 })
    -- Hostile-state fixture, not a reachable public status application.
    s.player.statuses.strength = 2147483645
    rejected(s, nil, 'status stack overflow')
end)

test('real bash restores damage, block, thorns and earlier events before status overflow', function()
    local s = battle('bash')
    Combat.addStatus(s.enemies[1], 'vulnerable', 2147483647)
    Combat.addStatus(s.enemies[1], 'thorns', 3)
    s.enemies[1].block = 2
    rejected(s, 1, 'status stack overflow')
end)

test('real shockwave rolls back first enemy and earlier status on later enemy overflow', function()
    local s = battle('shockwave', {'cultist', 'jaw_worm'})
    Combat.addStatus(s.enemies[2], 'vulnerable', 2147483647)
    rejected(s, nil, 'status stack overflow')
end)

test('unknown status after successful block, energy and strength restores inserted keys', function()
    local s = battle('defend')
    -- Controlled malformed content, not a shipped card or normal-run claim.
    s.catalog.cards.defend.effects = {{op='block', value=8}, {op='energy', value=2},
        {op='gainStatus', status='strength', value=2}, {op='gainStatus', status='missing', value=1}}
    rejected(s, nil, 'unknown status: missing')
end)

test('negative status amount after damage restores target and player', function()
    local s = battle('bash')
    s.catalog.cards.bash.effects[2].value = -1
    rejected(s, 1, 'invalid status amount')
end)

local function reshuffleBattle()
    local s = Combat.new(data, { deck = {'shrug_it_off', 'strike', 'defend', 'bash'}, seed = 42 })
    local kept
    for _, card in ipairs(s.hand) do
        if card.cardId == 'shrug_it_off' then kept = card else s.discard[#s.discard+1] = card end
    end
    for i = #s.hand, 1, -1 do table.remove(s.hand, i) end
    s.hand[1] = kept
    return s
end

test('draw then reshuffle then overflow restores old piles, RNG and all card identities', function()
    local s = reshuffleBattle()
    s.catalog.cards.shrug_it_off.effects[#s.catalog.cards.shrug_it_off.effects+1] =
        {op='gainStatus', status='strength', value=2}
    -- Hostile-state fixture: the public status API now clamps signed stats to 999.
    s.player.statuses.strength = 2147483647
    rejected(s, nil, 'status stack overflow')
end)

test('full-hand draw overflow followed by error restores discard and draw order', function()
    local s = reshuffleBattle()
    s.rules.player.maxHand = 0 -- controlled draw overflow boundary
    s.catalog.cards.shrug_it_off.effects[#s.catalog.cards.shrug_it_off.effects+1] =
        {op='gainStatus', status='missing', value=1}
    rejected(s, nil, 'unknown status: missing')
end)

test('controlled failure restores noDraw, HP and temporary player fields, preserving error object', function()
    local s = battle('defend')
    local check, original, marker = unchangedAfter(s), Combat.applyEffects, {}
    local calls = 0
    Combat.applyEffects = function(state, effects, source, target)
        calls = calls + 1
        original(state, effects, source, target)
        source.hp, source.noDraw, source.temporaryStrength = source.hp - 6, true, 3
        error(marker)
    end
    local ok, reason = pcall(Combat.play, s, s.hand[1].uid)
    Combat.applyEffects = original
    equal(ok, false); equal(reason, marker); equal(calls, 1); check()
end)

test('failed card remains playable after correcting only the overflow condition', function()
    local s = battle('inflame')
    local instance, statuses = s.hand[1], s.player.statuses
    -- Hostile-state fixture: the public status API now clamps signed stats to 999.
    s.player.statuses.strength = 2147483647
    rejected(s, nil, 'status stack overflow')
    Combat.addStatus(s.player, 'strength', -2147483647)
    equal(Combat.play(s, instance.uid), true)
    equal(s.player.statuses, statuses); equal(statuses.strength, 2)
    equal(#s.exhaust, 0); equal(#s.discard, 0); equal(s.energy, 2); equal(#s.hand, 0)
end)

test('successful real bash keeps identities, ordering and exactly one effect execution', function()
    local s = battle('bash')
    local player, enemy, statuses = s.player, s.enemies[1], s.enemies[1].statuses
    local hand, discard, events, instance = s.hand, s.discard, s.events, s.hand[1]
    local catalog, definitions = s.catalog, s.player.statusDefinitions
    local hp, n, calls, original = enemy.hp, #events, 0, Combat.applyEffects
    Combat.applyEffects = function(... ) calls = calls + 1; return original(...) end
    local ok, result, reason = pcall(Combat.play, s, instance.uid, 1)
    Combat.applyEffects = original
    assert(ok, tostring(result)); equal(result, true); equal(reason, nil); equal(calls, 1)
    equal(s.player, player); equal(s.enemies[1], enemy); equal(enemy.statuses, statuses)
    equal(s.hand, hand); equal(s.discard, discard); equal(s.events, events)
    equal(s.catalog, catalog); equal(player.statusDefinitions, definitions)
    equal(definitions, catalog.statuses); equal(enemy.statusDefinitions, definitions)
    equal(enemy.hp, hp - 8); equal(statuses.vulnerable, 2); equal(s.energy, 1)
    equal(discard[1], instance); equal(#hand, 0)
    equal(events[n+1].kind, 'play'); equal(events[n+1].detail.uid, instance.uid)
    equal(events[n+2].kind, 'damage'); equal(events[n+3].kind, 'status'); equal(#events, n+3)
    equal(events[n+3].detail.status, 'vulnerable'); equal(events[n+3].detail.amount, 2)
end)

test('successful reshuffle retains original pile swap and RNG draw sequence', function()
    local s = reshuffleBattle()
    local originalDiscard, originalDraw, originalHand = s.discard, s.draw, s.hand
    local instance, seed, n = s.hand[1], s.seed, #s.events
    local order = {table.unpack(s.discard)}
    for i = #order, 2, -1 do
        seed = (seed * 25173 + 13849) % 65536
        local j = seed % i + 1
        order[i], order[j] = order[j], order[i]
    end
    equal(Combat.play(s, instance.uid), true)
    equal(s.hand, originalHand); equal(s.draw, originalDiscard)
    assert(s.discard ~= originalDiscard and s.discard ~= originalDraw)
    equal(s.hand[1], order[#order]); equal(s.draw[1], order[1]); equal(s.draw[2], order[2])
    equal(s.discard[1], instance); equal(s.seed, seed); equal(s.player.block, 8)
    equal(s.events[n+1].kind, 'play'); equal(s.events[n+2].kind, 'block')
    equal(s.events[n+3].kind, 'reshuffle'); equal(#s.events, n+3)
end)

test('successful lethal attack retains discard then victory and no replay', function()
    local s = battle('strike')
    Combat.addStatus(s.player, 'strength', 100)
    local instance, n = s.hand[1], #s.events
    equal(Combat.play(s, instance.uid, 1), true)
    equal(s.phase, 'victory'); equal(s.discard[1], instance)
    equal(s.events[n+1].kind, 'play'); equal(s.events[n+2].kind, 'damage')
    equal(s.events[n+3].kind, 'victory'); equal(#s.events, n+3)
end)

test('canPlay rejection keeps false reason convention and complete state', function()
    local s = battle('bash')
    local check = unchangedAfter(s)
    local ok, reason = Combat.play(s, s.hand[1].uid, 99)
    equal(ok, false); equal(reason, 'invalid_target'); check()
    s.energy = 0; check = unchangedAfter(s)
    ok, reason = Combat.play(s, s.hand[1].uid, 1)
    equal(ok, false); equal(reason, 'insufficient_energy'); check()
end)

print('ATOMIC_PLAY ' .. (count - failed) .. '/' .. count .. ' passed')
assert(failed == 0, tostring(failed) .. ' atomic play tests failed')
