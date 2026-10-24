-- Source: AbstractPotion.canDiscard / PotionPopUp.updateInput at the fixed
-- community mirror identified in TASK-14.1-m3-inventory-audit.md.
package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local Run, Combat, data = require('abyss_run'), require('abyss_combat'), require('abyss_data')
local count, failures = 0, {}
local function equal(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function same(a,b)
    equal(type(a),type(b));if type(a)~='table' then equal(a,b);return end
    for k,v in pairs(a) do same(v,b[k]) end
    for k in pairs(b) do assert(a[k]~=nil,'unexpected key '..tostring(k)) end
end
local function test(name,fn)
    local ok,why=pcall(fn)
    if ok then count=count+1;print('ok potion discard '..count..' - '..name)
    else failures[#failures+1]=name..': '..tostring(why);print('not ok - '..failures[#failures]) end
end
local function belt()
    local run=Run.new(data,42)
    for _,id in ipairs({'fire_potion','block_potion','regen_potion'}) do assert(Run.obtainPotion(run,id)) end
    return run
end
local function refused(run,slot,reason)
    local before=Combat.copy(run)
    local ok,why=Run.discardPotion(run,slot)
    equal(ok,false);equal(why,reason);same(run,before)
end

test('discarding the middle bottle preserves physical slots and only changes that slot',function()
    local run=belt();local before=Combat.copy(run)
    assert(Run.discardPotion(run,2));before.potions[2]=nil;same(run,before)
    equal(Run.potionCount(run),2)
    refused(run,2,'empty_potion_slot')
    local ok,slot=Run.obtainPotion(run,'energy_potion');assert(ok);equal(slot,2)
    same(run.potions,{'fire_potion','energy_potion','regen_potion'})
end)

test('discard is independent of combat use legality and does not execute an effect',function()
    for _,phase in ipairs({'map','node','reward','combat'}) do
        local run=belt()
        if phase=='combat' then assert(Run.startCombat(run,'cultist_solo'));run.combat.phase='enemy' end
        run.phase=phase
        local before=Combat.copy(run)
        assert(Run.discardPotion(run,1));before.potions[1]=nil;same(run,before)
        equal(run.potions[3],'regen_potion')
    end
end)

test('invalid empty and unknown slots reject without changing inventory or random state',function()
    local run=belt()
    for _,slot in ipairs({0,-1,0.5,4,'1',false,{},math.huge,0/0}) do refused(run,slot,'invalid_potion_slot') end
    refused(run,nil,'invalid_potion_slot')
    run.potions[2]=nil;refused(run,2,'empty_potion_slot')
    run.potions[2]='unknown';refused(run,2,'unknown_potion')
end)

test('full reward belt can discard an old bottle then claim into the same vacancy once',function()
    local run=belt();assert(Run.startCombat(run,'cultist_solo'))
    -- Completed-battle fixture isolates the reward/discard transaction; it is
    -- not evidence of a normal-data victory or a full-run playthrough.
    for _,enemy in ipairs(run.combat.enemies) do enemy.hp=0 end
    assert(Run.finishCombat(run));equal(run.rewards.potion.id,'dexterity_potion')
    local before=Combat.copy(run)
    equal(Run.claimPotionReward(run),false);same(run,before)
    assert(Run.discardPotion(run,2));local ok,slot=Run.claimPotionReward(run)
    assert(ok);equal(slot,2);same(run.potions,{'fire_potion','dexterity_potion','regen_potion'})
    equal(Run.claimPotionReward(run),false)
    assert(Run.claimCardReward(run,0)); dofile('tests/lua/support/finish_combat_rewards.lua')(run);equal(run.phase,'map')
end)

if #failures>0 then error(table.concat(failures,'\n')) end
print('LUA_POTION_DISCARD_PASS '..count)
