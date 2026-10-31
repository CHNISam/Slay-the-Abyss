-- Controlled history, next-room type and terminal enemy HP are explicit inputs.
-- Actual public Run/Nodes effects and commits are never replaced by expected data.
local Run,Nodes,Map,D,C,R=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_data'),require('abyss_combat'),require('abyss_sts_random')
local CardRandom,Pending=require('abyss_card_random'),require('abyss_relic_pending')
local function same(a,b,label)
 label=label or 'state';assert(type(a)==type(b),label..' type')
 if type(a)~='table'then assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b));return end
 for k,v in pairs(a)do same(v,b[k],label..'.'..tostring(k))end
 for k in pairs(b)do assert(a[k]~=nil,label..' extra '..tostring(k))end
end
return function(v,pools)
 local run=Run.new(D,v.seed,{experimental=true,character='ironclad',campaign=true,campaignProfile='competition-two-act'})
 local map=Map.generate(run.data,run.runSeed,1)
 local function source(id)
  for _,d in ipairs(run.data.cards.cards)do if d.id==id then return assert(d.sourceId or d.sts_name)end end
  error('missing source identity '..tostring(id))
 end
 local function ids(list)local out={};for _,id in ipairs(list)do out[#out+1]=source(id)end;return out end
 local runtime=run.data.cards.sourcePools
 for _,tier in ipairs({'COMMON','UNCOMMON','RARE'})do
  same(ids(runtime.reward[tier:lower()]),pools.redReward[tier],'full reward source pool '..tier)
  for _,kind in ipairs({'ATTACK','SKILL','POWER'})do same(ids(runtime.shop[tier:lower()][kind:lower()]),pools.redShopTyped[tier][kind],'full typed source pool')end
 end
 for _,tier in ipairs({'UNCOMMON','RARE'})do same(ids(runtime.colorlessShop[tier:lower()]),pools.colorlessShopByRarity[tier],'full colorless shop source pool')end
 same({cardRng=R.snapshot(run.cardRng),cardRarityOffset=run.cardRarityOffset},v.initial,'initial card owner')
 -- Read-only observers tag the actual card owner across production transaction
 -- graph copies. They never substitute a stream, return value or chosen identity.
 local tagged=setmetatable({[run.cardRng]=true},{__mode='k'})
 local clone,cardClone,transaction=R.cloneState,CardRandom.clone,Run.transaction
 R.cloneState=function(owner,...)local copy=clone(owner,...);if tagged[owner]then tagged[copy]=true end;return copy end
 CardRandom.clone=function(owner)local copy=cardClone(owner);tagged[copy.cardRng]=true;return copy end
 Run.transaction=function(owner,command)
  return transaction(owner,function(staged)tagged[staged.cardRng]=true;return command(staged)end)
 end
 local int,between,chance=R.randomInt,R.randomIntBetween,R.randomBooleanChance
 local phase,trace='neow',{}
 local function observe(kind,fn,owner,...)
  local args=table.pack(...)
  local marked=tagged[owner];local before=marked and R.snapshot(owner)
  local value=fn(owner,table.unpack(args,1,args.n))
  if marked then
   local row={phase=phase,kind=kind,value=value,before=before,after=R.snapshot(owner)}
   if kind=='chance'then row.chance=args[1]
   elseif kind=='between'then row.minimum,row.maximum=args[1],args[2]
   else row.maximum=args[1]end
   trace[#trace+1]=row
  end
  return value
 end
 R.randomInt=function(owner,...)return observe('int',int,owner,...)end
 R.randomIntBetween=function(owner,...)return observe('between',between,owner,...)end
 R.randomBooleanChance=function(owner,...)return observe('chance',chance,owner,...)end
 local function state(stage)same({cardRng=R.snapshot(run.cardRng),cardRarityOffset=run.cardRarityOffset},stage.after,phase..' owner')end
 local function groups(actual,expected)
  assert(#actual==#expected,'reward group count')
  for i,g in ipairs(actual)do same(ids(g.cards),expected[i].cards,phase..' identities '..i);same(g.cardUpgrades,expected[i].upgrades,phase..' upgrades '..i)end
 end
 local function unchanged(fn)
  local before={cardRng=R.snapshot(run.cardRng),cardRarityOffset=run.cardRarityOffset};local n=#trace
  assert(fn());same({cardRng=R.snapshot(run.cardRng),cardRarityOffset=run.cardRarityOffset},before,'claim/skip must not redraw');assert(#trace==n)
 end
 -- Controlled history qualifies source four-offer Neow, not saved/player history.
 assert(Nodes.beginNeow(run,map,{bossCount=1,source='controlled-source-fixture'}))
 assert(Nodes.chooseEvent(run,'continue'));assert(run.nodeFlow.event.rewards[1].type=='RANDOM_COLORLESS')
 assert(Nodes.chooseEvent(run,'reward_1'))
 local offers={};for _,card in ipairs(run.nodeFlow.event.cardOffers)do offers[#offers+1]=source(card.cardId)end
 same(offers,v.stages[1].cards,'Neow colorless identities');state(v.stages[1])
 unchanged(function()return Nodes.chooseEvent(run,'claim_1')end)
 assert(Nodes.chooseEvent(run,'leave'))
 phase='orrery';assert(Run.obtainRelic(run,'Orrery'))
 local actual={};for _,item in ipairs(run.shopRelicRewards.items)do assert(item.kind=='card');actual[#actual+1]=item.reward end
 groups(actual,v.stages[2].groups);state(v.stages[2])
 while Pending.owner(run)do
  local choice;for _,row in ipairs(Pending.view(run).rows)do if row.token.kind=='done'or row.token.choice==0 then choice=row.token;break end end
  assert(choice);unchanged(function()return Pending.resolve(run,choice)end)
 end
 local function enter(kind)
  local first=assert(Nodes.available(run,map)[1]);for _,node in ipairs(map.nodes)do if node.id==first.id then node.type=kind end end
  assert(Nodes.enter(run,map,first.id))
 end
 phase='shop';enter('shop');local cards={}
 for _,offer in ipairs(run.nodeFlow.cards)do cards[#cards+1]={sourceId=offer.sourceCardId,rarity=offer.rarity}end
 same(cards,v.stages[3].cards,'shop source identities/rarities');state(v.stages[3]);assert(Nodes.leaveShop(run))
 assert(Run.obtainRelic(run,'Prayer Wheel'));assert(Run.obtainRelic(run,'Question Card'))
 local function win(kind)
  enter(kind)
  -- Exact terminal fixture: source construction and reward preparation are real.
  for _,enemy in ipairs(run.combat.enemies)do enemy.hp=0 end
  assert(Run.finishCombat(run))
 end
 phase='wheel';win('combat');groups(run.rewards.cardRewardGroups,v.stages[4].groups);state(v.stages[4])
 if not run.rewards.goldClaimed then assert(Run.claimGoldReward(run))end
 if run.rewards.potion and not run.rewards.potion.resolved then assert(Run.skipPotionReward(run))end
 while not run.rewards.cardResolved do unchanged(function()return Run.claimCardReward(run,0)end)end
 assert(Run.leaveCombatRewards(run));assert(Nodes.completeCombat(run,map))
 assert(Run.obtainRelic(run,'Busted Crown'))
 phase='elite_crown';win('elite')
 local elite=run.rewards.cardRewardGroups or {{cards=run.rewards.cards,cardUpgrades=run.rewards.cardUpgrades}}
 groups(elite,v.stages[5].groups);state(v.stages[5])
 same(trace,v.trace,'complete rarity/identity/retry/upgrade interleaving')
 assert(v.rewardDuplicateRetries>0 and v.shopDuplicateRetries>0,'independent fixture must exercise both retry protocols')
 R.cloneState,CardRandom.clone,Run.transaction=clone,cardClone,transaction
 R.randomInt,R.randomIntBetween,R.randomBooleanChance=int,between,chance
 print('CARD_CONSUMERS_PASS '..#trace..' wrappers; controlled public chain, natural NOT_RUN')
end
