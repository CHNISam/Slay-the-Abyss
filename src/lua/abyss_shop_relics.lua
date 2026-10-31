-- Independently adapted from STS 319009d5 relics and UseCardAction.
-- The caller owns transactions and action ordering; this module never rerolls
-- an unavailable item or silently completes an unresolved reward screen.
local A=require('abyss_actor')
local E=require('abyss_events')
local R=require('abyss_sts_random')
local M={}
M.aliases={Sling='sling',HandDrill='hand_drill',Toolbox='toolbox',['Chemical X']='chemical_x',
 Orrery='orrery',DollysMirror='dollys_mirror',OrangePellets='orange_pellets',PrismaticShard='prismatic_shard',
 ClockworkSouvenir='clockwork_souvenir',['Frozen Eye']='frozen_eye',TheAbacus='the_abacus',
 ['Medical Kit']='medical_kit',Cauldron='cauldron',['Strange Spoon']='strange_spoon',Brimstone='brimstone'}
function M.localId(id)return M.aliases[id]or id end
function M.owns(owner,id)
 for _,held in ipairs(owner.relics or {})do if (M.aliases[held]or held)==id then return true end end
 return false
end
function M.onEquip(run,id,api)
 id=M.aliases[id]or id
 api=api and api.openRewards and api or require('abyss_relic_choices').adapter()
 if id=='prismatic_shard' then
  if run.character~='defect'and (run.masterMaxOrbs or 0)==0 then run.masterMaxOrbs=1 end
 elseif id=='dollys_mirror' then
  assert(not run.shopRelicChoice,'unresolved shop relic choice')
  local uids={};for _,card in ipairs(run.deck)do uids[#uids+1]=card.uid end
  run.shopRelicChoice={relic=id,kind='copy',uids=uids}
 elseif id=='orrery' or id=='cauldron' then
  assert(api and type(api.openRewards)=='function','shop relic requires reward-screen adapter')
  local rewards={}
  for i=1,5 do
   if id=='orrery' then
    assert(type(api.createCardReward)=='function','Orrery requires ordinary card reward adapter')
    rewards[i]={kind='card',reward=assert(api.createCardReward(run)),claimed=false}
   else
    local pool=require('abyss_potion_random')
    if not run.shopRng then
     local seed=run.eventSeed or string.format('%.0f',run.seed)
     run.shopRng={merchant=R.fromSeed(seed),potion=R.fromSeed(seed)}
    end
    assert(run.shopRng.potion,'Cauldron requires potionRng')
    local potion=pool.sample({potionRng=run.shopRng.potion},{character=pool.character(run)})
    rewards[i]={kind='potion',id=potion.id,claimed=false}
   end
  end
  api.openRewards(run,id,rewards)
 end
end
function M.chooseMirror(run,uid,api)
 local choice=run.shopRelicChoice
 if not choice or choice.kind~='copy'or choice.relic~='dollys_mirror'then return false,'no_shop_relic_choice'end
 local eligible=false;for _,id in ipairs(choice.uids)do if id==uid then eligible=true end end
 if not eligible then return false,'invalid_card_choice'end
 api=api or require('abyss_relic_choices').adapter()
 assert(type(api.obtainCardCopy)=='function','Dolly requires permanent card-copy adapter')
 local ok,why=api.obtainCardCopy(run,uid)
 if not ok then return false,why end
 run.shopRelicChoice=nil;return true,why
end
function M.battleStartActions(state,context)
 local actions={}
 if M.owns(state,'sling')and context and (context.eliteTrigger==true or context.tier=='elite'and context.eliteTrigger~=false)then
  actions[#actions+1]={op='gainStatus',status='strength',value=2,relic='sling',top=true}
 end
 if M.owns(state,'clockwork_souvenir')then
  actions[#actions+1]={op='gainStatus',status='artifact',value=1,relic='clockwork_souvenir',top=true}
 end
 return actions
end
function M.turnStartActions(state,singleId)
 state.shopRelicCombat=state.shopRelicCombat or {}
 state.shopRelicCombat.pellets={}
 local actions={}
 if (not singleId or M.localId(singleId)=='brimstone')and M.owns(state,'brimstone')then
  -- Source inserts enemies at TOP after player; reverse enemy iteration.
  for i=#state.enemies,1,-1 do local enemy=state.enemies[i]
   actions[#actions+1]={op='applyStatus',status='strength',value=1,targetId=enemy.id,relic='brimstone',top=true}
  end
  actions[#actions+1]={op='gainStatus',status='strength',value=2,relic='brimstone',top=true}
 end
 return actions
end
function M.onBlockBroken(state,target)
 if M.owns(state,'hand_drill')and target~=state.player then
  require('abyss_card_actions').enqueueReaction(state,
   {op='shopRelic',kind='handDrill',targetId=target.id},false)
 end
end
-- Deep Breath must place constructor reactions before its shuffle continuation.
-- Other shuffle callers retain the existing BOTTOM enqueue by default.
function M.onShuffle(state,effectsOnly)
 if M.owns(state,'the_abacus')then
  local effect={op='block',value=6,fixed=true,relic='the_abacus'}
  if effectsOnly then return effect end
  require('abyss_card_actions').enqueueReaction(state,effect,false)
 end
end
function M.xBonus(state)return M.owns(state,'chemical_x')and 2 or 0 end
function M.medicalCard(state,definition)
 if definition.type~='status'or not M.owns(state,'medical_kit')then return definition end
 local copy={};for k,v in pairs(definition)do copy[k]=v end
 -- Burn/Dazed/Wound/Slimed become usable; costed statuses keep their cost.
 if copy.cost==-2 then copy.cost=0 end
 copy.exhaust=true;return copy
end
function M.exhaustAfterUse(state,definition,exhaust,purge)
 if not exhaust or purge or definition.type=='power'or not M.owns(state,'strange_spoon')then return exhaust end
 assert(state.cardRandomRng,'Strange Spoon requires cardRandomRng')
 return not R.randomBoolean(state.cardRandomRng)
end
function M.onUseCard(state,definition)
 if not M.owns(state,'orange_pellets')then return end
 state.shopRelicCombat=state.shopRelicCombat or {}
 local c=state.shopRelicCombat.pellets or {};state.shopRelicCombat.pellets=c
 c[definition.type]=true
 if c.attack and c.skill and c.power then
  state.shopRelicCombat.pellets={}
  require('abyss_card_actions').enqueueReaction(state,{op='shopRelic',kind='pellets'},false)
 end
end
local function removeDebuff(state,target,id)
 local n=id=='no_draw'and target.noDraw and 1 or target.statuses[id];if n==nil then return end
 require('abyss_power_schedule').remove(state,target,id)
 if id=='no_draw'then target.noDraw=false end
 target.statuses[id]=nil;target[id..'JustApplied']=nil
 local order={};for _,old in ipairs(target.powerOrder or {})do if old~=id then order[#order+1]=old end end
 target.powerOrder=order
 E.emit(state,'status',{source=target.id,target=target.id,status=id,amount=-n})
end
function M.execute(state,effect)
 if effect.kind=='handDrill'then
  for _,target in ipairs(state.enemies)do if target.id==effect.targetId and A.isActive(target)then
   A.applyPower(state,target,'vulnerable',2,state.player,false);break
  end end
 elseif effect.kind=='pellets'then
  local target=state.player;local powers,order={},{}
  if not A.isActive(target)then return end
  for i,id in ipairs(target.powerOrder or {})do order[id]=i end
  for id,n in pairs(target.statuses)do local d=target.statusDefinitions[id]
   if d and (d.kind=='debuff'or (id=='strength'or id=='dexterity'or id=='focus')and n<=0)then
    powers[#powers+1]={id=id,priority=d.priority or 5,order=order[id]or math.huge}
   end
  end
  if target.noDraw then powers[#powers+1]={id='no_draw',priority=5,order=order.no_draw or math.huge}end
  table.sort(powers,function(a,b)
   if a.priority~=b.priority then return a.priority<b.priority end
   if a.order~=b.order then return a.order<b.order end
   return a.id<b.id
  end)
  for i=#powers,1,-1 do removeDebuff(state,target,powers[i].id)end
 else error('unknown shop relic effect '..tostring(effect.kind))end
end
function M.beginToolbox(combat,state)
 assert(M.owns(state,'toolbox'),'Toolbox ownership required')
 assert(not state.pendingChoice,'card choice already pending')
 local pool=require('abyss_potion_discovery').pool(state,'colorless')
 local cards,used={},{}
 while #cards<3 do local id=pool[combat.cardRandom(state,#pool)]
  if not used[id]then used[id]=true;cards[#cards+1]={uid=#cards+1,cardId=id,upgraded=false}end
 end
 state.choiceSerial=(state.choiceSerial or 0)+1
 state.pendingChoice={op='toolbox',token=state.choiceSerial,uids={1,2,3},cards=cards,turn=state.turn}
 E.emit(state,'card_choice',{op='toolbox',token=state.choiceSerial})
end
function M.chooseToolbox(combat,state,token,index,actions)
 local p=state.pendingChoice
 if not p or p.op~='toolbox'or p.token~=token or p.turn~=state.turn then return false,'stale_card_choice'end
 if type(index)~='number'or index%1~=0 or not p.cards[index]then return false,'invalid_card_choice'end
 local card=actions.fresh(combat,state,p.cards[index].cardId)
 if (state.player.statuses.master_reality or 0)>0 and combat.canUpgrade(state,card)then combat.upgrade(state,card)end
 actions.toHand(state,card);state.pendingChoice=nil
 E.emit(state,'card_choice_resolved',{op='toolbox',cardId=card.cardId});return true
end
function M.drawOrderVisible(state)return M.owns(state,'frozen_eye')end
return M
