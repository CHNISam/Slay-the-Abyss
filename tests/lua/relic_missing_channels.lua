package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,N,Map,C,P,R,T=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat'),require('abyss_relic_pool'),require('abyss_sts_random'),require('abyss_treasure')
local D=require('abyss_data');local template=Map.generate(D,42)
local cases={{'White Beast Statue','white_beast_statue','uncommon'},{'Pear','pear','uncommon'},{'Mango','mango','rare'},
 {'Old Coin','old_coin','rare'},{'Frozen Egg 2','frozen_egg','uncommon'},{'Coffee Dripper','coffee_dripper','boss'},{'Fusion Hammer','fusion_hammer','boss'}}
local count=0
for _,character in ipairs({'ironclad','defect','raiden'})do for _,row in ipairs(cases)do
 local run=Run.new(D,42,{experimental=true,character=character,campaign=true});local map=C.copy(template)
 if character=='raiden'then
  assert(run.character=='raiden'and run.characterProfile.originalV4==true and run.characterProfile.role=='RD')
  assert(run.data.originalV4Role=='RD'and run.deck[1].cardId:match('^RD2%-'))
 end
 -- Controlled queue checkpoint: put the target first, retaining every other
 -- identity and RNG owner. This verifies real public source-chest claims;
 -- it is not evidence of a natural seed or a full route played by a person.
 local snap=P.snapshot(run.relicPool);local queue=snap.queues[row[3]];local original=#queue
 for i,id in ipairs(queue)do if id==row[1]then table.remove(queue,i);break end end
 table.insert(queue,1,row[1]);assert(#queue==original);run.relicPool=P.restore(snap,run.relicPool.catalog)
 if row[3]=='boss'then
  while Map.available(map)[1].floor<16 do assert(Map.choose(map,Map.available(map)[1].id))end
  assert(N.enter(run,map,Map.available(map)[1].id))
  for _,enemy in ipairs(run.combat.enemies)do enemy.hp=0 end
  assert(Run.finishCombat(run));assert(Run.claimCardReward(run,0))
  dofile('tests/lua/support/finish_combat_rewards.lua')(run);assert(N.completeCombat(run,map))
 end
 local first=Map.available(map)[1]
 if row[3]~='boss'then
  for _,node in ipairs(map.nodes)do if node.id==first.id then node.type='treasure';node.roomKind=nil end end
 end
 if row[3]~='boss'then
  local found=false
  for counter=0,99 do
   run.treasureRng=R.atCounter(run.eventSeed,counter)
   if T.create(run).chest.relicTier==row[3]then found=true;break end
  end
  assert(found)
 end
 assert(N.enter(run,map,first.id));assert(N.openTreasure(run))
 local item
 for _,v in ipairs(run.nodeFlow.reward.items)do if v.sourceId==row[1]then item=v;break end end
 assert(item and item.available and item.id==row[2],row[1]..' source item must be available')
 local owner=row[3]~='boss' and assert(N.treasureRewardSource(run,item.slot)) or nil
 local function claim()if row[3]=='boss'then return N.claimBossTreasure(run,1)end;return N.claimTreasureReward(run,owner)end
 assert(claim())
 assert(run.relics[#run.relics]==row[2]);local relics,gold,hp=run.relics,run.gold,run.hp
 assert(not claim());assert(run.relics==relics and run.gold==gold and run.hp==hp)
 assert(#run.relicPool.queues[row[3]]==original-(row[3]=='boss'and 3 or 1))
 print('PASS source chest '..character..' '..row[1]);count=count+1
end end
print('LUA_MISSING_RELIC_CHANNELS_PASS '..count)
