-- Fixed ApplyPower/Damage/GainBlock method-chain expectations; no original RNG claim.
package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local C=require("abyss_combat")
local Run=require("abyss_run")
local Data=require("abyss_data")
local count,failed=0,0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn)
 count=count+1;local ok,err=pcall(fn);if not ok then failed=failed+1 end
 print((ok and "ok " or "not ok ")..count.." - "..name..(ok and "" or ": "..tostring(err)))
end
local function battle(ids,card) return C.new(Data,{enemies=ids,deck={card or "defend"},seed=42}) end
local function intent(e,id)
 for i,v in ipairs(e.intents) do if v.id==id then e.intentIndex=i;return end end
 error("missing fixture intent "..id)
end
local function statusEvent(s,source,id)
 for i,event in ipairs(s.events) do
  if event.kind=="status" and event.detail.source==source and event.detail.status==id and event.detail.amount>0 then return event,i end
 end
end
local rows={{"fat_gremlin","fat_gremlin_1","weak",1,4},
 {"blue_slaver","blue_slaver_2","weak",1,7},{"gremlin_nob","gremlin_nob_2","vulnerable",2,6}}

test("real gremlin_gang retains Fat's queued Weak after lethal Thorns",function()
 local run=Run.new(Data,42);run.floor=5;assert(Run.startCombat(run,"gremlin_gang"))
 local s=run.combat;local fat
 for _,e in ipairs(s.enemies) do if e.definitionId=="fat_gremlin" then fat=e end end
 assert(fat);eq(#s.enemies,5);fat.hp=1;C.addStatus(s.player,"thorns",1);s.events={}
 assert(Run.endTurn(run));eq(fat.hp,0);eq(s.player.statuses.weak,1)
 local weak,index=statusEvent(s,fat.id,"weak");assert(weak,"Fat must still apply Weak")
 local retaliation,damage
 for i,event in ipairs(s.events) do
  if event.kind=="status_damage" and event.detail.target==fat.id then retaliation=i end
  if event.kind=="damage" and event.detail.source==fat.id then damage=i;eq(event.detail.amount,4) end
 end
 assert(damage and retaliation and damage<retaliation and retaliation<index)
 for _,e in ipairs(weak.frame.enemies) do if e.id==fat.id then eq(e.hp,0) end end
 eq(weak.detail.target,"player");eq(run.phase,"combat")
end)
for _,row in ipairs(rows) do
 test(row[1].." applies its queued status to live player after source death",function()
  local s=battle({row[1],"cultist"});local e=s.enemies[1]
  intent(e,row[2]);e.hp=1;C.addStatus(s.player,"thorns",1);s.events={}
  assert(C.endTurn(s));eq(e.hp,0);eq(s.player.hp,80-row[5]);eq(s.player.statuses[row[3]],row[4])
  assert(statusEvent(s,e.id,row[3]));eq(s.enemies[2].statuses.ritual,3);eq(C.intent(s,1),nil)
 end)
 test(row[1].." last-enemy death clears queued status",function()
  local s=battle({row[1]});local e=s.enemies[1]
  intent(e,row[2]);e.hp=1;C.addStatus(s.player,"thorns",1);s.events={}
  assert(C.endTurn(s));eq(s.phase,"victory");eq(s.player.statuses[row[3]] or 0,0)
  eq(statusEvent(s,e.id,row[3]),nil)
 end)
 test(row[1].." poison death before action never queues the status",function()
  local s=battle({row[1],"cultist"});local e=s.enemies[1]
  intent(e,row[2]);C.addStatus(e,"poison",100)
  assert(C.endTurn(s));eq(e.hp,0);eq(s.player.hp,80);eq(s.player.statuses[row[3]] or 0,0)
 end)
end
test("dead Nob's queued Vulnerable modifies the next living Blue attack",function()
 local s=battle({"gremlin_nob","blue_slaver"});local nob=s.enemies[1]
 intent(nob,"gremlin_nob_2");intent(s.enemies[2],"blue_slaver_1")
 nob.hp=1;C.addStatus(s.player,"thorns",1)
 assert(C.endTurn(s));eq(nob.hp,0);eq(s.player.hp,56,"6 + floor(12*1.5)")
 eq(s.player.statuses.vulnerable,2)
end)
test("dead Fat's queued Weak affects the next real Strike and expires without reapplication",function()
 local s=battle({"fat_gremlin","cultist"},"strike");local e=s.enemies[1]
 e.hp=1;C.addStatus(s.player,"thorns",1);assert(C.endTurn(s));eq(s.player.statuses.weak,1)
 local before=s.enemies[2].hp;assert(C.play(s,s.hand[1].uid,2));eq(before-s.enemies[2].hp,4)
 assert(C.endTurn(s));eq(s.player.statuses.weak,0);eq(e.hp,0);eq(s.player.hp,70)
end)
test("queued status precedes the dead Blue's already queued RollMove",function()
 local s=battle({"blue_slaver","cultist"});local e=s.enemies[1]
 intent(e,"blue_slaver_2");e.hp=1;C.addStatus(s.player,"thorns",1)
 local old=C.random;local countRoll=0
 C.random=function(state,n)
  countRoll=countRoll+1;eq(state.player.statuses.weak,1,"ApplyPower must precede RollMove")
  return old(state,n)
 end
 local ok,err=pcall(C.endTurn,s);C.random=old;assert(ok,err);eq(countRoll,1)
end)
test("dead queued source skips extra damage hits block and self status but keeps target status",function()
 local s=battle({"fat_gremlin","cultist"});local e=s.enemies[1]
 e.intents[1].effects={{op="damage",value=4,times=3},{op="block",value=99},
  {op="damage",value=99},{op="gainStatus",status="regen",value=99},{op="applyStatus",status="weak",value=1}}
 e.hp=1;C.addStatus(e,"regen",3);C.addStatus(s.player,"thorns",1)
 assert(C.endTurn(s));eq(e.hp,0);eq(s.player.hp,76);eq(e.block,0);eq(e.statuses.regen,3)
 eq(s.player.statuses.weak,1)
end)
test("unverified applyStatusAll is not enabled by source death",function()
 local s=battle({"fat_gremlin","cultist"});local e=s.enemies[1]
 table.insert(e.intents[1].effects,2,{op="applyStatusAll",status="weak",value=5})
 e.hp=1;C.addStatus(s.player,"thorns",1)
 assert(C.endTurn(s));eq(s.player.statuses.weak,1)
end)
test("a dead target never receives queued status even with living enemy teammate",function()
 local s=battle({"fat_gremlin","cultist"});local e=s.enemies[1]
 e.hp=1;s.player.hp=1;C.addStatus(s.player,"thorns",1);s.events={}
 assert(C.endTurn(s));eq(s.phase,"defeat");eq(s.player.hp,0);eq(s.player.statuses.weak or 0,0)
 eq(statusEvent(s,e.id,"weak"),nil)
end)
test("public applyEffects retains source-death protection even in enemy phase",function()
 local s=battle({"fat_gremlin","cultist"});s.enemies[1].hp=0;s.phase="enemy"
 C.applyEffects(s,{{op="applyStatus",status="weak",value=1}},s.enemies[1],s.player)
 eq(pcall(C.applyEffects,s,{false},s.enemies[1],s.player),true,"ordinary dead-source guard precedes payload access")
 eq(s.player.statuses.weak or 0,0)
end)
test("a player Bash killed by Thorns never applies its later Vulnerable",function()
 local s=battle({"fat_gremlin","cultist"},"bash");local e=s.enemies[1]
 s.player.hp=1;C.addStatus(e,"thorns",1)
 assert(C.play(s,s.hand[1].uid,1));eq(s.phase,"defeat");eq(s.player.hp,0);eq(e.statuses.vulnerable or 0,0)
end)
test("failed player transaction after queued enemy status preserves references and guard context",function()
 local s=battle({"fat_gremlin","cultist"});local e=s.enemies[1]
 e.hp=1;C.addStatus(s.player,"thorns",1);assert(C.endTurn(s));eq(s.player.statuses.weak,1)
 s.catalog.cards.defend.effects={{op="block",value=5},{op="gainStatus",status="missing",value=1}}
 local p,statuses,hand,events=s.player,s.player.statuses,s.hand,s.events
 local energy,block,n,seed=s.energy,p.block,#s.events,s.seed
 eq(pcall(C.play,s,s.hand[1].uid),false)
 eq(s.player,p);eq(p.statuses,statuses);eq(s.hand,hand);eq(s.events,events)
 eq(s.energy,energy);eq(p.block,block);eq(#s.events,n);eq(s.seed,seed)
 eq(s.resolvingEffects,nil);eq(s.queuedEnemyAction,nil);eq(s.player.statuses.weak,1)
end)
test("invalid queued operation is not silently hidden by source death",function()
 local s=battle({"fat_gremlin","cultist"});local e=s.enemies[1]
 e.hp=1;C.addStatus(s.player,"thorns",1);e.intents[1].effects[#e.intents[1].effects+1]={op="unknown_queued",value=1}
 local ok,err=pcall(C.endTurn,s);eq(ok,false);assert(tostring(err):find("unsupported effect",1,true))
 eq(s.resolvingEffects,nil)
end)
assert(failed==0,tostring(failed).." failed of "..count)
print("queued enemy status: "..count.." passed")
