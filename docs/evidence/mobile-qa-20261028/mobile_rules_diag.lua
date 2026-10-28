package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,Nodes,Map,C,T,D=require('abyss_run'),require('abyss_nodes'),require('abyss_map'),require('abyss_combat'),require('abyss_treasure'),require('abyss_data')
local function snap(r)local out={}for _,c in ipairs(r.deck)do out[#out+1]=c.cardId..':'..tostring(c.upgraded==true)..':'..tostring(c.upgrades or 0)end;return table.concat(out,',')end
local function new()local r=Run.new(D,42);r.deck={{uid=1,cardId='defend',upgraded=false},{uid=2,cardId='battle_trance',upgraded=false},{uid=3,cardId='strike',upgraded=false}};r.nextDeckUid=4;r.hp=10;return r end
local function camp(r)local m=Map.generate(r.data,42);local id=Map.available(m)[1].id;for _,n in ipairs(m.nodes)do if n.id==id then n.type='camp'end end;assert(Nodes.enter(r,m,id));return m end
for _,relic in ipairs({'none','war_paint','whetstone'})do
 local r=new();local before=snap(r)
 if relic~='none'then assert(Run.obtainRelic(r,relic))end
 local afterObtain=snap(r);camp(r);local beforeRest=snap(r);local hp=r.hp
 assert(Nodes.rest(r));local afterRest=snap(r)
 assert(beforeRest==afterRest,'rest unexpectedly changed deck')
 if relic=='war_paint'then assert(r.deck[1].upgraded and r.deck[2].upgraded and not r.deck[3].upgraded)end
 if relic=='whetstone'then assert(not r.deck[1].upgraded and not r.deck[2].upgraded and r.deck[3].upgraded)end
 print('DIAG rest relic='..relic..' before='..before..' afterObtain='..afterObtain..' afterRest='..afterRest..' hp='..hp..'->'..r.hp)
end
local function front(q,id)for i=#q,1,-1 do if q[i]==id then table.remove(q,i)end end;table.insert(q,1,id)end
local r=new();front(r.relicPool.queues.uncommon,'White Beast Statue')
local prepared=assert(T.open(r,{kind='medium',kindRoll=60,rewardRoll=80,relicTier='uncommon',goldReward=false,opened=false},{items={}}))
assert(#prepared.reward.items==1)
local item=prepared.reward.items[1];local taken,why=T.take(prepared.reward,item.slot)
assert(item.sourceId=='White Beast Statue' and item.available==false and taken==nil and why=='relic_content_unavailable')
print('DIAG white_beast id='..item.id..' available='..tostring(item.available)..' items='..#prepared.reward.items..' take='..why)
local b=Run.new(D,'1');local boss=assert(T.prepare(b,{boss=true}));for _,i in ipairs(boss.reward.items)do local value,reason=T.take(boss.reward,i.slot);print('DIAG boss_seed1 id='..i.id..' available='..tostring(i.available)..' take='..tostring(reason or value~=nil))end
print('MOBILE_RULES_DIAG_PASS')
