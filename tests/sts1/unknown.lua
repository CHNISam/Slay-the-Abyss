local loaded, Unknown = pcall(require, 'abyss_unknown')
assert(loaded, 'StS1 basic unknown-room reducer is not implemented')
local vectors = require('sts1_unknown_vectors')
local base = { monster = 10, shop = 3, treasure = 2 }
local count = 0
local function test(name, run)
    run(); count = count + 1; print('ok unknown ' .. count .. ' - ' .. name)
end
local function same(a, b)
    assert(a.version == b.version and a.monster == b.monster and a.shop == b.shop and a.treasure == b.treasure)
end
local function percent(value) return math.floor(value * 100 + 0.5) end

test('all supplied StS1 basic-only deterministic vectors', function()
    for _, case in ipairs(vectors.cases) do
        local state = { version = 1, monster = percent(case.state.monster), shop = percent(case.state.shop), treasure = percent(case.state.treasure) }
        local result = Unknown.advance(state, case.roll, base)
        assert(result == case.expected, case.id .. ': ' .. tostring(result))
        same(state, { version = 1, monster = percent(case.next.monster), shop = percent(case.next.shop), treasure = percent(case.next.treasure) })
    end
end)

test('sequence grows each miss and resets only the selected outcome', function()
    local state = Unknown.new(base)
    assert(Unknown.advance(state, 0.7, base) == 'event')
    assert(Unknown.advance(state, 0.15, base) == 'monster')
    same(state, { version = 1, monster = 10, shop = 9, treasure = 6 })
end)

test('cumulative probabilities above one retain priority without normalization or clamp', function()
    local state = { version = 1, monster = 90, shop = 30, treasure = 20 }
    assert(Unknown.advance(state, 0.95, base) == 'shop')
    same(state, { version = 1, monster = 100, shop = 3, treasure = 22 })
    assert(Unknown.advance(state, 0.999999, base) == 'monster')
    same(state, { version = 1, monster = 10, shop = 6, treasure = 24 })
end)

test('invalid rolls fail atomically, including NaN and the excluded upper endpoint', function()
    for _, bad in ipairs({ -0.01, 1, 1.5, 0/0, math.huge, '0.1', false }) do
        local state = Unknown.new(base); local before = Unknown.snapshot(state)
        assert(not pcall(Unknown.advance, state, bad, base)); same(state, before)
    end
    local state = Unknown.new(base)
    assert(Unknown.advance(state, 0, base) == 'monster')
end)

test('snapshots restore independently and reject malformed counters or extra fields', function()
    local state = Unknown.new(base)
    Unknown.advance(state, 0.8, base)
    local snapshot = Unknown.snapshot(state)
    local restored = assert(Unknown.restore(snapshot, base))
    Unknown.advance(restored, 0.15, base)
    same(state, snapshot)
    snapshot.monster = 30; assert(state.monster == 20)
    for _, bad in ipairs({ {}, { version = 2, monster = 10, shop = 3, treasure = 2 },
        { version = 1, monster = 0, shop = 3, treasure = 2 },
        { version = 1, monster = 11, shop = 3, treasure = 2 },
        { version = 1, monster = 10, shop = 3.5, treasure = 2 },
        { version = 1, monster = 10, shop = 3, treasure = 2, juzu = true } }) do
        assert(Unknown.restore(bad, base) == nil)
    end
end)

test('long event sequences preserve exact percent counters and restore the same next transition', function()
    local state = Unknown.new(base)
    for i = 1, 10000 do
        local restored = assert(Unknown.restore(Unknown.snapshot(state), base))
        local roll = (i % 997) / 997
        assert(Unknown.advance(restored, roll, base) == Unknown.advance(state, roll, base))
        same(restored, state)
    end
end)
print('LUA_UNKNOWN_PASS ' .. count)
