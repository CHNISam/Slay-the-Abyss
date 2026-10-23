-- Fixed-source queue interpretation; controlled draws are inputs, not STS seeds.
package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local C=require("abyss_combat")
local Data=require("abyss_data")
local count,failed=0,0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn)
 count=count+1;local ok,err=pcall(fn);if not ok then failed=failed+1 end
 print((ok and "ok " or "not ok ")..count.." - "..name..(ok and "" or ": "..tostring(err)))
end
local function battle(ids) return C.new(Data,{enemies=ids,deck={"defend"},seed=42}) end
local function setIntent(enemy,id)
 for i,intent in ipairs(enemy.intents) do if intent.id==id then enemy.intentIndex=i;return end end
 error("missing fixture intent "..id)
end
local function draws(state,fn,values)
 local old=C.random;local calls={}
 C.random=function(s,n)
  eq(s,state,"RNG receives the live combat state")
  calls[#calls+1]={maximum=n,events=#s.events,playerHp=s.player.hp}
  -- Zero primary and conditional fraction are fixed test inputs.
  return values and values[#calls] or 1
 end
 local ok,err=pcall(fn,calls);C.random=old;assert(ok,err)
end
local function eventIndex(state,kind,source)
 for i,event in ipairs(state.events) do
  if event.kind==kind and (event.detail.source==source or event.detail.enemy==source) then return i end
 end
 error("missing event "..kind.." / "..source)
end

for _,row in ipairs({{"blue_slaver","blue_slaver_1",12},{"gremlin_nob","gremlin_nob_3",14},
 {"jaw_worm","jaw_worm_1",11},{"spike_slime_s","spike_slime_s_1",5},{"fat_gremlin","fat_gremlin_1",4}}) do
 test(row[1].." queued roll survives lethal Thorns while a teammate is alive",function()
  local s=battle({row[1],"cultist"});local e=s.enemies[1]
  setIntent(e,row[2]);e.hp=1;C.addStatus(s.player,"thorns",1);s.events={}
  draws(s,function(calls)
   assert(C.endTurn(s));eq(e.hp,0);eq(s.player.hp,80-row[3]);eq(s.phase,"player")
   eq(calls[1] and calls[1].maximum,100,"already queued main roll")
   local teammate=eventIndex(s,"intent",s.enemies[2].id)
   local thorns=eventIndex(s,"status_damage",s.player.id)
   assert(thorns<=calls[1].events and calls[1].events<teammate,"roll must follow Thorns and precede teammate")
   eq(s.enemies[2].statuses.ritual,3)
  end)
 end)
 test(row[1].." last-enemy death clears its queued roll",function()
  local s=battle({row[1]});local e=s.enemies[1]
  setIntent(e,row[2]);e.hp=1;C.addStatus(s.player,"thorns",1)
  local intent=e.intentIndex
  draws(s,function(calls)
   assert(C.endTurn(s));eq(s.phase,"victory");eq(#calls,0);eq(e.intentIndex,intent)
  end)
 end)
 test(row[1].." poison death before acting never queues a roll",function()
  local s=battle({row[1],"cultist"});local e=s.enemies[1]
  setIntent(e,row[2]);local intent=e.intentIndex;C.addStatus(e,"poison",100)
  draws(s,function(calls)
   assert(C.endTurn(s));eq(e.hp,0);eq(s.player.hp,80);eq(#calls,0);eq(e.intentIndex,intent)
   eq(s.enemies[2].statuses.ritual,3)
  end)
 end)
end
test("dead Jaw's Chomp history still requests the conditional fraction after primary zero",function()
 local s=battle({"jaw_worm","cultist"});local e=s.enemies[1]
 e.hp=1;C.addStatus(s.player,"thorns",1)
 draws(s,function(calls)
  assert(C.endTurn(s));eq(e.hp,0);eq(#calls,2);eq(calls[1].maximum,100);eq(calls[2].maximum,65536)
  eq(e.jawLast,"jaw_worm_1");eq(e.intents[e.intentIndex].id,"jaw_worm_3")
  eq(C.intent(s,1),nil,"a rolled dead enemy is still not actionable")
 end)
end)
test("dead random actor cannot regenerate or decay owner-end status while its queued roll runs",function()
 local s=battle({"blue_slaver","cultist"});local e=s.enemies[1]
 setIntent(e,"blue_slaver_1");e.hp=1;C.addStatus(e,"regen",3);C.addTemporaryStrength(e,2);C.addStatus(s.player,"thorns",1)
 draws(s,function(calls)
  assert(C.endTurn(s));eq(e.hp,0);eq(e.statuses.regen,3);eq(e.temporaryStrength,2);eq(#calls,1)
 end)
end)
test("Acid S has no queued RollMove and gains no extra random draw after Thorns",function()
 local s=battle({"acid_slime_s","cultist"});local e=s.enemies[1]
 setIntent(e,"acid_slime_s_1");e.hp=1;C.addStatus(s.player,"thorns",1)
 draws(s,function(calls) assert(C.endTurn(s));eq(e.hp,0);eq(#calls,0);eq(s.enemies[2].statuses.ritual,3) end)
end)
test("dead owner's queued draw precedes and changes the surviving Blue's next choice",function()
 local s=battle({"blue_slaver","blue_slaver"});local first,second=s.enemies[1],s.enemies[2]
 setIntent(first,"blue_slaver_1");setIntent(second,"blue_slaver_1")
 first.hp=1;C.addStatus(s.player,"thorns",1)
 draws(s,function(calls)
  assert(C.endTurn(s));eq(first.hp,0);assert(second.hp>0);eq(#calls,2)
  eq(calls[1].maximum,100);eq(calls[2].maximum,100)
  eq(first.intents[first.intentIndex].id,"blue_slaver_2")
  eq(C.intent(s,2).id,"blue_slaver_1","survivor receives second primary 99, not first primary 0")
 end,{1,100})
end)
test("a dead owner cannot act or consume another queued roll on later turns",function()
 local s=battle({"blue_slaver","cultist"});local e=s.enemies[1]
 setIntent(e,"blue_slaver_1");e.hp=1;C.addStatus(s.player,"thorns",1)
 draws(s,function(calls)
  assert(C.endTurn(s));eq(#calls,1);s.events={}
  assert(C.endTurn(s));eq(#calls,1);eq(s.player.hp,62);eq(C.intent(s,1),nil)
  for _,event in ipairs(s.events) do assert(event.kind~="intent" or event.detail.enemy~=e.id) end
 end)
end)
test("a rejected player card leaves queued-roll owner history and event state untouched",function()
 local s=battle({"blue_slaver","cultist"});local e=s.enemies[1]
 setIntent(e,"blue_slaver_1");e.hp=1;C.addStatus(s.player,"thorns",1);assert(C.endTurn(s))
 eq(e.blueLast,"blue_slaver_1")
 local actor,statuses,events,hand=e,e.statuses,s.events,s.hand
 local before=C.copy(s)
 s.catalog.cards.defend.effects={{op="draw",value=1},{op="gainStatus",status="missing",value=1}}
 eq(pcall(C.play,s,s.hand[1].uid,1),false)
 eq(s.enemies[1],actor);eq(e.statuses,statuses);eq(s.events,events);eq(s.hand,hand)
 eq(e.intentIndex,before.enemies[1].intentIndex);eq(e.blueLast,before.enemies[1].blueLast)
 eq(e.bluePrevious,before.enemies[1].bluePrevious);eq(s.seed,before.seed);eq(#s.events,#before.events)
end)
assert(failed==0,tostring(failed).." failed of "..count)
print("queued enemy rolls: "..count.." passed")
