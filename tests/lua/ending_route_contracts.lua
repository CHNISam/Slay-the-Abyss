local F=dofile('tests/lua/support/ending_route_fixture.lua')
local Run,C=F.Run,F.C
local Gold,Relic,Potion,Cards=require('abyss_gold_rewards'),require('abyss_relic_rewards'),require('abyss_potion_rewards'),require('abyss_card_pool')
local count=0
local function test(name,fn)fn();count=count+1;print('PASS ending route contract '..count..' '..name)end
test('all invalid final-act entry owners refuse without changing any graph',function()
 local ready=F.ready();ready.floor=54
 for _,mutate in ipairs({
  function(r)return 'normal'end,function(r)r.floor=52;return 'elite'end,
  function(r)r.floor=54;return 'boss'end,function(r)r.floor=55;return 'elite'end,
  function(r)r.campaign=false;return 'elite'end,function(r)r.endingUnlocked=false;return 'elite'end,
  function(r)r.keys.ruby=false;return 'elite'end,function(r)r.keys.emerald=false;return 'elite'end,
  function(r)r.keys.sapphire=false;return 'elite'end,function(r)r.encounters.act=3;return 'elite'end,
  function(r)r.encounters.rawSeed='43';return 'elite'end,
  function(r)r.bossInitialization.bossList[2]='The Guardian';return 'elite'end})do
  local run=F.snapshot(ready);local tier=mutate(run);local before=F.snapshot(run)
  assert(not Run.startRoomCombat(run,tier));F.same(run,before)
 end
end)
local function hooks(command)
 local original={Gold.prepare,Relic.elite,Potion.prepare,Cards.prepareRewards};local calls={}
 Gold.prepare=function(...)calls[#calls+1]='gold';return original[1](...)end
 Relic.elite=function(...)calls[#calls+1]='relic';return original[2](...)end
 Potion.prepare=function(...)calls[#calls+1]='potion';return original[3](...)end
 Cards.prepareRewards=function(...)calls[#calls+1]='cards';return original[4](...)end
 local ok,why=pcall(command,calls)
 Gold.prepare,Relic.elite,Potion.prepare,Cards.prepareRewards=original[1],original[2],original[3],original[4]
 assert(ok,why)
end
test('formal elite observes Gold Relic Potion Cards construction order through real reward helpers',function()
 local run=F.eliteWon()
 hooks(function(calls)assert(Run.finishCombat(run));F.same(calls,{'gold','relic','potion','cards'})end)
end)
test('late formal card failure rolls back gold relic potion and every original graph alias',function()
 local run,map=F.eliteWon();local before,graph=F.snapshot(run),C.copy(map)
 local deck,pool,combat,flow=run.deck,run.relicPool,run.combat,run.nodeFlow
 local prepare=Cards.prepareRewards;Cards.prepareRewards=function()error('late card source fault')end
 local ok=pcall(Run.finishCombat,run);Cards.prepareRewards=prepare
 assert(not ok);F.same(run,before);F.same(map,graph)
 assert(run.deck==deck and run.relicPool==pool and run.combat==combat and run.nodeFlow==flow)
 assert(Run.finishCombat(run))
end)
test('legacy explicit-ID replay keeps fixed gold and its original Cards Potion order',function()
 local run=Run.new(F.Data or require('abyss_data'),'42')
 local encounter=run.data.enemies.encounters[1];run.floor=encounter.minFloor
 assert(Run.startCombat(run,encounter.id))
 for _,enemy in ipairs(run.combat.enemies)do C.damage(run.combat,run.combat.player,enemy,999,false)end
 hooks(function(calls)
  assert(Run.finishCombat(run));F.same(calls,{'cards','potion'})
  assert(run.rewards.gold==run.data.rules.rewards[run.encounterTier..'Gold'])
 end)
end)
test('actual lethal final-card Beat resolves defeat Fairy survival and Mark suppression before Run publishes ending',function()
 for _,mode in ipairs({'defeat','fairy','mark_fairy'})do
  local run,map=F.ready();run.floor=55
  local _,queue=F.Q.consume(run.encounters,'elite');run.encounters=queue -- controlled prior 54 completion.
  if mode~='defeat'then assert(Run.obtainPotion(run,'fairy_in_a_bottle'))end
  if mode=='mark_fairy'then assert(Run.obtainRelic(run,'Mark of the Bloom'))end
  assert(Run.startRoomCombat(run,'boss'))
  run.nodeFlow={id='55:4',floor=55,type='boss',complete=false,encounterId=run.encounterId,
   encounterSource=run.encounterSource,mapSeed=run.runSeed,mapSignature=map.sourceSignature}
  local battle=run.combat;battle.enemies[1].hp=1;battle.player.hp=1
  local card=require('abyss_card_actions').fresh(C,battle,'strike');battle.hand={card}
  -- Controlled physical hand and lethal HP isolate the real UseCard/Beat/Fairy
  -- pipeline, not a hypothetical outcome or fabricated resurrection relic.
  assert(Run.play(run,card.uid,1));assert(battle.enemies[1].hp==0)
  if mode=='fairy'then
   assert(run.phase=='ending_proceed'and run.hp>0 and run.combat.player.hp>0)
   assert(run.potions[1]==nil);assert(Run.proceedEnding(run,run.endingProceed))
   assert(run.phase=='victory')
  else
   assert(run.phase=='defeat'and run.hp==0 and not run.endingProceed and not run.rewards)
   if mode=='mark_fairy'then assert(run.potions[1]=='fairy_in_a_bottle')end
  end
 end
end)
print('ENDING_ROUTE_CONTRACTS_PASS '..count..' groups; strict refusal and full rollback, no platform claim')
