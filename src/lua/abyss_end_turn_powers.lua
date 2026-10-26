-- One ordinary player atEndOfTurn hook-construction pass. Combat owns the
-- existing queue, continuation and whole-command rollback.
local Schedule=require('abyss_power_schedule')
local Events=require('abyss_events')
local M={}
local ids={combust=true,rage=true,study=true,omega=true,establishment=true,regen=true,ritual=true,
 wraith_form=true,lose_strength=true,lose_dexterity=true,no_draw=true,entangled=true,double_tap=true,
 burst=true,shackled=true,rebound=true,amplify=true,equilibrium=true,well_laid_plans=true}
local preCards={metallicize=true,plated_armor=true,like_water=true}
M.ops={ownerEndRegen=true,ownerEndClearLoss=true,ownerEndClearNoDraw=true,ownerEndBombReduce=true,
 ownerEndDamageAll=true,ownerEndThorns=true,ownerEndRemoveDefect=true,
 ownerPreCardBlock=true,ownerEndOrbTrigger=true,ownerEndOrbEffect=true,ownerEndNative=true}
local function add(out,effect)
 out[#out+1]=effect.kind=='effect'and effect or {kind='effect',effect=effect}
end
function M.needed(state,extension)
 local p=state.player
 if p.noDraw or (p.temporaryStrength or 0)>0 or (p.temporaryDexterity or 0)>0 or state.orbs and #state.orbs.balls>0 then return true end
 for id in pairs(p.statuses)do if ids[id]or preCards[id]or extension and extension.ownerEndIds and extension.ownerEndIds[id]then return true end end
 for _,b in ipairs(state.colorlessBombs or {})do if b.turns>0 then return true end end
 return false
end
function M.preparePreCards(state)
 local out={}
 for _,entry in ipairs(Schedule.ownerEnd(state,preCards))do
  if entry.id~='like_water'or state.player.stance=='Calm'then add(out,{op='ownerPreCardBlock',value=entry.amount})end
 end
 if state.orbs then add(out,{op='ownerEndOrbTrigger'})end
 return out
end
-- These existing native callbacks are all source addToBottom DAMAGE actions.
-- Keep the actual owner/target graph; do not reinterpret arbitrary native ops.
local function nativeDamage(state,item)
 local e=item.effect
 return item.source==state.player and not item.instance and
  (e.op=='damageRandom'and e.fixed==true and not item.target
  or e.op=='silentFinal'and e.kind=='corpseDamage'and not item.target
  or e.op=='colorless'and e.kind=='sadisticDamage'and item.target~=nil)
end
function M.transferNative(state,queue)
 local actions=state.cardActions;state.cardActions=nil
 for _,item in ipairs(actions or {})do
  assert(nativeDamage(state,item),'unsupported owner-end native callback')
  queue.pushBottom(state,{kind='effect',effect={op='ownerEndNative',item=item}})
 end
end
function M.prepareExhaust(state)
 local hooks={dark_embrace=true,feel_no_pain=true};local filter,order={},{}
 for id in pairs(hooks)do if (state.player.statuses[id]or 0)>0 then filter[id]=true end end
 for _,entry in ipairs(Schedule.ownerEnd(state,filter))do order[#order+1]=entry.id end
 local prior=state.exhaustPowerOrder
 if prior then
  assert(type(prior)=='table'and getmetatable(prior)==nil,'invalid exhaust acquisition history')
  local count,seen=0,{}
  for k in pairs(prior)do assert(type(k)=='number'and k%1==0 and k>0,'invalid exhaust acquisition index');count=count+1 end
  for i=1,count do local id=prior[i];assert(hooks[id]and not seen[id],'invalid exhaust acquisition entry');seen[id]=true end
  local active={};for _,id in ipairs(prior)do if (state.player.statuses[id]or 0)>0 then active[#active+1]=id end end
  assert(#active==#order,'inconsistent exhaust acquisition history')
  for i,id in ipairs(active)do assert(id==order[i],'inconsistent exhaust acquisition history')end
 end
 state.exhaustPowerOrder=order
end
function M.prepare(state,combat,extension)
 local filter={};for id in pairs(ids)do filter[id]=true end
 for id in pairs(extension and extension.ownerEndIds or {})do filter[id]=true end
 local bombs={};for _,b in ipairs(state.colorlessBombs or {})do if b.turns>0 then filter[b.id]=true;bombs[b.id]=b end end
 local p=state.player;local virtual={}
 for stat,field in pairs({strength='temporaryStrength',dexterity='temporaryDexterity'})do
  if (p[field]or 0)>0 then virtual['lose_'..stat]={amount=p[field],priority=5}end
 end
 if p.noDraw then virtual.no_draw={amount=1,priority=5}end
 local top,bottom={},{}
 for _,entry in ipairs(Schedule.ownerEnd(state,filter,virtual))do
  local id,n=entry.id,entry.amount;local plan
  if id=='regen'then if n>0 then table.insert(top,1,{kind='effect',effect={op='ownerEndRegen',value=n}})end
  elseif id=='combust'then plan=require('abyss_warrior_strength_cards').planHook(state,id,'turn_end')
  elseif id=='rage'then if n>0 then
   local registered=false;for _,record in ipairs(state.cardTriggerPowerOrder or {})do if record.id==id then registered=true end end
   if registered then plan={bottom=require('abyss_card_triggers').prepareEndTurn(state)}else add(bottom,{op='removeStatus',status=id,value=0})end
  end
  elseif id=='study'then plan=require('abyss_watcher_flow_cards').planHook(state,id,'turn_end')
  elseif id=='omega'then add(bottom,{op='ownerEndDamageAll',value=n})
  elseif id=='establishment'then add(bottom,{op='watcherFinalEstablishment',value=n})
  elseif id=='lose_strength'or id=='lose_dexterity'then
   local stat=id=='lose_strength'and 'strength'or 'dexterity'
   add(bottom,{op='gainStatus',status=stat,value=-n});add(bottom,{op='ownerEndClearLoss',stat=stat})
  elseif id=='ritual'then if n>0 then add(bottom,{op='gainStatus',status='strength',value=n})end
  elseif id=='wraith_form'then if n<0 then add(bottom,{op='gainStatus',status='dexterity',value=n})end
  elseif id=='shackled'then
   add(bottom,{op='gainStatus',status='strength',value=n});add(bottom,{op='removeStatus',status=id,value=0})
  elseif id=='no_draw'then add(bottom,{op='ownerEndClearNoDraw'})
  elseif id=='equilibrium'then
   for _,c in ipairs(state.hand)do if not combat.cardDefinition(state,c).ethereal then c.retain=true end end
  elseif id=='well_laid_plans'then if n>0 then add(bottom,{op='ownerEndRetain'})end
  elseif id=='rebound'or id=='amplify'then add(bottom,{op='ownerEndRemoveDefect',status=id})
  elseif bombs[id]then
   local bomb=bombs[id];assert(n==bomb.turns,'inconsistent Bomb Power')
   add(bottom,{op='ownerEndBombReduce',bomb=bomb});if n==1 then add(bottom,{op='ownerEndDamageAll',value=bomb.damage})end
  elseif extension and extension.ownerEndIds and extension.ownerEndIds[id]then
   plan=extension.ownerEndPlan(state,id,n)
  else add(bottom,{op='removeStatus',status=id,value=0})end
  if plan then
   for _,effect in ipairs(plan.top or {})do table.insert(top,1,effect.kind=='effect'and effect or {kind='effect',effect=effect})end
   for _,effect in ipairs(plan.bottom or {})do add(bottom,effect)end
  end
 end
 for _,action in ipairs(bottom)do top[#top+1]=action end
 return top
end
function M.retained(effect)
 return effect.op=='ownerEndDamageAll'or effect.op=='ownerEndThorns'or effect.op=='ownerEndRegen'
  or effect.op=='ownerEndNative'or effect.op=='ownerEndOrbEffect'and effect.action.kind=='frost'
end
function M.apply(combat,state,effect,queue)
 local p=state.player
 if effect.op=='ownerPreCardBlock'then combat.block(state,p,effect.value,true)
 elseif effect.op=='ownerEndOrbTrigger'then
  local orbs=require('abyss_orbs')
  for i=1,#state.orbs.balls do
   local action=orbs.preparePassive(state,i,'end')
   if action then queue.pushBottom(state,{kind='effect',effect={op='ownerEndOrbEffect',action=action}})end
  end
  Events.emit(state,'orb_end_turn')
 elseif effect.op=='ownerEndOrbEffect'then require('abyss_orbs').resolve(state,effect.action,combat)
 elseif effect.op=='ownerEndNative'then
  assert(nativeDamage(state,effect.item),'unsupported owner-end native callback')
  require('abyss_card_actions').apply(combat,state,effect.item)
 elseif effect.op=='ownerEndRegen'then
  require('abyss_card_actions').apply(combat,state,{effect={op='heal',value=effect.value},source=p})
  p.statuses.regen=math.max(0,(p.statuses.regen or 0)-1)
  if p.statuses.regen==0 then Schedule.remove(state,p,'regen')end
 elseif effect.op=='ownerEndClearLoss'then
  local stat=effect.stat;local field=stat=='strength'and 'temporaryStrength'or stat=='dexterity'and 'temporaryDexterity'
  assert(field,'invalid temporary stat removal');p[field]=0
  local keep={};for _,id in ipairs(p.temporaryPowerOrder or {})do if id~=stat then keep[#keep+1]=id end end
  p.temporaryPowerOrder=#keep>0 and keep or nil
  keep={};for _,id in ipairs(p.powerOrder or {})do if id~='lose_'..stat then keep[#keep+1]=id end end;p.powerOrder=keep
 elseif effect.op=='ownerEndClearNoDraw'then
  p.noDraw=false;Events.emit(state,'no_draw_removed',{target=p.id})
 elseif effect.op=='ownerEndBombReduce'then
  local b=effect.bomb;b.turns=b.turns-1;p.statuses[b.id]=b.turns>0 and b.turns or nil
  if b.turns==0 then Schedule.remove(state,p,b.id)end
 elseif effect.op=='ownerEndDamageAll'then
  for _,enemy in ipairs(state.enemies)do if enemy.hp>0 and not enemy.escaped then combat.retaliate(state,nil,enemy,effect.value)end end
 elseif effect.op=='ownerEndThorns'then
  assert(type(effect.source)=='table'and effect.source~=p,'missing captured damage source')
  combat.retaliate(state,effect.source,p,effect.value)
 elseif effect.op=='ownerEndRemoveDefect'then require('abyss_defect_final_cards').removePower(state,effect.status)
 else error('unknown owner-end action')end
 return true
end
return M
