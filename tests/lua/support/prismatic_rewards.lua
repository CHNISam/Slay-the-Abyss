-- Source proof: path-only boss prefix and terminal enemy HP are controlled
-- fixtures, not a naturally played campaign. All reward generation/claim is public.
local Run,Nodes,Map,D,C,R=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_data'),require('abyss_combat'),require('abyss_sts_random')
local Pool,Cards,Pending=require('abyss_card_pool'),require('abyss_relic_card_rewards'),require('abyss_relic_pending')
local function same(a,b,label)
 label=label or 'state';assert(type(a)==type(b),label..' type')
 if type(a)~='table'then assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],label..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,label..' extra '..tostring(k))end
end
return function(v,pools)
 local run=Run.new(D,v.seed,{experimental=true,character='ironclad',campaign=true,campaignProfile='competition-two-act'})
 local function source(id)
  for _,card in ipairs(run.data.cards.cards)do if card.id==id then return assert(card.sourceId or card.sts_name)end end
  error('missing source '..tostring(id))
 end
 local function ids(cards)local out={};for _,id in ipairs(cards)do out[#out+1]=source(id)end;return out end
 assert(Run.obtainRelic(run,'PrismaticShard'));assert(run.masterMaxOrbs==1)
 assert(Run.obtainRelic(run,'Singing Bowl')) -- public modal owner prerequisite, no RNG/count modifier
 local actual=Pool.prismaticPools(run)
 for _,tier in ipairs({'COMMON','UNCOMMON','RARE'})do same(ids(actual[tier:lower()]),pools[tier],'full320 source identity pool '..tier)end
 assert(#pools.COMMON==76 and #pools.UNCOMMON==160 and #pools.RARE==84)
 local healing={};for _,tier in pairs(pools)do for _,id in ipairs(tier)do healing[id]=true end end
 assert(healing.Feed and healing.Reaper and healing["Bandage Up"],'reward overload retains HEALING')
 local function owner()return {cardRng=R.snapshot(run.cardRng),cardRarityOffset=run.cardRarityOffset}end
 same(owner(),v.initial,'initial owner')
 local tagged=setmetatable({[run.cardRng]=true},{__mode='k'})
 local clone,transaction=R.cloneState,Run.transaction
 R.cloneState=function(original,...)local copy=clone(original,...);if tagged[original]then tagged[copy]=true end;return copy end
 Run.transaction=function(original,command)return transaction(original,function(staged)tagged[staged.cardRng]=true;return command(staged)end)end
 local int,long,chance,boolean=R.randomInt,R.randomLongHex,R.randomBooleanChance,R.randomBoolean
 local phase,trace='boss',{}
 local function observe(kind,fn,rng,...)
  local args=table.pack(...);local marked=tagged[rng];local before=marked and R.snapshot(rng)
  local value=fn(rng,table.unpack(args,1,args.n))
  if marked then
   local row={phase=phase,kind=kind,value=value,before=before,after=R.snapshot(rng)}
   if kind=='int'then row.maximum=args[1]elseif kind=='chance'then row.chance=args[1]end
   trace[#trace+1]=row
  end
  return value
 end
 R.randomBoolean=function(rng,...)return observe('boolean',boolean,rng,...)end
 R.randomInt=function(rng,...)return observe('int',int,rng,...)end
 R.randomLongHex=function(rng,...)return observe('long',long,rng,...)end
 R.randomBooleanChance=function(rng,...)return observe('chance',chance,rng,...)end
 local function unchanged(fn)
  local before=owner();local length=#trace;assert(fn());same(owner(),before,'claim must not redraw');assert(#trace==length)
 end
 local stale
 local function reward(stage)
  for _,enemy in ipairs(run.combat.enemies)do enemy.hp=0 end
  assert(Run.finishCombat(run))
  assert(#trace==stage.traceEnd,phase..' exact long/identity/retry draw count')
  same(ids(run.rewards.cards),stage.cards,phase..' identities');same(run.rewards.cardUpgrades,stage.upgrades,phase..' upgrades')
  same(owner(),stage.after,phase..' complete owner')
  local prefix={};for i=1,stage.traceEnd do prefix[i]=v.trace[i]end
  same(trace,prefix,phase..' exact interleaving')
  unchanged(function()return Cards.open(run,run.rewards)end)
  if stale then
   local before=C.copy(run);local rewards,deck,pending=run.rewards,run.deck,run.pendingCardRewardSelection;local count=#trace
   local ok,why=Pending.resolve(run,stale);assert(not ok and why=='stale_relic_choice','old reward token rejected')
   same(run,before,'stale token full rollback');assert(run.rewards==rewards and run.deck==deck and run.pendingCardRewardSelection==pending);assert(#trace==count)
  end
  local token
  for _,row in ipairs(Pending.view(run).rows)do if row.token.kind=='card'and row.token.choice==1 then token=row.token;break end end
  assert(token);local count=#run.deck;local uid=run.nextDeckUid
  unchanged(function()return Pending.resolve(run,token)end)
  assert(#run.deck==count+1 and run.nextDeckUid==uid+1,'public card instance committed')
  same(source(run.deck[#run.deck].cardId),stage.cards[1],'claimed source identity')
  same(run.deck[#run.deck].upgraded==true,stage.upgrades[1],'claimed upgrade')
  stale=token
  if not run.rewards.goldClaimed then unchanged(function()return Run.claimGoldReward(run)end)end
  if run.rewards.potion and not run.rewards.potion.resolved then unchanged(function()return Run.skipPotionReward(run)end)end
  unchanged(function()return Run.leaveCombatRewards(run)end)
 end
 local map=Map.generate(run.data,run.runSeed,1,assert(Run.freezeMapContext(run)))
 while Map.available(map)[1].floor<16 do assert(Map.choose(map,Map.available(map)[1].id))end
 assert(Nodes.enter(run,map,Map.available(map)[1].id));assert(run.encounterTier=='boss')
 reward(v.stages[1]);assert(Nodes.completeCombat(run,map))
 assert(Nodes.enter(run,map,Nodes.available(run,map)[1].id));assert(Nodes.claimBossTreasure(run,0));phase='transition';assert(Nodes.advanceAct(run,map));assert(run.act==2)
 same(owner(),v.stages[2].after,'transition complete source owner');assert(#trace==v.stages[2].traceEnd,'transition exact consumption')
 phase='normal_act2';assert(Nodes.enter(run,map,Nodes.available(run,map)[1].id));assert(run.encounterTier=='normal')
 reward(v.stages[3]);assert(Nodes.completeCombat(run,map))
 -- Controlled tier API: same Act2 owner, not an assertion of a natural elite map route.
 phase='elite_act2';assert(Run.startRoomCombat(run,'elite'));reward(v.stages[4])
 same(trace,v.trace,'complete source trace');assert(v.duplicateRetries>0,'source retry exercised')
 R.cloneState,Run.transaction=clone,transaction;R.randomInt,R.randomLongHex,R.randomBooleanChance,R.randomBoolean=int,long,chance,boolean
 print('PRISMATIC_REWARDS_PASS '..#trace..' wrappers, full320 pool, real claims; natural NOT_RUN')
end
