local C,D,R,AI,A,G=require('abyss_combat'),require('abyss_data'),require('abyss_sts_random'),
 require('abyss_enemy_ai'),require('abyss_actor'),require('abyss_giant_head')
local count,failed=0,0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end
end
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function battle(seed,ids)
 local streams={seed=seed or '1'}
 for _,key in ipairs({'monsterHpRng','aiRng','cardRandomRng','shuffleRng'})do streams[key]=R.fromSeed(streams.seed)end
 return C.new(D,{enemies=ids or {'giant_head'},deck={},roomSeed=streams.seed,roomStreams=streams,maxHp=1000,hp=1000})
end
local function intent(e)return e.intents[e.intentIndex]end
local function primary(n)return function(_,maximum)eq(maximum,100);return n+1 end end
test('source constructor draws fixed HP once and installs a visible zero Slow Power',function()
 local s=battle();local e=s.enemies[1]
 eq(e.hp,500);eq(e.maxHp,500);eq(e.sourceId,'GiantHead');eq(e.tier,'elite')
 eq(s.monsterHpRng.counter,1);eq(s.aiRng.counter,1);eq(s.cardRandomRng.counter,0)
 eq(e.statuses.slow,0);eq(e.giantHeadCount,4);eq(e.powerOrder[1],'slow')
 eq(e.powerScheduleOrder[1].id,'slow');eq(e.powerScheduleSerial,1)
 local visible=false;for _,entry in ipairs(A.statusView(e))do if entry.id=='slow'then visible=true;eq(entry.amount,0)end end
 assert(visible);eq(D.enemies.enemies[#D.enemies.enemies].id~='giant_head',true)
end)
test('independent two-seed twelve-turn vectors lock actual attacks HP and both RNG states',function()
 local vectors=dofile('tests/fixtures/giant-head-vectors.lua')
 for _,v in ipairs(vectors.ai)do
  local s=battle(v.seed);local e=s.enemies[1];eq(e.hp,v.monsterHp)
  for _,step in ipairs(v.steps)do
   eq(intent(e).id,step.intent);eq(e.giantHeadCount,step.count)
   local hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp-step.damage);eq(s.player.hp,step.hpAfter)
   eq(e.statuses.slow,0)
  end
  eq(intent(e).id,v.nextIntent);eq(e.giantHeadCount,v.nextCount)
  same(R.snapshot(s.monsterHpRng),v.hpRng);same(R.snapshot(s.aiRng),v.aiRng)
 end
end)
test('49/50 split and both no-third-repeat branches consume their primary rolls',function()
 for _,n in ipairs({49,50})do
  local e=C.copy(G.enemy);local draws=0
  local random=function(_,maximum)eq(maximum,100);draws=draws+1;return n+1 end
  G.initialize({},e,random);local preferred=n==49 and 'glare'or 'count'
  eq(intent(e).id,preferred);G.advance({},e,random);eq(intent(e).id,preferred)
  G.advance({},e,random);assert(intent(e).id~=preferred)
  G.advance({},e,random);eq(intent(e).id,preferred);eq(draws,4);eq(e.giantHeadCount,1)
  G.advance({},e,random);eq(intent(e).id,'it_is_time');eq(intent(e).effects[1].value,30);eq(draws,5)
 end
end)
test('It Is Time begins fifth, ramps by five, caps at sixty and preserves old intent graphs',function()
 local e=C.copy(G.enemy);G.initialize({},e,primary(0))
 for _=1,3 do G.advance({},e,primary(0))end
 for i=1,10 do
  local old=C.copy(e.intents);local ref=e.intents
  G.advance({},e,primary(0));eq(intent(e).effects[1].value,math.min(60,25+i*5))
  same(ref,old);assert(e.intents~=ref)
 end
 eq(e.giantHeadCount,-6)
end)
test('Glare Weak is monster-sourced, spends Artifact and never adds a second turn',function()
 for _,artifact in ipairs({0,1})do
  local s=battle();local e=s.enemies[1];AI.initialize(s,e,primary(0))
  if artifact==1 then A.applyPower(s,s.player,'artifact',1,s.player)end
  assert(C.endTurn(s));eq(s.player.statuses.weak or 0,artifact==0 and 1 or 0)
  eq(s.player.statuses.artifact or 0,0);eq(e.giantHeadCount,3);eq(s.aiRng.counter,2)
 end
end)
test('ramp damage obeys Strength and Weak but not its own incoming Slow',function()
 local s=battle();local e=s.enemies[1]
 e.giantHeadCount=1;AI.advance(s,e,primary(0))
 A.applyPower(s,e,'strength',3,e);A.applyPower(s,e,'weak',1,s.player);A.applyPower(s,e,'slow',9,e)
 local hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp-24);eq(e.statuses.slow,0)
end)
test('queued RollMove survives lethal retaliation only while an ally remains',function()
 for _,ally in ipairs({false,true})do
  local s=battle('1',ally and {'giant_head','cultist'}or nil);local e=s.enemies[1]
  AI.initialize(s,e,primary(50));A.applyPower(s,s.player,'thorns',999,s.player)
  local old=s.aiRng.counter;assert(C.endTurn(s));eq(e.hp,0)
  eq(s.aiRng.counter,old+(ally and 2 or 0))
 end
end)
print('GIANT_HEAD_AI '..count..' groups; '..failed..' failed');assert(failed==0)
