local Data=require('abyss_data')
local Combat=require('abyss_combat')
local View=require('abyss_battle_intent_view')
local Particles=require('abyss_monster_intent_particle_view')
local s=Combat.new(Data,{deck={'defend'},enemies={'fat_gremlin'}})
s.player.statuses.weak=2147483647
local before=Combat.copy(s)
local selected=View.selectedDescriptor(s,1,false)
assert(selected.baseDamage==4 and selected.intent=='ATTACK_DEBUFF' and selected.face==nil)
local ok,why=pcall(View.selectedDescriptor,s,1,true)
assert(not ok and tostring(why):find('status stack overflow',1,true),'full tooltip keeps its real overflow guard')
assert(s.player.statuses.weak==before.player.statuses.weak and #s.events==#before.events)
local parasite=Combat.new(Data,{deck={'defend'},enemies={'shelled_parasite'}})
local enemy=parasite.enemies[1]
for index,move in ipairs(enemy.intents)do if move.id=='life_suck'then enemy.intentIndex=index end end
local vampire=View.selectedDescriptor(parasite,1,false)
assert(vampire.intent=='ATTACK_BUFF' and vampire.baseDamage>0,'vampire attack participates in source applyPowers')
local view=Particles.new({},function()error('no native writes')end,function()error('no native writes')end)
view:sync({{id=enemy.id,actor=enemy}},parasite,nil,true)
local state=view.states[enemy.id]
state.createPending=nil;state.intentAlpha=.4;state.timer=.31
state.effects={{id='retained-effect'}}
local effects=state.effects
view:reconcileDisplayed();view:reconcileDisplayed()
assert(state.createPending and state.intentAlpha==.4 and state.timer==.31 and state.effects==effects)
view:onEngineDestroy();view:reconcileDisplayed()
assert(next(view.states)==nil and next(view.outputs)==nil,'late recovery cannot resurrect destroyed engine controls')
print('MONSTER_INTENT_REFRESH_BOUNDARIES PASS')
