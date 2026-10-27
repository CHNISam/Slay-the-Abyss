package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,R,AI,Data=require('abyss_combat'),require('abyss_sts_random'),require('abyss_enemy_ai'),require('abyss_data')
assert(type(C.prepareEncounter)=='function','EVENT_ENEMY_PREPARATION_MISSING: no constructor-only boundary')
local vectors=dofile('tests/fixtures/event-enemy-preparation-vectors.lua')
local count,failed=0,0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function same(a,b,path,seen)
 path=path or 'state';eq(type(a),type(b),path);if type(a)~='table'then eq(a,b,path);return end
 seen=seen or {};if seen[a]==b then return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],path..'.'..tostring(k),seen)end
 for k in pairs(b)do assert(a[k]~=nil,path..' unexpected '..tostring(k))end
end
local function test(name,fn)
 count=count+1;local ok,why=pcall(fn);if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))
end
local function streams(seed)
 local result={};for _,id in ipairs({'monsterHpRng','aiRng','shuffleRng','cardRandomRng','miscRng','visualRng'})do result[id]=R.fromSeed(seed)end
 return result
end
local function sphere(seed)
 seed=seed or '42';return {sourceEncounter='2 Orb Walkers',roomSeed=seed,roomStreams=streams(seed),
  encounterBoundary={misc={integer=function()error('Sphere must not consume misc')end,boolean=function()error('Sphere must not consume misc')end}}}
end
local function begin(options,prepared)
 local next={};for k,v in pairs(options)do next[k]=v end
 next.deck={'strike','defend','strike','defend','strike','defend','strike'}
 if prepared then next.enemies,next.sourceEncounter,next.encounterBoundary=nil,nil,nil end
 next.preparedEncounter=prepared;next.hp,next.maxHp,next.gold=70,80,123
 return C.new(Data,next)
end
test('Sphere constructs two physical actors with four HP draws and no other input changes',function()
 local options=sphere();local before=C.copy(options.roomStreams);local data=C.copy(Data)
 local prepared=C.prepareEncounter(Data,options)
 eq(prepared.roomSeed,'42');eq(prepared.sourceEncounter,'2 Orb Walkers');eq(#prepared.actors,2)
 local expected=R.fromSeed('42');for _=1,4 do R.randomIntBetween(expected,90,96)end
 same(prepared.monsterHpRng,R.snapshot(expected));same(options.roomStreams,before);same(Data,data)
 for i,e in ipairs(prepared.actors)do
  eq(e.definitionId,'orb_walker');eq(e.id,'orb_walker_'..i);eq(e.hp,e.maxHp);eq(e.block,0)
  eq(e.statuses.generic_strength_up,nil);eq(e.act3Last,nil)
  eq(e.sourcePosition.x,i==1 and -250 or 150);eq(e.sourcePosition.y,i==1 and 32 or 26)
 end
 for _,key in ipairs({'player','draw','hand','events','relicCounters','aiRng','shuffleRng'})do eq(prepared[key],nil,key)end
end)
test('preparation cannot call full Combat.new AI preBattle draw or turn setup',function()
 local oldNew,oldInit,oldPre,oldDraw,oldTurn=C.new,AI.initialize,AI.preBattle,C.draw,C.startPlayerTurn
 local function forbidden()error('PREPARATION_RAN_BATTLE_SETUP')end
 C.new,AI.initialize,AI.preBattle,C.draw,C.startPlayerTurn=forbidden,forbidden,forbidden,forbidden,forbidden
 local ok,prepared=pcall(C.prepareEncounter,Data,sphere())
 C.new,AI.initialize,AI.preBattle,C.draw,C.startPlayerTurn=oldNew,oldInit,oldPre,oldDraw,oldTurn
 assert(ok,prepared);eq(#prepared.actors,2)
end)
test('independent source constructor vectors pin both overwritten HP draws and final actors',function()
 for _,v in ipairs(vectors)do
  local prepared=C.prepareEncounter(Data,sphere(v.seed))
  eq(prepared.actors[1].hp,v.hp[1]);eq(prepared.actors[2].hp,v.hp[2]);same(prepared.monsterHpRng,v.after)
 end
end)
test('prepared start matches full ordinary setup while reusing HP and leaving its cache unchanged',function()
 local options=sphere();local prepared=C.prepareEncounter(Data,options);local cache=C.copy(prepared)
 local direct=begin(options);local actual=begin(options,prepared)
 same(actual,direct);same(prepared,cache)
 eq(actual.monsterHpRng.counter,4);eq(actual.aiRng.counter,2);eq(actual.turn,1);eq(#actual.hand,5)
 for _,e in ipairs(actual.enemies)do eq(e.statuses.generic_strength_up,3);assert(e.statusDefinitions==actual.catalog.statuses)end
 actual.enemies[1].hp=1;eq(prepared.actors[1].hp,cache.actors[1].hp)
end)
test('fight-time gold or relic work cannot rewind the newer misc owner',function()
 local options=sphere();local prepared=C.prepareEncounter(Data,options)
 R.randomIntBetween(options.roomStreams.miscRng,45,55)
 local expected=R.snapshot(options.roomStreams.miscRng)
 local battle=begin(options,prepared)
 same(R.snapshot(battle.miscRng),expected);eq(battle.miscRng.counter,1);eq(battle.monsterHpRng.counter,4)
end)
test('all MindBloom Boss constructors can prepare explicitly and enter the same unchanged opening',function()
 for _,id in ipairs({'guardian','hexaghost','slime_boss'})do
  local options={enemies={id},roomSeed='77',roomStreams=streams('77')}
  local prepared=C.prepareEncounter(Data,options);eq(prepared.enemyIds[1],id);eq(prepared.sourceEncounter,nil)
  same(begin(options,prepared),begin(options))
 end
end)
test('wrong room source explicit/formation mixtures and initialized caches are refused without mutation',function()
 local options=sphere();local prepared=C.prepareEncounter(Data,options);local before=C.copy(prepared)
 for _,change in ipairs({{roomSeed='43'},{sourceEncounter='3 Shapes'},{enemies={'cultist'}}})do
  local altered={};for k,v in pairs(options)do altered[k]=v end;for k,v in pairs(change)do altered[k]=v end
  altered.preparedEncounter=prepared
  if change.roomSeed then altered.enemies,altered.sourceEncounter,altered.encounterBoundary=nil,nil,nil end
  eq(pcall(C.new,Data,altered),false);same(prepared,before)
 end
 local poisoned=C.copy(prepared);poisoned.actors[1].statuses.strength=2
 eq(pcall(begin,options,poisoned),false);same(prepared,before)
 local explicit={enemies={'guardian'},roomSeed='42',roomStreams=streams('42')}
 local saved=C.prepareEncounter(Data,explicit);explicit.enemies={'hexaghost'}
 explicit.preparedEncounter=saved;eq(pcall(C.new,Data,explicit),false)
end)
test('constructor and late opening faults preserve all caller streams and prepared actors',function()
 local options=sphere();local before=C.copy(options.roomStreams);local original,calls=AI.prepare,0
 AI.prepare=function(...)calls=calls+1;original(...);if calls==2 then error('PREPARE_SECOND_ACTOR_FAULT')end end
 local ok,why=pcall(C.prepareEncounter,Data,options);AI.prepare=original
 eq(ok,false);assert(tostring(why):find('PREPARE_SECOND_ACTOR_FAULT',1,true));same(options.roomStreams,before)
 local prepared=C.prepareEncounter(Data,options);local cache=C.copy(prepared)
 options.beforeFirstTurn=function()return false,'OPENING_PREPARED_FAULT'end
 local battle,reason=begin(options,prepared);eq(battle,nil);eq(reason,'OPENING_PREPARED_FAULT')
 same(prepared,cache);same(options.roomStreams,before)
end)
test('constructor-created shared Void definition survives prepared Awakened adoption',function()
 local options={sourceEncounter='Awakened One',roomSeed='42',roomStreams=streams('42'),encounterBoundary={misc={}}}
 local prepared=C.prepareEncounter(Data,options)
 local battle=begin(options,prepared);assert(battle.catalog.cards.void);eq(#battle.enemies,3)
 same(battle,begin(options))
end)
print('EVENT_ENEMY_PREPARATION '..count..' groups; '..failed..' failed');assert(failed==0)
