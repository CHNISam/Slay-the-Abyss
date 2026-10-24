package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Nodes,Map,Combat= require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat')
local data=require('abyss_data')
local finishCombatRewards=dofile('tools/diagnostics/finish_combat_rewards.lua')
local seed=42
local run,map=Run.new(data,seed),Map.generate(data,seed)
local function ledger(label)
 local deck={};for _,c in ipairs(run.deck) do deck[#deck+1]=c.cardId..(c.upgraded and '+' or '') end
 print(label,'floor='..run.floor,'phase='..run.phase,'hp='..run.hp,'gold='..run.gold,'wins='..run.victories,'potions='..Run.potionCount(run),'relics='..table.concat(run.relics,','),'deck='..table.concat(deck,','))
end
local preferred={'bludgeon','carnage','flame_barrier','shrug_it_off','cleave','twin_strike','iron_wave','anger','pommel_strike','uppercut','inflame','battle_trance'}
local function rank(id) for i,x in ipairs(preferred) do if x==id then return 100-i end end return 0 end
local turns,plays=0,0
ledger('START seed=42')
for step=1,17 do
 local available=Nodes.available(run,map)
 if #available==0 then print('STOP no_available_nodes');break end
 -- Stable route preference, not seeded search or future-map optimization.
 local scores={camp=80,treasure=70,event=60,shop=50,combat=30,elite=10,boss=0}
 table.sort(available,function(a,b) if scores[a.type]~=scores[b.type] then return scores[a.type]>scores[b.type] end return a.id<b.id end)
 local node=available[1]
 print('ENTER',node.id,node.type,node.encounterId or '',node.roomKind or '')
 local ok,reason=Nodes.enter(run,map,node.id)
 if not ok then print('STOP rejected',reason);break end
 local nodeType=run.nodeFlow.type -- Unknown rooms may resolve as a shop or treasure.
 if run.phase=='combat' then
  for turn=1,100 do
   turns=turns+1
   local s=run.combat
   local enemies={};for i,e in ipairs(s.enemies) do enemies[#enemies+1]=i..':'..e.id..':'..e.hp end
   print('TURN',node.id,s.turn,'hp='..s.player.hp,'energy='..s.energy,'enemies='..table.concat(enemies,','))
   for action=1,30 do
    if run.phase~='combat' then break end
    s=run.combat
    local target
    for i,e in ipairs(s.enemies) do if e.hp>0 and (not target or e.hp<s.enemies[target].hp) then target=i end end
    local chosen,priority
    for _,c in ipairs(s.hand) do
     if Combat.canPlay(s,c.uid,target) then
      local def=Combat.cardDefinition(s,c)
      local p=(def.type=='attack' and 100 or 0)+rank(c.cardId)
      if not chosen or p>priority then chosen,priority=c,p end
     end
    end
    if not chosen then break end
    print('PLAY',chosen.cardId,chosen.uid,target)
    assert(Run.play(run,chosen.uid,target));plays=plays+1
   end
   if run.phase~='combat' then break end
   assert(Run.endTurn(run))
   if run.phase~='combat' then break end
  end
  if run.phase=='combat' then print('STOP bounded_100_turns');break end
  if run.phase=='defeat' then ledger('DEFEAT');break end
  local options=Run.rewardOptions(run);local choice=0
  for i,id in ipairs(options) do if rank(id)>0 and (choice==0 or rank(id)>rank(options[choice])) then choice=i end end
  print('REWARD',table.concat(options,','),'choice='..choice)
  assert(Run.claimCardReward(run,choice));finishCombatRewards(run,map)
 elseif nodeType=='camp' then
  if run.hp<run.maxHp-15 then print('REST');assert(Nodes.rest(run))
  else
   local cards=Nodes.view(run,map).node.upgradeCards;local c=cards[1]
   for _,v in ipairs(cards) do if rank(v.cardId)>rank(c.cardId) then c=v end end
   print('UPGRADE',c.cardId,c.uid);assert(Nodes.upgrade(run,c.uid))
  end
 elseif nodeType=='shop' then
  local offers=Nodes.view(run,map).node.cards
  table.sort(offers,function(a,b) if rank(a.id)~=rank(b.id) then return rank(a.id)>rank(b.id) end return a.id<b.id end)
  for _,o in ipairs(offers) do if rank(o.id)>0 and run.gold>=o.price then print('BUY',o.id,o.price);assert(Nodes.buyCard(run,o.id));break end end
  assert(Nodes.leaveShop(run))
 elseif nodeType=='treasure' then
  if run.nodeFlow.roomKind=='boss_treasure' then assert(Nodes.claimBossTreasure(run,0))
  else assert(Nodes.claimTreasure(run)) end
 elseif nodeType=='event' then
  local v=Nodes.view(run,map).node.event
  if v.id=='cleric' and run.hp<run.maxHp-15 and run.gold>=v.healCost then print('EVENT heal');assert(Nodes.chooseEvent(run,'heal'))
  elseif v.id=='purifier' then print('EVENT pray',run.deck[1].uid);assert(Nodes.chooseEvent(run,'pray',run.deck[1].uid))
  else assert(Nodes.chooseEvent(run,'leave')) end
 else error('unsupported_node_type:'..tostring(nodeType))
 end
 ledger('COMPLETE '..node.id)
end
ledger('END turns='..turns..' plays='..plays)

if run.phase=='defeat' then
 local e=run.combat.enemies[1]
 print('FINAL_ENEMY',e.id,e.hp,'player='..run.combat.player.hp,'turn='..run.combat.turn)
 local ok,reason=Nodes.completeCombat(run,map)
 assert(ok==false and reason=='run_defeated')
 assert(#Nodes.available(run,map)==0)
 print('LOSS_GATE',reason,'available=0')
 local fresh=Run.new(data,seed)
 assert(fresh.hp==80 and fresh.gold==99 and #fresh.deck==10 and #fresh.relics==1 and Run.potionCount(fresh)==0)
 print('FRESH_RUN',fresh.hp,fresh.gold,#fresh.deck,#fresh.relics,Run.potionCount(fresh))
end
