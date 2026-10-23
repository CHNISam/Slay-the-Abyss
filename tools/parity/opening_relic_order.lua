-- Diagnostic parity gate, deliberately outside the ordinary passing regression suite.
-- Fixed source chain and scope: docs/rules/OPENING_RELIC_ORDER.md.
-- Reads existing event frames only: no hooks, simulated effects, or production edits.
package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local Run = require('abyss_run')
local data = require('abyss_data')
local failed, passed = 0, 0
local function equal(a,b) assert(a == b, tostring(a)..' ~= '..tostring(b)) end
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed=passed+1; print('PASS '..name)
    else failed=failed+1; print('FAIL '..name..': '..tostring(err)) end
end
local function battle(relics)
    local run = Run.new(data, 42)
    -- An owned-relic fixture, not a claim about natural acquisition RNG.
    run.relics = relics
    assert(Run.startCombat(run, 'cultist_solo'))
    return run.combat
end
local function statuses(state)
    local out={}
    for _, e in ipairs(state.events) do
        if e.kind == 'status' and e.detail.target == 'player' then out[#out+1]=e end
    end
    return out
end
local definitions = {
    {'vajra','strength',1}, {'oddly_smooth_stone','dexterity',1}, {'bronze_scales','thorns',3}
}
for _, item in ipairs(definitions) do
    test(item[1]..' applies before ordinary opening draw', function()
        local state=battle({item[1]})
        equal(state.player.statuses[item[2]], item[3])
        equal(#state.hand,5) -- final amount is not evidence of correct ordering
        local events=statuses(state); equal(#events,1)
        equal(#events[1].frame.hand,0)
    end)
end
for a=1,3 do for b=1,3 do if b~=a then
    local c=6-a-b
    test('top-insert reverses owned power relic order '..a..b..c, function()
        local state=battle({definitions[a][1],definitions[b][1],definitions[c][1]})
        local events=statuses(state); equal(#events,3)
        equal(events[1].detail.status,definitions[c][2])
        equal(events[2].detail.status,definitions[b][2])
        equal(events[3].detail.status,definitions[a][2])
    end)
end end end

for _, relics in ipairs({{'vajra','lantern'}, {'lantern','vajra'}}) do
    test('Lantern energy precedes opening power: '..table.concat(relics,','), function()
        local state=battle(relics); equal(state.energy,4)
        local events=statuses(state); equal(#events,1)
        -- Lantern's TOP gain precedes Vajra's TOP power, and base energy is
        -- still queued behind both. Expected one, not final energy four.
        equal(events[1].frame.energy,1)
    end)
end

test('control: bottom-insert Anchor then Bag follows ordinary draw', function()
    local state=battle({'anchor','bag_of_preparation'})
    equal(state.player.block,10); equal(#state.hand,7)
    local block
    for _,e in ipairs(state.events) do if e.kind=='block' then block=e end end
    assert(block); equal(#block.frame.hand,5)
end)
test('control: bottom-insert Bag then Anchor preserves acquisition order', function()
    local state=battle({'bag_of_preparation','anchor'})
    equal(state.player.block,10); equal(#state.hand,7)
    local block
    for _,e in ipairs(state.events) do if e.kind=='block' then block=e end end
    assert(block); equal(#block.frame.hand,7)
end)
test('control: no relic retains ordinary first hand and energy',function()
    local state=battle({});equal(#state.hand,5);equal(state.energy,3);equal(#statuses(state),0)
end)
print('OPENING_RELIC_ORDER '..passed..' passed / '..failed..' failed')
if failed>0 then error('opening relic queue parity not established: '..failed..' mismatches') end
