-- Regression promoted from the independent diagnostic after reproducing its red result.
-- Fixed source chain and scope: docs/rules/OPENING_RELIC_ORDER.md.
-- Real Run commands and existing frames; no replacement dispatcher or injected hooks.
package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local Run, Combat = require('abyss_run'), require('abyss_combat')
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

for _, relics in ipairs({
    {'anchor','vajra','bag_of_preparation','lantern','oddly_smooth_stone','bronze_scales'},
    {'bronze_scales','bag_of_preparation','oddly_smooth_stone','anchor','lantern','vajra'}
}) do
    test('mixed opening preserves all source phases: '..table.concat(relics,','), function()
        local state=battle(relics)
        local events=statuses(state); equal(#events,3)
        for _, e in ipairs(events) do
            equal(#e.frame.hand,0); equal(e.frame.energy,1)
            equal(e.frame.player.block,0)
        end
        local block
        for _, e in ipairs(state.events) do if e.kind=='block' then block=e end end
        assert(block); equal(block.frame.energy,4)
        equal(block.frame.player.statuses.strength,1)
        equal(block.frame.player.statuses.dexterity,1)
        equal(block.frame.player.statuses.thorns,3)
        equal(#block.frame.hand,relics[1]=='anchor' and 5 or 7)
        equal(#state.hand,7); equal(state.energy,4); equal(state.player.block,10)
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

local function same(a,b)
    equal(type(a),type(b))
    if type(a)~='table' then equal(a,b); return end
    for k,v in pairs(a) do same(v,b[k]) end
    for k in pairs(b) do assert(a[k]~=nil,'unexpected key '..tostring(k)) end
end
local function rejected(run,reason)
    local before=Combat.copy(run)
    local ok,actual=Run.startCombat(run,'cultist_solo')
    equal(ok,false); equal(actual,reason); same(run,before)
end

test('opening refusal never commits partial battle or advances run RNG',function()
    local run=Run.new(data,42)
    run.relics={'lantern','unknown'}; rejected(run,'unknown_relic')
    run.data.relics.relics[#run.data.relics.relics+1]={id='unverified',trigger='combat_start',effects={{op='block',value=1}}}
    run.relics={'lantern','unverified'}; rejected(run,'unsupported_opening_relic:unverified')
    run.relics={'lantern','vajra'}
    for _,r in ipairs(run.data.relics.relics) do if r.id=='vajra' then r.effects={{op='fake',value=1}} end end
    rejected(run,'unsupported_effect:fake')
    run.relics={'lantern','anchor'}
    for _,r in ipairs(run.data.relics.relics) do if r.id=='anchor' then r.effects={{op='fake',value=1}} end end
    rejected(run,'unsupported_effect:fake')
end)

test('base energy after Lantern preserves existing overflow refusal',function()
    local run=Run.new(data,42); run.relics={'lantern'}
    for _,r in ipairs(run.data.relics.relics) do if r.id=='lantern' then r.effects[1].value=2147483647 end end
    rejected(run,'effect_overflow')
end)

local function dataOnly(value)
    assert(type(value)~='function','opening callback escaped into persistent state')
    if type(value)=='table' then for k,v in pairs(value) do dataOnly(k); dataOnly(v) end end
end
test('opening callbacks stay out of state and do not repeat on the next player turn',function()
    local state=battle({'lantern','vajra','anchor','bag_of_preparation'})
    dataOnly(state)
    assert(Combat.endTurn(state)); equal(state.turn,2); equal(state.energy,3)
    equal(#state.hand,5); equal(state.player.block,0); equal(state.player.statuses.strength,1)
    equal(#statuses(state),1); dataOnly(state)
end)

test('a second real battle gets a fresh opening queue exactly once',function()
    local run=Run.new(data,42)
    run.relics={'burning_blood','lantern','vajra','anchor','bag_of_preparation'}
    assert(Run.startCombat(run,'cultist_solo'))
    for _=1,200 do
        if run.phase~='combat' then break end
        local chosen
        for _,card in ipairs(run.combat.hand) do
            if Combat.canPlay(run.combat,card.uid,1) then
                chosen=card
                if Combat.cardDefinition(run.combat,card).type=='attack' then break end
            end
        end
        if chosen then assert(Run.play(run,chosen.uid,1)) else assert(Run.endTurn(run)) end
    end
    equal(run.phase,'reward'); assert(Run.claimCardReward(run,0)); dofile('tests/lua/support/finish_combat_rewards.lua')(run)
    assert(Run.startCombat(run,'cultist_solo'))
    local state=run.combat; local events=statuses(state)
    equal(#events,1); equal(events[1].frame.energy,1); equal(#events[1].frame.hand,0)
    equal(#state.hand,7); equal(state.energy,4); equal(state.player.block,10)
    equal(state.player.statuses.strength,1); dataOnly(state)
end)
print('OPENING_RELIC_ORDER '..passed..' passed / '..failed..' failed')
if failed>0 then error('opening relic queue parity not established: '..failed..' mismatches') end
