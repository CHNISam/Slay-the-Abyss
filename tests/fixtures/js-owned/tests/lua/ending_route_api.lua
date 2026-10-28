package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D,Q,R=require('abyss_run'),require('abyss_combat'),require('abyss_data'),require('abyss_encounter_queue'),require('abyss_sts_random')
assert(type(Run.proceedEnding)=='function','ENDING_ROUTE_API_MISSING: explicit final Proceed transaction')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 if a==b then return end;eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil,tostring(k))end
end
local function fixture()
 local run=Run.new(D,'42',{experimental=true,campaign=true})
 -- Controlled source-history/key/late-room boundary. Not natural route proof.
 run.act,run.floor,run.endingUnlocked,run.keys=4,55,true,{ruby=true,emerald=true,sapphire=true}
 local q=Q.new(run.runSeed,4);run.bossInitialization,run.encounters=Q.initializeBoss(q)
 local _,nextQueue=Q.consume(run.encounters,'elite');run.encounters=nextQueue
 assert(Run.startRoomCombat(run,'boss'))
 run.combat.player.hp=40 -- combat-end Burning Blood must not invalidate Proceed.
 run.nodeFlow={id='55:4',floor=55,type='boss',complete=false,encounterId=run.encounterId,
  encounterSource=run.encounterSource,mapSeed=run.runSeed,mapSignature='controlled-source-map'}
 return run
end
local function defeated(run)
 run.combat.enemies[1].hp=0 -- controlled final-damage boundary only.
 local misc=R.cloneState(run.combat.miscRng);R.randomIntBetween(misc,-5,5)
 local card,potion,treasure=R.snapshot(run.cardRng),run.shopRng and R.snapshot(run.shopRng.potion),R.snapshot(run.treasureRng)
 local gold=run.gold;assert(Run.finishCombat(run));eq(run.phase,'ending_proceed');eq(run.rewards,nil);eq(run.gold,gold)
 same(R.snapshot(run.miscRng),R.snapshot(misc));same(R.snapshot(run.cardRng),card)
 same(R.snapshot(run.treasureRng),treasure)
 eq(run.shopRng and R.snapshot(run.shopRng.potion).counter,potion and potion.counter)
 return run.endingProceed
end
do
 local run=fixture();local owner=defeated(run)
 local snapshot=C.copy(run,{[run.data]=run.data});local flow=run.nodeFlow
 assert(not Run.proceedEnding(run));assert(not Run.proceedEnding(run,C.copy(owner)))
 assert(not Run.proceedEnding(run,setmetatable({},{__eq=function()return true end})))
 same(run,snapshot);eq(run.nodeFlow,flow);eq(run.endingProceed,owner)
 assert(Run.proceedEnding(run,owner));eq(run.phase,'victory');eq(run.ending,'true_victory')
 eq(run.endingProceed,nil);eq(run.nodeFlow.complete,true);eq(run.nodeFlow.result,'true_victory')
 assert(not Run.proceedEnding(run,owner))
end
do
 for _,mutate in ipairs({
  function(r)r.keys.ruby=false end,function(r)r.endingUnlocked=false end,
  function(r)r.combat.cardActions={{effect={op='heartBeat'}}}end,
  function(r)r.combat.player.hp=0 end,function(r)r.nodeFlow.complete=true end,
  function(r)r.endingProceed.extra=true end,function(r)r.combat.enemies[1].definitionId='cultist'end})do
  local run=fixture();local owner=defeated(run);mutate(run)
  local snapshot=C.copy(run,{[run.data]=run.data});local deck,flow=run.deck,run.nodeFlow
  assert(not Run.proceedEnding(run,owner));same(run,snapshot);eq(run.deck,deck);eq(run.nodeFlow,flow)
 end
end
do
 local run=fixture();run.combat.enemies[1].hp=0;run.combat.player.hp=0
 assert(Run.finishCombat(run));eq(run.phase,'defeat');eq(run.endingProceed,nil);eq(run.rewards,nil)
end
print('ENDING_ROUTE_API_PASS 3 groups; controlled source-history/final-damage boundaries, no natural run claim')
