-- Integration only: history, prior routing and destination room types are
-- explicitly staged; actual public entry/obtain/key commands are exercised.
local Run,Nodes,Map=require('abyss_run'),require('abyss_nodes'),require('abyss_map')
local C,Data=require('abyss_combat'),require('abyss_data')
local count=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b,seen)
 if a==b then return end;eq(type(a),type(b));if type(a)~='table' then eq(a,b);return end
 seen=seen or {};if seen[a]then eq(seen[a],b);return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function identities(root)
 local refs,seen={},{}
 local function walk(owner)
  if seen[owner]then return end;seen[owner]=true
  for k,v in pairs(owner)do if type(v)=='table'then refs[#refs+1]={owner,k,v};walk(v)end end
 end
 walk(root);return refs
end
local function refusal(r,m,fn,reason)
 local before,mbefore=C.copy(r),C.copy(m);local refs=identities(r);local mrefs=identities(m)
 local ok,why=fn();eq(ok,false);if reason then eq(why,reason)else assert(type(why)=='string')end
 same(r,before);same(m,mbefore)
 for _,list in ipairs({refs,mrefs})do for _,ref in ipairs(list)do eq(ref[1][ref[2]],ref[3])end end
end
local function test(name,fn)fn();count=count+1;print('PASS M3v2 keys/Darkstone '..count..' '..name)end
local function toCamp(r)
 local m=Map.generate(r.data,r.runSeed)
 while true do
  local choices=Map.available(m);assert(#choices>0)
  for _,n in ipairs(choices)do if n.type=='camp'then assert(Nodes.enter(r,m,n.id));return m end end
  assert(Map.choose(m,choices[1].id))
 end
end
local function chest(floor)
 local data=C.copy(Data);local relics={}
 for _,relic in ipairs(data.relics.relics)do if relic.id=='darkstone_periapt'or relic.rarity=='starter'then relics[#relics+1]=relic end end
 data.relics.relics=relics
 local r=Run.new(data,'42',{experimental=true,campaign=true});r.act=3;r.endingUnlocked=true
 local m=Map.generate(data,r.runSeed,3)
 while Map.available(m)[1].floor<floor do assert(Map.choose(m,Map.available(m)[1].id))end
 r.floor=m.floor;eq(r.floor,floor-1)
 local next=Map.available(m)[1]
 for _,n in ipairs(m.nodes)do if n.id==next.id then n.type='treasure';n.roomKind=nil end end
 assert(Nodes.enter(r,m,next.id));eq(r.floor,floor);return r,m
end

test('ignored nested stale Recall rolls back prior Darkstone curse health/card/gold and every original owner',function()
 local r=Run.new(Data,'42',{experimental=true,campaign=true});r.endingUnlocked=true
 assert(Run.obtainRelic(r,'Darkstone Periapt'));r.hp=17;local m=toCamp(r)
 local token=assert(Nodes.recallSource(r,m));token.roomGeneration=token.roomGeneration+1
 local oldMax,oldHp,oldGold=r.maxHp,r.hp,r.gold;local called=false
 refusal(r,m,function()return Run.transaction(r,function(staged)
  assert(Run.gainGold(staged,91)==91);assert(Run.obtainCard(staged,'writhe'))
  eq(staged.maxHp,oldMax+6);eq(staged.hp,oldHp+6);eq(staged.gold,oldGold+91)
  local ok,why=Nodes.recall(staged,m,token);eq(ok,false);eq(why,'camp_source_mismatch');called=true
  return true -- Deliberately ignore the failed child command.
 end)end,'camp_source_mismatch')
 assert(called);eq(r.maxHp,oldMax);eq(r.hp,oldHp);eq(r.gold,oldGold)
 assert(Nodes.recall(r,m,assert(Nodes.recallSource(r,m))))
 assert(r.keys.ruby and not r.keys.sapphire and not r.keys.emerald)
end)

test('destination48 linked Darkstone or Sapphire is one exclusive choice; replay never grants the opposite',function()
 for _,choice in ipairs({'relic','sapphire'})do
  local r,m=chest(48);eq(r.nodeFlow.reward.relicId,'darkstone_periapt')
  local token=assert(Nodes.treasureSource(r,m));eq(token.relicId,'darkstone_periapt')
  r.hp=17;local max,hp,slots=r.maxHp,r.hp,#r.relics
  assert(Nodes.chooseTreasure(r,m,token,choice));eq(r.keys.sapphire,choice=='sapphire')
  eq(#r.relics,slots+(choice=='relic'and 1 or 0));eq(r.maxHp,max);eq(r.hp,hp)
  assert(not r.nodeFlow.reward.sapphireKey and not Nodes.treasureSource(r,m))
  for _,replay in ipairs({'relic','sapphire'})do refusal(r,m,function()return Nodes.chooseTreasure(r,m,token,replay)end)end
  refusal(r,m,function()return Nodes.claimTreasure(r)end)
  assert(Run.obtainCard(r,'writhe'));eq(r.maxHp,max+(choice=='relic'and 6 or 0));eq(r.hp,hp+(choice=='relic'and 6 or 0))
  eq(r.keys.ruby,false);eq(r.keys.emerald,false)
 end
end)

test('destination49 gold fallback has neither Darkstone nor a synthesized Sapphire choice',function()
 local r,m=chest(49);eq(r.nodeFlow.reward.relicId,nil);eq(r.nodeFlow.reward.sapphireKey,nil)
 assert(not Nodes.treasureSource(r,m));local gold,slots=r.gold,#r.relics
 refusal(r,m,function()return Nodes.chooseTreasure(r,m,{},'sapphire')end)
 assert(Nodes.claimTreasure(r));eq(r.gold,gold+Data.rules.rewards.normalGold);eq(#r.relics,slots)
 assert(not r.keys.sapphire and not r.keys.ruby and not r.keys.emerald)
 refusal(r,m,function()return Nodes.claimTreasure(r)end)
end)
print('M3_V2_KEYS_DARKSTONE '..count..' passed')
