package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,G=require('abyss_run'),require('abyss_gold_rewards')
local r=Run.new(require('abyss_data'),'42');local ok,why=Run.obtainRelic(r,'golden_idol');assert(ok,why)
assert(G.offerAmount(10,r)==13);assert(G.offerAmount(14,r)==18);assert(G.offerAmount(98,r)==123)
local C,R=require('abyss_combat'),require('abyss_sts_random')
for _,tier in ipairs({'normal','elite','boss'})do for index=0,10 do
 local rng=R.restore({words={'0000000000000000',string.format('%016x',index)},counter=0})
 local streams={treasureRng=R.cloneState(rng),miscRng=R.cloneState(rng)}
 local before=C.copy(streams);local base,key,next=G.prepare(tier,streams)
 assert(base==(tier=='normal'and 10 or tier=='elite'and 25 or 95)+index)
 assert(key==(tier=='boss'and'miscRng'or'treasureRng'))
 assert(G.offerAmount(base,r)==base+math.floor(base*.25+.5));assert(next.counter==1)
 for _,name in ipairs({'treasureRng','miscRng'})do assert(streams[name].counter==before[name].counter);for i=1,2 do assert(R.snapshot(streams[name]).words[i]==R.snapshot(before[name]).words[i])end end
end end
-- Offer creation freezes once; lost/new ownership before claim never recalculates.
local function terminal(held)
 local run=Run.new(require('abyss_data'),42);if held then assert(Run.obtainRelic(run,'golden_idol'))end
 assert(Run.startCombat(run,'cultist_solo'));run.combat.enemies[1].hp=0;assert(Run.finishCombat(run));return run
end
local with=terminal(true);assert(with.rewards.gold==19);local frozen=with.rewards.gold
for i,id in ipairs(with.relics)do if id=='golden_idol'then table.remove(with.relics,i);break end end
local gold=with.gold;assert(Run.claimGoldReward(with));assert(with.gold==gold+frozen)
local without=terminal(false);assert(without.rewards.gold==15);assert(Run.obtainRelic(without,'golden_idol'));gold=without.gold;assert(Run.claimGoldReward(without));assert(without.gold==gold+15)
local stolen=terminal(true);stolen.rewards.stolenGold={type='STOLEN_GOLD',amount=7,claimed=false};gold=stolen.gold;assert(Run.claimStolenGoldReward(stolen));assert(stolen.gold==gold+7)
gold=stolen.gold;assert(Run.gainGold(stolen,333)==333);assert(stolen.gold==gold+333)
local ecto=terminal(true);ecto.relics[#ecto.relics+1]='ectoplasm';gold=ecto.gold;assert(Run.claimGoldReward(ecto));assert(ecto.gold==gold and ecto.rewards.gold==19)
local F=dofile('tests/lua/support/golden_idol_fixture.lua')
-- A real TreasureRoom fallback remains direct base gold; SPECIAL Idol is not a chest candidate.
local chest,map,node=F.fixture();assert(Run.obtainRelic(chest,'golden_idol'))
for i=#chest.data.relics.relics,1,-1 do local d=chest.data.relics.relics[i];if d.rarity~='special'and d.rarity~='starter'then table.remove(chest.data.relics.relics,i)end end
for _,v in ipairs(map.nodes)do if v.id==node then v.type='treasure';v.eventId=nil end end
assert(F.Nodes.enter(chest,map,node));assert(chest.nodeFlow.reward.gold==15);gold=chest.gold;assert(F.Nodes.claimTreasure(chest));assert(chest.gold==gold+15)
-- Actual formal reward boundary keeps bonus + card/potion/RNG updates private on a later failure.
local source=Run.new(F.D,'42');assert(Run.obtainRelic(source,'golden_idol'));assert(Run.startRoomCombat(source,'normal'));for _,e in ipairs(source.combat.enemies)do e.hp=0 end
local saved=C.copy(source);local P=require('abyss_potion_rewards');local prepare=P.prepare
P.prepare=function()error('after Golden offer')end;local called=pcall(Run.finishCombat,source);P.prepare=prepare;assert(not called);F.same(source,saved)
assert(Run.finishCombat(source));assert(source.rewards.gold>=13 and source.rewards.gold<=25)
print('GOLDEN_IDOL_GOLD_PASS 33 raw source outcomes/RNG preserved; offer-frozen round bonus, late owner changes, direct/stolen exclusion and Ectoplasm claim gate')
