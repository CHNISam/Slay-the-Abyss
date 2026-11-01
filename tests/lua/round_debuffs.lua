-- Fixed fc379c8 method-body expectations, not a certified original-PC run.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local C = require("abyss_combat")
local A = require("abyss_actor")
local data = require("abyss_data")
local count, failed = 0, 0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn)
 count=count+1; local ok,err=pcall(fn); if not ok then failed=failed+1 end
 print((ok and "ok " or "not ok ")..count.." - "..name..(ok and "" or ": "..tostring(err)))
end
local function battle(n)
 local enemies={}; for i=1,n or 1 do enemies[i]="jaw_worm" end
 local s=C.new(data,{enemies=enemies,deck={"strike"},seed=42})
 for _,e in ipairs(s.enemies) do e.ai=nil; e.intents={{id="fixture_hit",kind="attack",effects={{op="damage",value=10}}}}; e.intentIndex=1 end
 return s
end
for _,id in ipairs({"weak","vulnerable","frail"}) do
 test(id.." does not decay at owner end, only at shared round boundary",function()
  local s=battle(); C.addStatus(s.player,id,2); C.addStatus(s.enemies[1],id,2)
  A.endTurn(s,s.player); A.endTurn(s,s.enemies[1])
  eq(s.player.statuses[id],2); eq(s.enemies[1].statuses[id],2)
  assert(C.endTurn(s)); eq(s.player.statuses[id],1); eq(s.enemies[1].statuses[id],1)
 end)
 test(id.." new monster application skips one round but stacking never refreshes skip",function()
  local s=battle(); local e=s.enemies[1]
  e.intents={{id="fixture_debuff",kind="debuff",effects={{op="applyStatus",status=id,value=2}}}}
  assert(C.endTurn(s)); eq(s.player.statuses[id],2)
  assert(C.endTurn(s)); eq(s.player.statuses[id],3)
  e.intents={{id="fixture_hit",kind="attack",effects={{op="damage",value=0}}}}
  assert(C.endTurn(s)); eq(s.player.statuses[id],2)
 end)
 test(id.." all enemy actions precede player then enemy duration decay",function()
  local s=battle(2); C.addStatus(s.player,id,1); C.addStatus(s.enemies[1],id,1)
  s.events={}; assert(C.endTurn(s)); local lastHit,playerTick,enemyTick
  for i,event in ipairs(s.events) do
   if event.kind=="damage" then lastHit=i end
   if event.kind=="status" and event.detail.status==id and event.detail.amount==-1 then
    if event.detail.target=="player" then playerTick=i else enemyTick=i end
   end
  end
  assert(lastHit and playerTick and enemyTick); assert(lastHit<playerTick and playerTick<enemyTick)
 end)
end
test("one Vulnerable lasts through both enemy attacks",function()
 local s=battle(2); C.addStatus(s.player,"vulnerable",1)
 assert(C.endTurn(s)); eq(s.player.hp,50); eq(s.player.statuses.vulnerable,0)
end)
test("new enemy Weak applies during its attack and decays afterwards",function()
 local s=battle(); C.applyEffects(s,{{op="applyStatus",status="weak",value=1}},s.player,s.enemies[1])
 assert(C.endTurn(s)); eq(s.player.hp,73); eq(s.enemies[1].statuses.weak,0)
end)
test("monster-source Weak and Frail skip even when applied during player phase",function()
 for _,id in ipairs({"weak","frail"}) do
  local s=battle(); C.applyEffects(s,{{op="applyStatus",status=id,value=1}},s.enemies[1],s.player)
  assert(C.endTurn(s)); eq(s.player.statuses[id],1)
  assert(C.endTurn(s)); eq(s.player.statuses[id],0)
 end
end)
test("monster-source Vulnerable in player phase does not skip",function()
 local s=battle(); C.applyEffects(s,{{op="applyStatus",status="vulnerable",value=1}},s.enemies[1],s.player)
 assert(C.endTurn(s)); eq(s.player.hp,65); eq(s.player.statuses.vulnerable,0)
end)
test("recreated Weak receives fresh skip after expiration",function()
 local s=battle(); local e=s.enemies[1]
 C.addStatus(s.player,"weak",1); assert(C.endTurn(s)); eq(s.player.statuses.weak,0)
 e.intents={{id="fixture_debuff",kind="debuff",effects={{op="applyStatus",status="weak",value=1}}}}
 assert(C.endTurn(s)); eq(s.player.statuses.weak,1)
end)
test("death before round boundary does not fabricate duration ticks",function()
 local s=battle(); C.addStatus(s.player,"weak",1); C.addStatus(s.enemies[1],"poison",100)
 assert(C.endTurn(s)); eq(s.phase,"victory"); eq(s.player.statuses.weak,1)
end)
test("failed card restores duration and new first-application bookkeeping in place",function()
 local s=battle(); local e=s.enemies[1]; local statuses,events,hand=e.statuses,s.events,s.hand
 local before=C.copy(s)
 s.catalog.cards.strike.effects={{op="applyStatus",status="weak",value=1},{op="applyStatus",status="poison",value=-1}}
 eq(pcall(C.play,s,s.hand[1].uid,1),false)
 eq(e.statuses,statuses); eq(s.events,events); eq(s.hand,hand)
 eq(e.statuses.weak,nil); eq(e.weakJustApplied,nil); eq(s.energy,before.energy)
 eq(#s.events,#before.events); eq(#s.hand,#before.hand)
end)
test("dead actor skips duration and skip bookkeeping while living teammate completes round",function()
 local s=battle(2); local e=s.enemies[1]
 C.applyEffects(s,{{op="applyStatus",status="weak",value=2}},e,e)
 eq(e.weakJustApplied,true); e.hp=0; s.events={}
 assert(C.endTurn(s)); eq(e.statuses.weak,2); eq(e.weakJustApplied,true)
 for _,event in ipairs(s.events) do
  assert(not(event.kind=="status" and event.detail.target==e.id),"dead actor must not receive a duration tick")
 end
 eq(s.player.hp,70)
end)
assert(failed==0,tostring(failed).." round debuff failures")
print("round debuffs: "..count.." passed")
