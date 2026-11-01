-- Actual combat entry and turn commands verify supported Boss relic mechanics;
-- the post-combat heal case isolates the terminal-state boundary explicitly.
package.path = 'src/lua/?.lua;build/lua/?.lua;' .. package.path
local Run,Combat,data=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local count=0
local function equal(a,b) if a~=b then error(tostring(a)..' ~= '..tostring(b),2) end end
local function test(name,fn) fn();count=count+1;print('ok boss relic '..count..' - '..name) end
local function battle(relics,tier)
    local run=Run.new(data,42);run.relics=relics
    if tier=='boss' then run.floor=16 elseif tier=='elite' then run.floor=6 end
    assert(Run.startCombat(run,tier=='boss' and 'boss_guardian' or tier=='elite' and 'elite_nob' or 'cultist_solo'))
    return run
end
test('Sozu raises prepared energy on both opening and subsequent turns',function()
    local run=battle({'burning_blood','sozu'})
    equal(run.combat.energy,4);assert(Run.endTurn(run));equal(run.combat.energy,4)
    equal(run.data.rules.player.energyPerTurn,3);equal(data.rules.player.energyPerTurn,3)
end)
test('Slaver collar applies in elite and Boss fights but not ordinary combat',function()
    for _,tier in ipairs({'normal','elite','boss'}) do
        local run=battle({'burning_blood','slavers_collar'},tier)
        equal(run.combat.energy,tier=='normal' and 3 or 4)
        assert(Run.endTurn(run));equal(run.combat.energy,tier=='normal' and 3 or 4)
        equal(run.data.rules.player.energyPerTurn,3)
    end
end)
test('conditional collar stacks with Sozu and Lantern only on the opening turn',function()
    local run=battle({'burning_blood','slavers_collar','sozu','lantern'},'elite')
    equal(run.combat.energy,6);assert(Run.endTurn(run));equal(run.combat.energy,5)
end)
test('an elite victory does not leave Collar energy in the following ordinary fight',function()
    local run=battle({'burning_blood','slavers_collar'},'elite')
    equal(run.combat.energy,4)
    for _,enemy in ipairs(run.combat.enemies) do enemy.hp=0 end
    assert(Run.finishCombat(run));assert(Run.claimCardReward(run,0)); dofile('tests/lua/support/finish_combat_rewards.lua')(run);run.floor=1
    assert(Run.startCombat(run,'cultist_solo'));equal(run.combat.energy,3)
    assert(Run.endTurn(run));equal(run.combat.energy,3)
end)
test('Sozu blocks new bottles in a vacant slot while owned bottles remain usable',function()
    local run=Run.new(data,42);assert(Run.obtainPotion(run,'fire_potion'));run.relics={'burning_blood','sozu'}
    for _,phase in ipairs({'map','node','reward','combat'}) do
        run.phase=phase;local ok,reason=Run.obtainPotion(run,'energy_potion')
        equal(ok,false);equal(reason,'potion_blocked_by_sozu');equal(run.potions[2],nil)
    end
    run.phase='map';assert(Run.startCombat(run,'cultist_solo'))
    local hp=run.combat.enemies[1].hp
    assert(Run.usePotion(run,1,1));equal(run.combat.enemies[1].hp,hp-20);equal(run.potions[1],nil)
    equal(Run.obtainPotion(run,'energy_potion'),false)
end)
test('Black Blood heals 12 once on victory, caps at max HP and never heals defeat',function()
    for _,hp in ipairs({20,75}) do
        local run=battle({'black_blood'});run.combat.player.hp=hp
        for _,enemy in ipairs(run.combat.enemies) do enemy.hp=0 end
        assert(Run.finishCombat(run));equal(run.hp,math.min(80,hp+12))
        equal(Run.finishCombat(run),false);equal(run.hp,math.min(80,hp+12))
    end
    local run=battle({'black_blood'});run.combat.player.hp=0
    assert(Run.finishCombat(run));equal(run.phase,'defeat');equal(run.hp,0)
end)
print('LUA_BOSS_RELIC_EFFECTS_PASS '..count)
