-- Offline evidence only. Unmodified production rules and public commands.
-- No navigation, inventory, HP, enemy, reward, pool or RNG writes.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Nodes,Map=require('abyss_run'),require('abyss_nodes'),require('abyss_map')
local C,R,Q=require('abyss_combat'),require('abyss_sts_random'),require('abyss_encounter_queue')
local Data=require('abyss_data')
local Policy=dofile('scripts/warrior75-autoplay-policy.lua')
local EventCards=dofile('scripts/m3-event-card-policy.lua')
local RelicChoices=dofile('scripts/m3-relic-choice-policy.lua')
local Pending=require('abyss_relic_pending')
local function json(value)
    if type(value)=='nil' then return 'null' end
    if type(value)=='boolean' or type(value)=='number' then return tostring(value) end
    if type(value)=='string' then return '"'..value:gsub('[%z\1-\31\\"]',function(c)
        return c=='"' and '\\"' or c=='\\' and '\\\\' or string.format('\\u%04x',string.byte(c)) end)..'"' end
    local keys,n,array={},0,true
    for k in pairs(value) do keys[#keys+1]=k;n=n+1;if type(k)~='number' then array=false end end
    local result={}
    if array and #value==n then for _,v in ipairs(value) do result[#result+1]=json(v) end
        return '['..table.concat(result,',')..']' end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    for _,k in ipairs(keys) do result[#result+1]=json(tostring(k))..':'..json(value[k]) end
    return '{'..table.concat(result,',')..'}'
end

local function snap(run,map)
 local deck={}
 for _,c in ipairs(run.deck)do deck[#deck+1]={uid=c.uid,cardId=c.cardId,upgraded=c.upgraded==true}end
 return {act=run.act,floor=run.floor,mapFloor=map.floor,phase=run.phase,hp=run.hp,maxHp=run.maxHp,gold=run.gold,
 deck=deck,relics=C.copy(run.relics),potions=C.copy(run.potions),nextDeckUid=run.nextDeckUid,
 rng={card=R.snapshot(run.cardRng),event=R.snapshot(run.eventRng),misc=R.snapshot(run.miscRng),
 treasure=R.snapshot(run.treasureRng),encounters=Q.snapshot(run.encounters),
 combat=run.combat and {ai=run.combat.aiRng and R.snapshot(run.combat.aiRng),
 shuffle=run.combat.shuffleRng and R.snapshot(run.combat.shuffleRng),
 cardRandom=run.combat.cardRandomRng and R.snapshot(run.combat.cardRandomRng),
 hp=run.combat.monsterHpRng and R.snapshot(run.combat.monsterHpRng)}or nil},path=C.copy(map.path),ending=run.ending}
end
local function new(seed)
 local run=Run.new(Data,tostring(seed),{experimental=true,campaign=true,campaignProfile='competition-two-act',character='ironclad'})
 local map=Map.generate(run.data,run.runSeed,1,assert(Run.freezeMapContext(run)))
 return run,map
end
local function play(seed)
 local run,map=new(seed)
 local report={seed=seed,policy='warrior75-visible-state-v1',actions={},rooms={},initial=snap(run,map),platformVerified=false}
 local coverage,done={},{}
 local function command(label,fn,details)
  local before=snap(run,map)
  local ok,reason=fn()
  if label=='enter'then print('M3_PROGRESS '..seed..' floor='..run.floor..' hp='..run.hp)end
  report.actions[#report.actions+1]={label=label,details=details,ok=ok,reason=reason,before=before,after=snap(run,map)}
  assert(ok,label..': '..tostring(reason))
 end
 local function execute()
 command('begin_neow',function()return Nodes.beginNeow(run,map,{bossCount=0,source='fresh-start'})end)
 local actions=0
 while (run.phase~='defeat' and run.phase~='victory' or Pending.owner(run)) and actions<3000 do
  actions=actions+1
  local pendingToken,pendingDetails=RelicChoices.choose(run,Policy.scoreCard)
  if pendingToken then command('mandatory_relic_choice',function()return Pending.resolve(run,pendingToken)end,pendingDetails)
  elseif run.phase=='act_transition'then command('advance_act',function()return Nodes.advanceAct(run,map)end);done={}
  elseif run.phase=='combat'then
   local choice=run.combat.pendingChoice
   if choice then
    local uid,best
    for _,candidate in ipairs(choice.uids)do
     for _,pile in ipairs({run.combat.hand,run.combat.discard,run.combat.exhaust})do for _,card in ipairs(pile)do if card.uid==candidate then
      local def=C.cardDefinition(run.combat,card)
      local score=math.max(1,Policy.scoreCard(run,card.cardId))+(def.type=='attack'and 10 or 0)
      if def.type=='status'or def.type=='curse'then score=-10000 end
      if choice.op=='exhaustChoose'or choice.op=='handToDraw'then score=-score end
      if not best or score>best then uid,best=candidate,score end
     end end end
    end
    command('choose_card',function()return Run.chooseCard(run,choice.token,uid)end,{uid=uid,op=choice.op})
   else
   local slot,id=Policy.choosePotion(run)
   if slot then command('potion',function()return Run.usePotion(run,slot,1)end,{slot=slot,id=id})
   else
    local uid,target,choice=Policy.chooseCombat(run)
    if uid then command('play',function()return Run.play(run,uid,target)end,choice)
    else command('end_turn',function()return Run.endTurn(run)end)end
   end
  end
  elseif run.phase=='reward'then
   if run.rewards.goldClaimed==false then command('gold',function()return Run.claimGoldReward(run)end)
   elseif run.rewards.potion and not run.rewards.potion.resolved then
    command('potion_reward',function()if run.rewards.potion.unavailable or Run.potionCount(run)>=run.data.rules.player.potionSlots then return Run.skipPotionReward(run)end return Run.claimPotionReward(run)end)
   elseif not run.rewards.cardResolved then local index=Policy.chooseReward(run);command('card_reward',function()return Run.claimCardReward(run,index)end,{index=index,offers=Run.rewardOptions(run)})
   elseif run.rewards.stolenGold and not run.rewards.stolenGold.claimed then command('stolen_gold',function()return Run.claimStolenGoldReward(run)end)
   elseif run.rewards.manualContinue then command('leave_rewards',function()return Run.leaveCombatRewards(run)end)
   else command('complete_combat',function()return Nodes.completeCombat(run,map)end)end
  elseif run.nodeFlow and not run.nodeFlow.complete then
   local flow=run.nodeFlow
   if flow.eventCombat or flow.type=='combat' or flow.type=='elite' or flow.type=='boss'then command('complete_combat',function()return Nodes.completeCombat(run,map)end)
   elseif flow.type=='event'then
    local options=Nodes.eventOptions(run,flow)
    local choice
    for _,o in ipairs(options)do if o.enabled~=false and not o.disabled and (o.choice=='leave' or o.choice=='continue' or o.choice=='proceed')then choice=o;break end end
    if flow.event.id=='back_to_basics'and flow.event.stage=='intro'then choice=options[2]end
    if flow.event.id=='neow'then choice=options[flow.event.stage=='neow_blessing' and 2 or 1]end
    if not choice then for _,o in ipairs(options)do if o.enabled~=false and not o.disabled then choice=o;break end end end
    assert(choice,'no public event option '..flow.event.id)
    local uid=EventCards.uid(run,map,choice,Policy.scoreCard)
    command('event',function()return Nodes.chooseEvent(run,choice.choice,uid)end,{event=flow.event.id,choice=choice.choice,stage=flow.event.stage,uid=uid})
   else
    local plan=assert(Policy.suggestNodeAction(run,map,coverage,done),'no node plan')
    command(plan.method,function()
     if plan.method=='rest'then return Nodes.rest(run)
     elseif plan.method=='upgrade'then return Nodes.upgrade(run,plan.uid)
     elseif plan.method=='buyCardSlot'then return Nodes.buyCardSlot(run,plan.slot)
     elseif plan.method=='buyCard'then return Nodes.buyCard(run,plan.id)
     elseif plan.method=='removeCard'then return Nodes.removeCard(run,plan.uid)
     elseif plan.method=='buyPotion'then return Nodes.buyPotion(run,plan.slot)
     elseif plan.method=='leaveShop'then return Nodes.leaveShop(run)
     elseif plan.method=='claimTreasure'then return Nodes.claimTreasure(run)
     elseif plan.method=='claimBossTreasure'then return Nodes.claimBossTreasure(run,1)end
    end,plan)
    coverage[plan.coverage or plan.method]=true;done[plan.coverage or plan.method]=true
   end
  else
   local node=assert(Policy.chooseNode(run,map,coverage),'no legal next node')
   command('enter',function()return Nodes.enter(run,map,node.id)end,{node=node.id,type=node.type})
   report.rooms[#report.rooms+1]={floor=run.floor,act=run.act,type=run.nodeFlow.type,event=run.nodeFlow.event and run.nodeFlow.event.id,encounter=run.encounterId}
   coverage[run.nodeFlow.type]=true;done={}
  end
 end
 assert(actions<3000,'action budget exhausted')
 end
 local ok,reason=pcall(execute)
 report.status=ok and run.phase or 'driver_blocked';report.reason=not ok and tostring(reason)or nil
 report.final=snap(run,map)
 local fresh,freshMap=new(seed)
 report.newRunConstructionResetVerified=json(snap(fresh,freshMap))==json(report.initial)
 assert(report.newRunConstructionResetVerified,'new Run construction retained state')
 print('M3_SUMMARY '..json({seed=seed,status=report.status,reason=report.reason,floor=run.floor,hp=run.hp,actions=#report.actions,ending=run.ending}))
 print('M3_EVIDENCE_JSON '..json(report))
end
play(M3_SEED or 42)
