-- aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0:
-- Healer.takeTurn (90-108) queues active recipient references once.
-- Real C.endTurn + unchanged production Act2 definitions, not replacement AI.
-- Events.emit mutations below are contract-boundary probes; production emit has
-- no callbacks. They are NOT a natural-gameplay reproduction or PC acceptance.
local C = require('abyss_combat')
local Data = require('abyss_data')
local Events = require('abyss_events')
local Act2 = require('abyss_act2_enemies')
local Run = require('abyss_run')
local passed, failed = 0, 0
local function eq(actual, expected, label)
    assert(actual == expected, (label or 'value') .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function test(name, fn)
    local ok, why = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1 end
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(why)))
end
local function setIntent(actor, id)
    for i, intent in ipairs(actor.intents) do
        if intent.id == id then actor.intentIndex = i; return end
    end
    error('missing production intent ' .. id)
end
local function battle(move, extras)
    local ids = C.copy(assert(Act2.resolve('Centurion and Healer', 'normal')).enemies)
    for _, id in ipairs(extras or {}) do ids[#ids + 1] = id end
    local streams = Run.roomStreams({runSeed = '42'}, 18)
    local s = C.new(Data, { seed = 42, deck = {}, enemies = ids, hp = 500, maxHp = 500,
        roomSeed = streams.seed, roomStreams = streams })
    local tank, mage = s.enemies[1], s.enemies[2]
    setIntent(tank, 'protect'); setIntent(mage, move)
    -- Keep exact production op/amount/target payloads throughout every test.
    local effect = mage.intents[mage.intentIndex].effects[1]
    eq(effect.op, move == 'heal' and 'enemyHealAll' or 'enemyStrengthAll')
    eq(effect.value, move == 'heal' and 16 or 2)
    for _, actor in ipairs(s.enemies) do actor.hp = 1 end
    return s, tank, mage
end
local function strength(actor) return actor.statuses.strength or 0 end
local function expectEffect(actor, move, applied)
    eq(actor.hp, move == 'heal' and applied and math.min(17, actor.maxHp) or 1, actor.id .. ' HP')
    eq(strength(actor), move == 'buff' and applied and 2 or 0, actor.id .. ' Strength')
end
local function partyEvents(s, source)
    local result = {}
    for _, event in ipairs(s.events) do
        local d = event.detail
        if type(d) == 'table' and d.source == source.id and (event.kind == 'heal' or event.kind == 'status' and d.status == 'strength') then
            result[#result + 1] = d
        end
    end
    return result
end
local function onFirstPartyEvent(s, mage, mutation)
    local emit, seen = Events.emit, false
    Events.emit = function(state, kind, detail)
        local result = emit(state, kind, detail)
        if not seen and state == s and type(detail) == 'table' and detail.source == mage.id
            and (kind == 'heal' or kind == 'status' and detail.status == 'strength') then
            seen = true; mutation(state)
        end
        return result
    end
    local called, result = pcall(C.endTurn, s)
    Events.emit = emit
    assert(called, result); eq(result, true, 'endTurn'); eq(seen, true, 'party event observed')
end
for _, move in ipairs({'heal', 'buff'}) do
    test(move .. ': production group order includes self, never player, and caps healing', function()
        local s, tank, mage = battle(move)
        mage.hp = mage.maxHp - 3
        assert(C.endTurn(s))
        expectEffect(tank, move, true)
        eq(mage.hp, move == 'heal' and mage.maxHp or mage.maxHp - 3)
        eq(strength(mage), move == 'buff' and 2 or 0)
        eq(s.player.hp, 500); eq(strength(s.player), 0)
        local events = partyEvents(s, mage)
        eq(#events, 2); eq(events[1].target, tank.id); eq(events[2].target, mage.id)
        eq(events[1].amount, move == 'heal' and 16 or 2)
        eq(events[2].amount, move == 'heal' and 3 or 2)
        eq(s.enemies[1], tank, 'tank identity'); eq(s.enemies[2], mage, 'caster identity')
    end)
    test(move .. ': injected append cannot join captured recipients (contract boundary)', function()
        local s, tank, mage = battle(move)
        local appended = C.copy(tank); appended.id = 'appended_after_capture'; appended.block = 0
        onFirstPartyEvent(s, mage, function(state) state.enemies[#state.enemies + 1] = appended end)
        expectEffect(appended, move, false); expectEffect(mage, move, true)
        local events = partyEvents(s, mage)
        eq(#events, 2); eq(events[1].target, tank.id); eq(events[2].target, mage.id)
    end)
    test(move .. ': captured actor reference survives same-ID list replacement (contract boundary)', function()
        local s, _, mage = battle(move, {'cultist'})
        local captured = s.enemies[3]
        local replacement = C.copy(captured)
        eq(replacement.id, captured.id); assert(replacement ~= captured)
        onFirstPartyEvent(s, mage, function(state) state.enemies[3] = replacement end)
        eq(s.enemies[3], replacement); expectEffect(captured, move, true); expectEffect(replacement, move, false)
        eq(#partyEvents(s, mage), 3)
    end)
    test(move .. ': initially dead/escaped actors remain excluded even if made active later (contract boundary)', function()
        local s, _, mage = battle(move, {'cultist', 'cultist'})
        local dead, escaped = s.enemies[3], s.enemies[4]
        dead.hp = 0; escaped.escaped = true
        onFirstPartyEvent(s, mage, function() dead.hp = 1; escaped.escaped = nil end)
        expectEffect(dead, move, false); expectEffect(escaped, move, false)
        eq(#partyEvents(s, mage), 2)
    end)
    test(move .. ': later death skips captured recipient without resurrection (contract boundary)', function()
        local s, _, mage = battle(move, {'cultist'})
        local captured = s.enemies[3]
        onFirstPartyEvent(s, mage, function() captured.hp = 0 end)
        eq(captured.hp, 0); eq(strength(captured), 0); eq(#partyEvents(s, mage), 2)
    end)
    test(move .. ': later escape skips captured recipient (contract boundary)', function()
        local s, _, mage = battle(move, {'cultist'})
        local captured = s.enemies[3]
        onFirstPartyEvent(s, mage, function() captured.escaped = true end)
        expectEffect(captured, move, false); eq(#partyEvents(s, mage), 2)
    end)
    test(move .. ': queued later recipient retains dead caster source (contract boundary)', function()
        local s, tank, mage = battle(move, {'cultist'})
        local captured = s.enemies[3]
        onFirstPartyEvent(s, mage, function() mage.hp = 0 end)
        eq(mage.hp, 0); eq(strength(mage), 0); expectEffect(captured, move, true)
        local events = partyEvents(s, mage)
        eq(#events, 2); eq(events[1].target, tank.id); eq(events[2].target, captured.id)
        eq(events[2].source, mage.id)
    end)
    test(move .. ': live actor with pending escape intent is still a recipient', function()
        local s, _, mage = battle(move, {'looter'})
        local escaping = s.enemies[3]; setIntent(escaping, 'looter_escape')
        assert(C.endTurn(s)); expectEffect(escaping, move, true); eq(escaping.escaped, true)
        eq(#partyEvents(s, mage), 3)
    end)
    test(move .. ': failed advanced turn restores party aliases and values', function()
        local s, tank, mage = battle(move)
        s.experimentalMechanics = true; s.player.statuses.berserk = 0
        local enemies, before, emit, seen = s.enemies, C.copy(s), Events.emit, false
        Events.emit = function(state, kind, detail)
            local result = emit(state, kind, detail)
            if type(detail) == 'table' and detail.source == mage.id and (kind == 'heal' or kind == 'status' and detail.status == 'strength') then
                seen = true; error('snapshot regression injected rollback')
            end
            return result
        end
        local called, why = pcall(C.endTurn, s); Events.emit = emit
        eq(called, false); eq(seen, true); assert(tostring(why):find('snapshot regression injected rollback', 1, true))
        eq(s.enemies, enemies); eq(s.enemies[1], tank); eq(s.enemies[2], mage)
        eq(tank.hp, before.enemies[1].hp); eq(mage.hp, before.enemies[2].hp)
        eq(strength(tank), 0); eq(strength(mage), 0); eq(#s.events, #before.events)
        eq(s.seed, before.seed); eq(s.turn, before.turn); eq(s.phase, before.phase)
        eq(s.aiRng.counter, before.aiRng.counter); eq(s.monsterHpRng.counter, before.monsterHpRng.counter)
    end)
end

test('Collector shared Strength branch keeps production Block15 then ordered Strength3', function()
    local s = C.new(Data, {seed = 42, deck = {}, enemies = {'collector'}, hp = 500, maxHp = 500})
    local collector = s.enemies[1]
    assert(C.endTurn(s)) -- production spawn, no injected replacement definitions
    setIntent(collector, 'buff')
    local first = #s.events + 1
    assert(C.endTurn(s)); eq(collector.block, 15)
    local result = {}
    for i = first, #s.events do
        local event = s.events[i]; local d = event.detail
        if type(d) == 'table' and d.source == collector.id and (event.kind == 'block' or event.kind == 'status' and d.status == 'strength') then
            result[#result + 1] = event
        end
    end
    eq(#result, 4); eq(result[1].kind, 'block'); eq(result[1].detail.amount, 15)
    for i, actor in ipairs(s.enemies) do
        eq(strength(actor), 3); eq(result[i + 1].detail.target, actor.id); eq(result[i + 1].detail.amount, 3)
    end
end)
print('ACT2_PARTY_SNAPSHOT ' .. passed .. ' passed; ' .. failed .. ' failed')
assert(failed == 0, tostring(failed) .. ' party recipient contract mismatches')
