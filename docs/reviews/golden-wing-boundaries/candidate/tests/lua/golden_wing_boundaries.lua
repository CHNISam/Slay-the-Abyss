-- Bounded Golden Wing rule review: explicit event/deck fixtures, not natural-run or platform evidence.
-- Expected qualification is independently fixed from GoldenWing/CardHelper and original card constructors.
package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local C, Run, Map, Nodes = require('abyss_combat'), require('abyss_run'), require('abyss_map'), require('abyss_nodes')
local data = require('abyss_data')
local baseMap = Map.generate(data, 42)
local n, failed = 0, 0
local function eq(a, b, label) assert(a == b, (label or 'value') .. ': ' .. tostring(a) .. ' ~= ' .. tostring(b)) end
local function same(a, b, path)
    path = path or 'state'
    eq(type(a), type(b), path .. ' type')
    if type(a) ~= 'table' then return eq(a, b, path) end
    for k, v in pairs(a) do same(v, b[k], path .. '.' .. tostring(k)) end
    for k in pairs(b) do assert(a[k] ~= nil, path .. ' extra ' .. tostring(k)) end
end
local function test(name, fn)
    n = n + 1
    local ok, err = pcall(fn)
    if not ok then failed = failed + 1 end
    print((ok and 'ok ' or 'not ok ') .. n .. ' - ' .. name .. (ok and '' or ': ' .. tostring(err)))
end
local function enter(cardId, upgraded, hp, relics)
    local run, map = Run.new(data, 42), C.copy(baseMap)
    -- Exact permanent UID is retained; only this test's deck composition is staged.
    run.deck = { { uid = run.deck[1].uid, cardId = cardId, upgraded = upgraded } }
    if hp then run.hp = hp end
    if relics then run.relics = C.copy(relics) end
    map.nodes[1].type, map.nodes[1].eventId = 'event', 'golden_wing'
    assert(Nodes.enter(run, map, map.nodes[1].id))
    return run, map
end
local function refuseUnchanged(run, map, choice, uid, reason)
    local before = C.copy({ run = run, map = map })
    local ok, actualReason = Nodes.chooseEvent(run, choice, uid)
    eq(ok, false, choice .. ' refused')
    eq(actualReason, reason, choice .. ' reason')
    same({ run = run, map = map }, before)
end

-- These are fixed source expectations, not values recomputed from the production predicate.
for _, row in ipairs({
    { 'strike', false, false, 'base 6' }, { 'strike', true, false, 'upgraded 9 below threshold' },
    { 'bash', false, false, 'base 8' }, { 'bash', true, true, 'upgraded 10 exactly at threshold' },
    { 'cleave', false, false, 'AOE base 8' }, { 'cleave', true, true, 'AOE upgraded 11' },
    { 'twin_strike', false, false, 'two hits of 5 are not base damage 10' },
    { 'twin_strike', true, false, 'two hits of 7 are not base damage 14' },
    { 'body_slam', false, false, 'variable block damage is not a fixed base 10' },
    { 'body_slam', true, false, 'cost-only upgrade does not create base damage' },
}) do
    test('qualification: ' .. row[1] .. ' ' .. row[4], function()
        local run, map = enter(row[1], row[2])
        eq(run.nodeFlow.event.canAttack, row[3], 'captured qualification')
        eq(Nodes.view(run, map).node.event.options[2].enabled, row[3], 'displayed qualification')
        if not row[3] then
            refuseUnchanged(run, map, 'take_gold', nil, 'event_condition_unmet')
        else
            local before = C.copy(run)
            assert(Nodes.chooseEvent(run, 'take_gold'))
            assert(run.gold >= before.gold + 50 and run.gold <= before.gold + 80)
            eq(run.miscRng.counter, before.miscRng.counter + 1, 'one gold draw')
            eq(run.hp, before.hp, 'gold choice hp')
            same(run.deck, before.deck); same(run.eventRng, before.eventRng)
            same(run.cardRng, before.cardRng); same(run.treasureRng, before.treasureRng)
            eq(run.phase, 'map'); eq(run.nodeFlow.complete, true)
            refuseUnchanged(run, map, 'take_gold', nil, 'no_pending_node')
        end
    end)
end

test('Vajra strength does not turn upgraded Strike base 9 into event eligibility', function()
    local run, map = enter('strike', true, nil, { 'burning_blood', 'vajra' })
    eq(run.nodeFlow.event.canAttack, false)
    refuseUnchanged(run, map, 'take_gold', nil, 'event_condition_unmet')
end)

test('eligibility stays captured at entry rather than recomputed by later requests', function()
    local run, map = enter('strike', true)
    run.deck[1].cardId, run.deck[1].upgraded = 'bash', true
    eq(Nodes.view(run, map).node.event.options[2].enabled, false)
    refuseUnchanged(run, map, 'take_gold', nil, 'event_condition_unmet')
    run, map = enter('bash', true)
    run.deck[1].cardId, run.deck[1].upgraded = 'strike', false
    eq(Nodes.view(run, map).node.event.options[2].enabled, true)
    assert(Nodes.chooseEvent(run, 'take_gold'))
end)

for _, hp in ipairs({ 1, 6, 7 }) do
    test('sacrifice at hp ' .. hp .. ' finishes defeat before any purge can commit', function()
        local run, map = enter('bash', true, hp)
        local before = C.copy(run)
        local ok, result = Nodes.chooseEvent(run, 'sacrifice')
        eq(ok, true); assert(result ~= 'choose_purge')
        eq(run.hp, 0); eq(run.phase, 'defeat'); eq(run.nodeFlow.complete, true)
        eq(#Nodes.available(run, map), 0)
        same(run.deck, before.deck); eq(run.nextDeckUid, before.nextDeckUid); eq(run.gold, before.gold)
        same(run.miscRng, before.miscRng); same(run.eventRng, before.eventRng)
        same(run.cardRng, before.cardRng); same(run.treasureRng, before.treasureRng)
        for _, choice in ipairs({ 'sacrifice', 'take_gold', 'purge', 'leave' }) do
            refuseUnchanged(run, map, choice, before.deck[1].uid, 'no_pending_node')
        end
    end)
end

test('surviving sacrifice is paid once and locks every alternative until exact UID purge', function()
    local run, map = enter('bash', true, 8)
    local before, uid = C.copy(run), run.deck[1].uid
    local ok, result = Nodes.chooseEvent(run, 'sacrifice')
    eq(ok, true); eq(result, 'choose_purge'); eq(run.hp, 1)
    eq(run.phase, 'node'); eq(run.nodeFlow.complete, false); eq(run.nodeFlow.event.stage, 'purge')
    same(run.deck, before.deck); eq(run.gold, before.gold)
    same(run.miscRng, before.miscRng); same(run.eventRng, before.eventRng)
    for _, choice in ipairs({ 'sacrifice', 'take_gold', 'leave' }) do
        refuseUnchanged(run, map, choice, uid, 'invalid_event_choice')
    end
    refuseUnchanged(run, map, 'purge', uid + 999, 'invalid_card')
    assert(Nodes.purgeWing(run, uid))
    eq(run.hp, 1); eq(#run.deck, 0); eq(run.nextDeckUid, before.nextDeckUid)
    eq(run.phase, 'map'); eq(run.nodeFlow.complete, true)
    same(run.miscRng, before.miscRng); same(run.eventRng, before.eventRng)
    refuseUnchanged(run, map, 'purge', uid, 'no_pending_node')
end)

print('GOLDEN_WING_BOUNDARIES ' .. n .. ' tests, ' .. failed .. ' failed')
assert(failed == 0)
