package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Nodes,Map,Pool,Random=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_relic_pool'),require('abyss_sts_random')
local Data=require('abyss_data')
local H,P=require('abyss_relic_hooks'),require('abyss_potion_rewards')
local count,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)local ok,why=pcall(fn);if ok then count=count+1;print('PASS missing relic '..name)else failed=failed+1;print('FAIL missing relic '..name..': '..tostring(why))end end
local function camp(run)
 local map=Map.generate(Data,42);local first=Map.available(map)[1]
 for _,node in ipairs(map.nodes)do if node.id==first.id then node.type='camp';node.roomKind=nil end end
 assert(Nodes.enter(run,map,first.id));return map
end
test('White Beast source obtain activates the existing exact potion hook',function()
 local run=Run.new(Data,42);assert(Run.obtainRelic(run,'White Beast Statue'))
 eq(run.relics[#run.relics],'white_beast_statue')
 run.potionChanceModifier=-1000
 local reward,rng,modifier=P.prepare(run,0);assert(reward and not reward.unavailable)
 eq(Random.snapshot(rng).counter>0,true);eq(modifier,-1010)
 -- The source four-item room limit overrides even guaranteed potions.
 local blocked,_,nextModifier=P.prepare(run,4);eq(blocked,nil);eq(nextModifier,-990)
end)
test('Pear and Mango increase current and maximum health once without bypassing Bloom',function()
 for _,row in ipairs({{'Pear','pear',10},{'Mango','mango',14}})do
  local run=Run.new(Data,42);run.hp=20;assert(Run.obtainRelic(run,row[1]))
  eq(run.hp,20+row[3]);eq(run.maxHp,80+row[3]);eq(Run.obtainRelic(run,row[1]),false)
  local blocked=Run.new(Data,42);blocked.relics[#blocked.relics+1]='mark_of_bloom';blocked.hp=20
  assert(Run.obtainRelic(blocked,row[1]));eq(blocked.hp,20);eq(blocked.maxHp,80+row[3])
 end
end)
test('Old Coin gains exactly 300 through the existing gold prohibition',function()
 local run=Run.new(Data,42);local before=run.gold;assert(Run.obtainRelic(run,'Old Coin'));eq(run.gold,before+300)
 local blocked=Run.new(Data,42);blocked.relics[#blocked.relics+1]='ectoplasm';before=blocked.gold
 assert(Run.obtainRelic(blocked,'Old Coin'));eq(blocked.gold,before)
end)
test('Frozen Egg upgrades obtained power and reward preview but leaves skill and existing deck alone',function()
 local run=Run.new(Data,42);local existing=run.deck[1];assert(Run.obtainRelic(run,'Frozen Egg 2'));eq(existing.upgraded,false)
 assert(Run.obtainCard(run,'inflame'));eq(run.deck[#run.deck].upgraded,true)
 assert(Run.obtainCard(run,'defend'));eq(run.deck[#run.deck].upgraded,false)
 local reward={cards={'inflame','defend'}};H.previewCardReward(run,reward)
 eq(reward.cardUpgrades[1],true);eq(reward.cardUpgrades[2],nil)
end)
test('Coffee Dripper gives permanent prepared energy and rejects only camp rest',function()
 local run=Run.new(Data,42);assert(Run.obtainRelic(run,'Coffee Dripper'));assert(Run.startCombat(run,'cultist_solo'))
 eq(run.combat.energy,4);assert(Run.endTurn(run));eq(run.combat.energy,4)
 local r=Run.new(Data,42);assert(Run.obtainRelic(r,'Coffee Dripper'));r.hp=20;local map=camp(r)
 local view=Nodes.view(r,map);eq(view.node.canRest,false);eq(view.node.canForge,true)
 local flow=r.nodeFlow;local ok,why=Nodes.rest(r);eq(ok,false);eq(why,'rest_blocked_by_relic');eq(r.hp,20);eq(r.nodeFlow,flow)
 assert(Nodes.upgrade(r,r.deck[1].uid))
end)
test('Fusion Hammer gives prepared energy and rejects only camp smithing',function()
 local run=Run.new(Data,42);assert(Run.obtainRelic(run,'Fusion Hammer'));assert(Run.startCombat(run,'cultist_solo'))
 eq(run.combat.energy,4);assert(Run.endTurn(run));eq(run.combat.energy,4)
 local r=Run.new(Data,42);assert(Run.obtainRelic(r,'Fusion Hammer'));r.hp=20;local map=camp(r)
 local view=Nodes.view(r,map);eq(view.node.canRest,true);eq(view.node.canForge,false)
 local flow=r.nodeFlow;local ok,why=Nodes.upgrade(r,r.deck[1].uid);eq(ok,false);eq(why,'upgrade_blocked_by_relic');eq(r.deck[1].upgraded,false);eq(r.nodeFlow,flow)
 assert(Nodes.rest(r));eq(r.hp,44)
end)
test('camp with no legal rest or smith option can proceed once without applying either benefit',function()
 local run=Run.new(Data,42);assert(Run.obtainRelic(run,'Coffee Dripper'));assert(Run.obtainRelic(run,'Fusion Hammer'));run.hp=20
 local map=camp(run);eq(Nodes.view(run,map).node.canLeaveCamp,true)
 local hp,uid=run.hp,run.deck[1].uid;assert(Nodes.leaveCamp(run));eq(run.phase,'map');eq(run.hp,hp);eq(run.deck[1].uid,uid);eq(run.deck[1].upgraded,false)
 eq(Nodes.leaveCamp(run),false)
 local ordinary=Run.new(Data,42);camp(ordinary);eq(Nodes.leaveCamp(ordinary),false)
end)
assert(failed==0,tostring(failed)..' missing relic regressions failed')
print('LUA_MISSING_RELIC_DEFINITIONS_PASS '..count)
