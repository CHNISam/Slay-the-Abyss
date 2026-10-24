-- Mad Gremlin A0: passive Angry, never a replacement buff turn.
package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local C, Run, data = require("abyss_combat"), require("abyss_run"), require("abyss_data")
local passed, failed = 0, 0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn)
 local ok,err=pcall(fn); if ok then passed=passed+1 else failed=failed+1 end
 print((ok and "PASS " or "FAIL ")..name..(ok and "" or ": "..tostring(err)))
end
local function battle(deck,enemies,seed)
 return C.new(data,{seed=seed or 42,deck=deck or {"defend"},enemies=enemies or {"mad_gremlin"}})
end
local function strength(e) return e.statuses.strength or 0 end
local function play(s,id,target)
 for _,c in ipairs(s.hand) do if c.cardId==id then assert(C.play(s,c.uid,target or 1)); return end end
 error("missing card "..id)
end
local function observe(fn,endpoint)
 local original,calls=C.random,{}
 C.random=function(s,range) calls[#calls+1]=range; local n=original(s,range); return range==100 and endpoint~=nil and endpoint+1 or n end
 local ok,err=pcall(fn,calls);C.random=original;assert(ok,err)
end
local function ranges(calls,want)
 eq(#calls,#want,"random request count");for i,n in ipairs(want) do eq(calls[i],n,"random range "..i) end
end
local function statusEvents(s,start)
 local out={};for i=start or 1,#s.events do local e=s.events[i];if e.kind=="status" and e.detail.status=="strength" then out[#out+1]=e.detail end end;return out
end

for _,endpoint in ipairs({0,99}) do test("opening roll endpoint "..endpoint.." grants Angry1 and keeps attack4",function()
 observe(function(calls)
  local s=battle();ranges(calls,{5,100});eq(s.seed,42944);eq(s.enemies[1].hp,24);eq(s.enemies[1].maxHp,24)
  eq(s.enemies[1].statuses.angry,1);eq(C.intent(s,1).id,"mad_gremlin_1");eq(C.intent(s,1).effects[1].value,4)
 end,endpoint)
end) end

test("HP samples cover each integer 20 through 24",function()
 local seen={};for seed=1,64 do local e=battle(nil,nil,seed).enemies[1];assert(e.hp>=20 and e.hp<=24);eq(e.hp,e.maxHp);seen[e.hp]=true end
 for hp=20,24 do assert(seen[hp],"missing HP "..hp) end
end)
test("every ordinary turn attacks without spontaneous strength or AI rolls",function()
 observe(function(calls)
  local s=battle();local count=#calls
  for turn=1,5 do assert(C.endTurn(s));eq(s.player.hp,80-4*turn);eq(strength(s.enemies[1]),0);eq(C.intent(s,1).id,"mad_gremlin_1");eq(#calls,count) end
 end)
end)
test("opening HP and AI precede four-card shuffle",function()
 observe(function(calls) local s=battle({"strike","defend","bash","anger"});ranges(calls,{5,100,4,3,2});eq(s.seed,50871) end)
end)
test("Strike causes one reactive Strength and next attack is five",function()
 local s=battle({"strike"});local e=s.enemies[1];local hp=e.hp;play(s,"strike");eq(e.hp,hp-6);eq(strength(e),1)
 assert(C.endTurn(s));eq(s.player.hp,75);eq(strength(e),1)
end)
test("fully blocked and zero normal damage do not trigger",function()
 local s=battle();local e=s.enemies[1];e.block=6
 eq(C.damage(s,s.player,e,6),0);eq(strength(e),0);eq(C.damage(s,s.player,e,0),0);eq(strength(e),0)
end)
test("one HP through partial block triggers one",function()
 local s=battle({"strike"});local e=s.enemies[1];e.block=5;local hp=e.hp;play(s,"strike");eq(e.hp,hp-1);eq(strength(e),1)
end)
test("Twin Strike grants one Strength after each unblocked hit",function()
 local s=battle({"twin_strike"});local e=s.enemies[1];local hp=e.hp;local start=#s.events+1;play(s,"twin_strike")
 eq(e.hp,hp-10);eq(strength(e),2);local events=statusEvents(s,start);eq(#events,2);eq(events[1].amount,1);eq(events[2].amount,1)
 local sequence={};for i=start,#s.events do local x=s.events[i];if x.kind=="damage" then sequence[#sequence+1]="damage" elseif x.kind=="status" and x.detail.status=="strength" then sequence[#sequence+1]="angry" end end
 eq(table.concat(sequence,","),"damage,angry,damage,angry")
end)
test("Twin Strike consumes block before deciding each trigger",function()
 local s=battle({"twin_strike"});local e=s.enemies[1];e.block=6;local hp=e.hp;play(s,"twin_strike");eq(e.hp,hp-4);eq(strength(e),1)
end)
test("Body Slam is normal damage and triggers Angry",function()
 local s=battle({"body_slam"});s.player.block=3;play(s,"body_slam");eq(strength(s.enemies[1]),1);eq(s.player.block,3)
end)
test("poison tick never grants Angry",function()
 local s=battle();local e=s.enemies[1];local hp=e.hp;C.addStatus(e,"poison",2);assert(C.endTurn(s));eq(e.hp,hp-2);eq(strength(e),0);eq(s.player.hp,76)
end)
test("retaliation damage never grants Angry",function()
 local s=battle();local e=s.enemies[1];local hp=e.hp;C.addStatus(s.player,"thorns",3);assert(C.endTurn(s));eq(e.hp,hp-3);eq(strength(e),0)
end)
test("real Fire Potion hits but does not trigger Angry",function()
 local run=Run.new(data,42);run.floor=5;run.potions={"fire_potion"};assert(Run.startCombat(run,"gremlin_gang"))
 local e=run.combat.enemies[1];local hp=e.hp;assert(Run.usePotion(run,1,1));e=run.combat.enemies[1]
 eq(e.hp,math.max(0,hp-20));eq(strength(e),0);eq(#run.potions,0)
end)
test("lethal attack does not apply pending Strength to dead target",function()
 local s=battle({"strike"},{"mad_gremlin","sneaky_gremlin"});local e=s.enemies[1];e.hp=6;local start=#s.events+1
 play(s,"strike");eq(e.hp,0);eq(strength(e),0);eq(#statusEvents(s,start),0);eq(s.phase,"player")
end)
test("last enemy kill completes victory without a Strength application",function()
 local s=battle({"strike"});local e=s.enemies[1];e.hp=6;play(s,"strike");eq(s.phase,"victory");eq(strength(e),0)
end)
test("area hits finish before reverse-queued Angry applies",function()
 local s=battle({"cleave"},{"mad_gremlin","mad_gremlin"});local start=#s.events+1;play(s,"cleave")
 eq(strength(s.enemies[1]),1);eq(strength(s.enemies[2]),1)
 local seq={};for i=start,#s.events do local e=s.events[i];if e.kind=="damage" then seq[#seq+1]="damage:"..e.detail.target elseif e.kind=="status" and e.detail.status=="strength" then seq[#seq+1]="angry:"..e.detail.target end end
 eq(table.concat(seq,","),"damage:mad_gremlin_1,damage:mad_gremlin_2,angry:mad_gremlin_2,angry:mad_gremlin_1")
end)
test("area sibling death cancels only its own pending Strength",function()
 local s=battle({"cleave"},{"mad_gremlin","mad_gremlin"});s.enemies[2].hp=8;play(s,"cleave")
 eq(strength(s.enemies[1]),1);eq(strength(s.enemies[2]),0);eq(s.enemies[2].hp,0)
end)
test("area final wipe gives no Strength to either dead target",function()
 local s=battle({"cleave"},{"mad_gremlin","mad_gremlin"});for _,e in ipairs(s.enemies) do e.hp=8 end;play(s,"cleave")
 eq(s.phase,"victory");eq(strength(s.enemies[1]),0);eq(strength(s.enemies[2]),0)
end)
test("Thunderclap Angry executes before queued Vulnerable",function()
 local s=battle({"thunderclap"},{"mad_gremlin","mad_gremlin"});local start=#s.events+1;play(s,"thunderclap")
 local seq={};for i=start,#s.events do local e=s.events[i];if e.kind=="status" then seq[#seq+1]=e.detail.status..":"..e.detail.target end end
 eq(table.concat(seq,","),"strength:mad_gremlin_2,strength:mad_gremlin_1,vulnerable:mad_gremlin_1,vulnerable:mad_gremlin_2")
end)
test("positive reactive Strength does not spend Artifact at negative existing Strength",function()
 local s=battle({"strike"});local e=s.enemies[1];C.addStatus(e,"artifact",1);C.addStatus(e,"strength",-3);play(s,"strike")
 eq(strength(e),-2);eq(e.statuses.artifact,1)
end)
test("reactive Strength respects existing 999 cap",function()
 local s=battle({"strike"});local e=s.enemies[1];C.addStatus(e,"strength",999);play(s,"strike");eq(strength(e),999)
end)
test("failed card restores Angry reaction, HP, seed and table identity",function()
 local s=battle({"strike"});local e=s.enemies[1];local hp,seed,events,stacks=e.hp,s.seed,s.events,e.statuses
 s.catalog.cards.strike.effects={{op="damage",value=6},{op="gainStatus",status="thorns",value=2147483647}};C.addStatus(s.player,"thorns",1)
 local before=#s.events;eq(pcall(C.play,s,s.hand[1].uid,1),false);eq(s.enemies[1],e);eq(e.statuses,stacks);eq(e.hp,hp);eq(strength(e),0);eq(s.seed,seed);eq(s.events,events);eq(#s.events,before)
end)
test("preview and invalid target do not trigger or draw",function()
 observe(function(calls)
  local s=battle({"strike"});local n=#calls;local e=s.enemies[1];for _=1,3 do local v=C.statusView(e);for _,x in ipairs(v) do x.amount=99 end;C.intent(s,1);eq(C.play(s,s.hand[1].uid,99),false) end
  eq(#calls,n);eq(strength(e),0);eq(e.statuses.angry,1)
 end)
end)
test("real gang entry grants passive only to mad gremlin",function()
 local run=Run.new(data,42);run.floor=5;assert(Run.startCombat(run,"gremlin_gang"));local s=run.combat
 eq(s.enemies[1].definitionId,"mad_gremlin");eq(s.enemies[1].statuses.angry,1)
 for i=2,#s.enemies do eq(s.enemies[i].statuses.angry,nil) end
end)
print("mad gremlin: "..passed.." passed, "..failed.." failed");assert(failed==0,"Mad Gremlin regressions")
