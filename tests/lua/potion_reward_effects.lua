-- Acquisition/effect bridge: original starter deck defeats the unchanged
-- Cultist; supported reward bottles are claimed, carried and used next battle.
-- Seed/ID rows come from the independent full-source potion oracle.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Combat,data=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local count=0
local function equal(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function win(run)
    for _=1,160 do
        if run.phase~='combat' then break end
        local uid
        for _,card in ipairs(run.combat.hand) do
            if Combat.canPlay(run.combat,card.uid,1) then
                uid=card.uid
                if Combat.cardDefinition(run.combat,card).type=='attack' then break end
            end
        end
        if uid then assert(Run.play(run,uid,1)) else assert(Run.endTurn(run)) end
    end
    equal(run.phase,'reward')
end
local rows={
    {159,'energy_potion'}, {61,'fire_potion'}, {23,'block_potion'},
    {2,'dexterity_potion'}, {84,'regen_potion'}, {18,'strength_potion'}
}
for _,row in ipairs(rows) do
    local run=Run.new(data,row[1]);assert(Run.startCombat(run,'cultist_solo'));win(run)
    equal(run.rewards.potion.id,row[2]);assert(Run.claimPotionReward(run));equal(run.potions[1],row[2])
    assert(Run.claimCardReward(run,0)); dofile('tests/lua/support/finish_combat_rewards.lua')(run);equal(run.phase,'map');equal(run.potions[1],row[2])
    -- No route navigation is claimed here: this isolates the retained-bottle
    -- bridge between two legal combat entries, using production combat data.
    assert(Run.startCombat(run,'cultist_solo'))
    local state=run.combat;local hp,energy=state.enemies[1].hp,state.energy
    assert(Run.usePotion(run,1,row[2]=='fire_potion' and 1 or nil));state=run.combat
    equal(run.potions[1],nil);equal(Run.potionCount(run),0)
    if row[2]=='fire_potion' then equal(state.enemies[1].hp,hp-20)
    elseif row[2]=='block_potion' then equal(state.player.block,12)
    elseif row[2]=='energy_potion' then equal(state.energy,energy+2)
    elseif row[2]=='strength_potion' then equal(state.player.statuses.strength,2)
    elseif row[2]=='dexterity_potion' then equal(state.player.statuses.dexterity,2)
    else equal(state.player.statuses.regen,5) end
    local ok,why=Run.usePotion(run,1,1);equal(ok,false);equal(why,'empty_potion_slot')
    count=count+1;print('ok reward effect '..count..' - '..row[2])
end
print('LUA_POTION_REWARD_EFFECTS_PASS '..count)
