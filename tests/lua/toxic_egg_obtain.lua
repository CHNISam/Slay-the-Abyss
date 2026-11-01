package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C=require('abyss_run'),require('abyss_combat')
local D=require('abyss_data')
local passed,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)local ok,why=pcall(fn);if ok then passed=passed+1;print('PASS '..name)else failed=failed+1;print('FAIL '..name..': '..tostring(why))end end
local function same(a,b,seen)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 seen=seen or {};if seen[a]==b then return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function find(r,id)for _,d in ipairs(r.data.cards.cards)do if d.id==id then return d end end end
test('public source obtain upgrades exactly one eligible permanent Skill before insertion and keeps UID/RNG/input private',function()
 local r=Run.new(D,42);local other=Run.new(D,42);local original=C.copy(D)
 local ok,id=Run.obtainRelic(r,'Toxic Egg 2');assert(ok,id);eq(id,'toxic_egg')
 assert(Run.obtainRelic(r,'CeramicFish'))
 local streams={};for _,key in ipairs({'cardRng','miscRng','treasureRng','potionRng'})do streams[key]=C.copy(r[key])end
 local gold,uid=r.gold,r.nextDeckUid
 for _,spec in ipairs({{'defend',false,true},{'defend',true,true},{'strike',false,false},{'demon_form',false,false},{'jax',false,true},{'bandage_up',false,true},{'wound',false,false},{'regret',false,false}})do
  local added,got=Run.obtainCard(r,spec[1],{upgraded=spec[2]});assert(added,got);eq(got,uid)
  local card=r.deck[#r.deck];eq(card.uid,uid);eq(card.upgraded,spec[3]);uid=uid+1
  if spec[1]=='defend'and not spec[2]then eq(card.upgrades,1)end
 end
 eq(r.gold,gold+8*9);for key,value in pairs(streams)do same(r[key],value)end
 local unupgradeable={upgraded=false};require('abyss_relic_hooks').onPreviewObtainCard(r,unupgradeable,{type='skill',upgrade={}})
 eq(unupgradeable.upgraded,false)
 assert(not find(r,'defend').upgraded);eq(other.deck[6].upgraded,false);same(D,original)
 local snapshot=C.copy(r);local rejected,why=Run.obtainCard(r,'missing');eq(rejected,false);eq(why,'card_content_unavailable');same(r,snapshot)
end)
test('equipment upgrades existing unresolved card rewards without upgrading old deck or current shop shelf',function()
 local r=Run.new(D,42);local old=C.copy(r.deck);local gold=r.gold
 r.phase='reward';r.rewards={cards={'defend','strike','defend'},cardUpgrades={false,false,true},cardResolved=false}
 r.nodeFlow={type='shop',cards={{id='defend',upgraded=false}}}
 local before=C.copy(r.cardRng);local ok,id=Run.obtainRelic(r,'Toxic Egg 2');assert(ok,id)
 eq(r.rewards.cardUpgrades[1],true);eq(r.rewards.cardUpgrades[2],false);eq(r.rewards.cardUpgrades[3],true)
 same(r.deck,old);eq(r.nodeFlow.cards[1].upgraded,false);same(r.cardRng,before);eq(r.gold,gold)
end)
test('a failing later permanent hook rolls back the Egg upgrade UID gold and graph',function()
 local r=Run.new(D,42);assert(Run.obtainRelic(r,'Toxic Egg 2'));assert(Run.obtainRelic(r,'CeramicFish'));r.gold=2147483647
 local alias={};alias.self=alias;r.probe=alias;r.alias=alias
 local before=C.copy(r);local ok=Run.obtainCard(r,'defend');eq(ok,false);same(r,before);eq(r.probe,r.alias);eq(r.probe.self,r.probe)
end)
test('ordinary random-upgraded cards skip preview dispatch while equipment preview still visits them',function()
 local r=Run.new(D,42);assert(Run.obtainRelic(r,'Toxic Egg 2'));local H=require('abyss_relic_hooks')
 local reward={cards={'defend','strike','defend'},cardUpgrades={true,false,false}}
 local original,calls=H.onPreviewObtainCard,0
 H.onPreviewObtainCard=function(...)calls=calls+1;return original(...)end
 H.previewCardReward(r,reward,true);local ordinary=calls;calls=0
 H.previewCardReward(r,reward);H.onPreviewObtainCard=original
 eq(ordinary,2);eq(calls,3);eq(reward.cardUpgrades[1],true);eq(reward.cardUpgrades[3],true)
end)
print('TOXIC_EGG_OBTAIN '..passed..' passed; '..failed..' failed');assert(failed==0)
