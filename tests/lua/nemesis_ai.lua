local H=dofile('tests/lua/support/nemesis_fixture.lua')
local C,R,AI,A,N,eq,same=H.C,H.R,H.AI,H.A,H.N,H.eq,H.same
local count,failed=0,0
local function test(name,fn)local ok,why=pcall(fn);count=count+1;if not ok then failed=failed+1 end
 print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function primary(n)return function(_,max)eq(max,100);return n+1 end end
test('source fixed HP consumes one draw and no opening intangible or cosmetic gameplay draws',function()
 local s=H.battle();local e=s.enemies[1]
 eq(e.sourceId,'Nemesis');eq(e.tier,'elite');eq(e.hp,185);eq(e.maxHp,185)
 eq(e.sourcePosition.x,0);eq(e.sourcePosition.y,0)
 eq(s.monsterHpRng.counter,1);eq(s.aiRng.counter,1);eq(s.cardRandomRng.counter,0)
 eq(e.statuses.nemesis_intangible,nil);eq(e.nemesisCooldown,-1);eq(e.nemesisFirst,false)
end)
test('independent boundary oracle locks conditional Boolean draws cooldown and every history branch',function()
 local v=dofile('tests/fixtures/act3-nemesis-vectors.lua');eq(#v.boundaries,208)
 for _,row in ipairs(v.boundaries)do
  local e=C.copy(N.enemy);e.nemesisFirst=row.first;e.nemesisCooldown=row.cooldown
  e.nemesisLast=row.history[#row.history];e.nemesisPrevious=row.history[#row.history-1]
  local primaryCalls,booleans=0,0
  local random=function(_,max)
   if max==100 then primaryCalls=primaryCalls+1;return row.n+1 end
   eq(max,2);booleans=booleans+1;return row.boolean and 2 or 1
  end
  N.advance({},e,random);eq(H.intent(e),row.move);eq(e.nemesisCooldown,row.after)
  eq(e.nemesisFirst,false);eq(primaryCalls,1);eq(booleans,row.calls)
 end
end)
test('four independent twelve-action vectors lock real attacks alternation and full RNG words',function()
 local values=dofile('tests/fixtures/act3-nemesis-vectors.lua').vectors;eq(#values,4)
 for _,v in ipairs(values)do
  local deck={};for _=1,65 do deck[#deck+1]='strike'end
  local s=H.battle(v.seed,deck);local e=s.enemies[1];eq(e.hp,v.hp)
  for _,step in ipairs(v.steps)do
   eq(H.intent(e),step.intent);eq(e.nemesisCooldown,step.cooldown)
   local hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp-step.loss);eq(s.player.hp,step.health)
   eq(e.statuses.nemesis_intangible~=nil,step.intangibleAfter)
  end
  eq(H.intent(e),v.nextIntent);eq(e.nemesisCooldown,v.nextCooldown)
  same(R.snapshot(s.monsterHpRng),v.hpRng);same(R.snapshot(s.aiRng),v.aiRng)
  eq(s.cardRandomRng.counter,0)
 end
end)
test('three separate attacks use each hit block and actual retaliation cancellation',function()
 local s=H.battle();local e=H.force(s,'fire');s.player.block=8
 local hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp-10);eq(e.statuses.nemesis_intangible,1)
 for _,ally in ipairs({false,true})do
  s=H.battle('1',{},ally and {'nemesis','cultist'}or nil);e=H.force(s,'fire')
  A.applyPower(s,s.player,'thorns',999,s.player)
  hp=s.player.hp;local ai=s.aiRng.counter;assert(C.endTurn(s));eq(e.hp,0);eq(s.player.hp,hp-6)
  eq(e.statuses.nemesis_intangible,nil);eq(s.aiRng.counter,ai+(ally and 3 or 0))
 end
end)
test('Nemesis attacks retain source Strength Weak Vulnerable and target-only rules',function()
 local s=H.battle();local e=H.force(s,'fire')
 A.applyPower(s,e,'strength',3,e);A.applyPower(s,e,'weak',1,s.player)
 A.applyPower(s,s.player,'vulnerable',1,e)
 local hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp-30)
 s=H.battle();e=H.force(s,'scythe');hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp-45)
end)
print('NEMESIS_AI '..count..' groups; '..failed..' failed');assert(failed==0)
