-- Diagnostic evidence, not a passing strict-parity test. Fixed method evidence:
-- docs/evidence/card-audit-m3/source-identity.json (Shockwave/Barricade use).
package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local C, data = require('abyss_combat'), require('abyss_data')
local function events(state, first)
    local result = {}
    for i = first, #state.events do
        local event = state.events[i]
        if event.kind == 'status' then
            result[#result + 1] = event.detail.target .. ':' .. event.detail.status .. ':' .. string.format('%.0f', event.detail.amount)
        end
    end
    return result
end
local function quote(value) return '"' .. value .. '"' end
local function array(values)
    local result = {}; for _, value in ipairs(values) do result[#result + 1] = quote(value) end
    return '[' .. table.concat(result, ',') .. ']'
end
local function report(id, expected, actual)
    local matches = table.concat(expected, '|') == table.concat(actual, '|')
    print('{"finding":' .. quote(id) .. ',"strictExpectedMatch":' .. tostring(matches)
        .. ',"expected":' .. array(expected) .. ',"actual":' .. array(actual) .. '}')
end
for _, upgraded in ipairs({false, true}) do
    local state = C.new(data, {seed = 42, deck = {{cardId = 'shockwave', upgraded = upgraded}}, enemies = {'cultist', 'jaw_worm'}})
    local first = #state.events + 1
    assert(C.play(state, state.hand[1].uid))
    local n = upgraded and '5' or '3'
    local a, b = state.enemies[1].id, state.enemies[2].id
    report('shockwave' .. (upgraded and '+' or ''), {
        a .. ':weak:' .. n, a .. ':vulnerable:' .. n,
        b .. ':weak:' .. n, b .. ':vulnerable:' .. n}, events(state, first))
end
local state = C.new(data, {seed = 42, deck = {'barricade', 'barricade'}, enemies = {'cultist'}})
state.energy = 6 -- Isolated sufficient-energy input, not natural acquisition.
assert(C.play(state, state.hand[1].uid))
local first = #state.events + 1
assert(C.play(state, state.hand[1].uid))
report('barricade-repeat', {}, events(state, first))
