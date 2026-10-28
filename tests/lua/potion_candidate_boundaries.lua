package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Combat,Data=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local Hooks,Inventory,Actions=require('abyss_relic_hooks'),require('abyss_inventory'),require('abyss_card_actions')
local function same(a,b)
    assert(type(a)==type(b),'state type changed')
    if type(a)~='table'then assert(a==b,'state value changed');return end
    for key,value in pairs(a)do same(value,b[key])end
    for key in pairs(b)do assert(a[key]~=nil,'state key added')end
end
local base=Run.new(Data,42)
assert(Run.obtainPotion(base,'block_potion'))
assert(Run.startCombat(base,'cultist_solo'))
local cases={
    {function(r)r.nodeFlow={event={id='WeMeetAgain'}}end,0,'potion_event_restricted'},
    {function(r)r.combat.phase='enemy'end,0,'not_player_turn'},
    {function(r)r.combat.pendingChoice={};r.combat.pendingDiscard={}end,0,'card_choice_pending'},
    {function(r)r.combat.cardActions={}end,0,'card_choice_pending'},
    {function(r)r.combat.pendingPotionChoice={}end,0,'card_choice_pending'},
    {function(r)r.combat.pendingDiscard={};r.combat.pendingPlay={}end,0,'unsupported_potion_during_discard'},
    {function(r)r.combat.pendingScry={}end,0,'unsupported_potion_during_selection'},
    {function(r)r.combat.pendingPlay={}end,0,'unsupported_potion_during_selection'},
    {function()end,0,'invalid_potion_slot'},
    {function()end,2,'empty_potion_slot'},
    {function(r)r.potions[1]='missing'end,1,'unknown_potion'},
    {function(r)r.potions[1]='fairy_in_a_bottle'end,1,'automatic_potion'},
    {function(r)r.phase='map'end,0,'not_in_combat'},
    {function(r)r.phase='menu';r.potions[1]='blood_potion'end,1,'not_in_combat'},
}
for index,case in ipairs(cases)do
    -- Refusals stop before effect execution; keep their state small and explicit.
    local run={phase='combat',potions={'block_potion'},relics={},combat={phase='player'},
        data={rules={player={potionSlots=3}},potions={potions={{id='block_potion'},{id='fairy_in_a_bottle'},
            {id='blood_potion',effects={}}}}}}
    case[1](run)
    local before=Combat.copy(run)
    local ok,reason=Run.usePotion(run,case[2])
    assert(not ok and reason==case[3],index..': '..tostring(reason))
    same(before,run)
end
local run=Combat.copy(base)
run.hp,run.combat.player.hp=50,50
run.relics[#run.relics+1]='toy_ornithopter'
run.combat.relics[#run.combat.relics+1]='toy_ornithopter'
local trace={}
local apply,onUse,drain=Inventory.apply,Hooks.onUsePotion,Actions.drain
Inventory.apply=function(...)
    trace[#trace+1]='effect'
    return apply(...)
end
Hooks.onUsePotion=function(owner,candidate)
    trace[#trace+1]='hook'
    assert(candidate.potionInventory[1]=='block_potion')
    return onUse(owner,candidate)
end
Actions.drain=function(combat,candidate)
    trace[#trace+1]='drain'
    assert(candidate.potionInventory[1]==nil)
    return drain(combat,candidate)
end
local called,ok=pcall(Run.usePotion,run,1,nil,function(candidate)
    trace[#trace+1]='after'
    assert(candidate.potionInventory[1]==nil)
    assert(candidate.player.hp==50,'queued healing ran before caller actions')
    assert(candidate.player.block==12,'potion effect must precede hooks')
end)
Inventory.apply,Hooks.onUsePotion,Actions.drain=apply,onUse,drain
assert(called and ok)
assert(table.concat(trace,',')=='effect,hook,after,drain',table.concat(trace,','))
assert(run.hp==55 and run.potions[1]==nil)
local failed=Combat.copy(base)
local before=Combat.copy(failed)
local accepted,reason=Run.usePotion(failed,1,nil,function(candidate)
    assert(candidate.potionInventory[1]==nil)
    error('failed staged caller action')
end)
assert(not accepted and reason=='potion_effect_failed')
same(before,failed)
local Generation=require('abyss_potion_generation')
local outside=Run.new(Data,42)
assert(Run.obtainPotion(outside,'entropic_brew'))
before=Combat.copy(outside)
local prepare,available=Generation.prepare,Generation.available
Generation.prepare=function()error('prepare boundary')end
accepted,reason=Run.usePotion(outside,1)
Generation.prepare=prepare
assert(not accepted and reason=='potion_effect_failed')
same(before,outside)
Generation.available=function()error('available boundary')end
called,reason=pcall(Run.usePotion,outside,1)
Generation.available=available
assert(not called and tostring(reason):find('available boundary',1,true))
same(before,outside)
local effects=base.data.potions.potions
for _,potion in ipairs(effects)do if potion.id=='block_potion'then effects=potion.effects;break end end
local copy=Combat.copy
Combat.copy=function(value)
    if value==effects then error('effect copy boundary')end
    return copy(value)
end
called,reason=pcall(Run.usePotion,base,1)
Combat.copy=copy
assert(not called and tostring(reason):find('effect copy boundary',1,true))
print('POTION_CANDIDATE_BOUNDARIES_PASS '..#cases..' refusals; effect,hook,after,drain; callback rollback; prepare/available/copy exception boundaries')
