-- Independent fixed SlaverRed/EntanglePower/AbstractCard A0 expectations.
package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local C=require("abyss_combat")
local A=require("abyss_actor")
local Run=require("abyss_run")
local Data=require("abyss_data")
local count,failed=0,0
local function eq(a,b,label) assert(a==b,(label or "value")..": "..tostring(a).." ~= "..tostring(b)) end
local function same(a,b)
 if type(a)~="table" then eq(a,b);return end
 for k,v in pairs(a) do same(v,b[k]) end
 for k in pairs(b) do assert(a[k]~=nil,"extra key "..tostring(k)) end
end
local function test(name,fn)
 count=count+1;local ok,err=pcall(fn);if not ok then failed=failed+1 end
 print((ok and "ok " or "not ok ")..count.." - "..name..(ok and "" or ": "..tostring(err)))
end
local function battle(ids,deck) return C.new(Data,{enemies=ids or {"red_slaver"},deck=deck or {"strike","defend","inflame"},seed=42}) end
local function force(e,id)
 for i,intent in ipairs(e.intents) do if intent.id==id then e.intentIndex=i;return end end;error("missing intent "..id)
end
local function uid(s,id) for _,card in ipairs(s.hand) do if card.cardId==id then return card.uid end end;error("missing hand "..id) end
local function roll(value,fn,expected)
 local original=C.random;local calls=0
 C.random=function(s,n) if n==100 then calls=calls+1;return value+1 end;return original(s,n) end
 local ok,err=pcall(fn);C.random=original;assert(ok,err);eq(calls,expected or 1,"main rolls")
end
local function move(s) return C.intent(s,1).id end
test("A0 HP inclusive endpoints and opening ignored roll are real initialization requests",function()
 for _,endpoint in ipairs({1,5}) do for _,opening in ipairs({1,100}) do
  local original=C.random;local requests={}
  C.random=function(s,n) requests[#requests+1]=n;if n==5 then return endpoint end;if n==100 then return opening end;return original(s,n) end
  local ok,s=pcall(battle,nil,{"defend"});C.random=original;assert(ok,s)
  eq(s.enemies[1].hp,45+endpoint);eq(s.enemies[1].maxHp,45+endpoint);eq(move(s),"red_slaver_1")
  eq(requests[1],5);eq(requests[2],100);eq(#requests,2);eq(s.enemies[1].redUsedEntangle,false)
 end end
end)
test("opening Stab deals exactly 13 and no power",function()
 local s=battle();roll(0,function() assert(C.endTurn(s)) end);eq(s.player.hp,67);eq(s.player.statuses.entangled or 0,0);eq(s.player.statuses.vulnerable or 0,0)
end)
for _,row in ipairs({{54,"red_slaver_3"},{55,"red_slaver_3"},{74,"red_slaver_3"},{75,"red_slaver_2"},{99,"red_slaver_2"}}) do
 test("before net use boundary "..row[1],function()
  local s=battle();roll(row[1],function() assert(C.endTurn(s)) end);eq(move(s),row[2]);eq(s.enemies[1].redUsedEntangle,false)
 end)
end
test("before net use two Scrapes force Stab unless net threshold takes priority",function()
 for _,row in ipairs({{74,"red_slaver_1"},{75,"red_slaver_2"}}) do
  local s=battle();local e=s.enemies[1];force(e,"red_slaver_3");e.redLast="red_slaver_3"
  roll(row[1],function() assert(C.endTurn(s)) end);eq(move(s),row[2])
 end
end)
for _,row in ipairs({{54,"red_slaver_3"},{55,"red_slaver_1"},{75,"red_slaver_1"},{99,"red_slaver_1"}}) do
 test("after net use boundary "..row[1],function()
  local s=battle();local e=s.enemies[1];e.redUsedEntangle=true;force(e,"red_slaver_3")
  roll(row[1],function() assert(C.endTurn(s)) end);eq(move(s),row[2])
 end)
end
test("after net use neither Stab nor Scrape can occur three consecutive times",function()
 for _,row in ipairs({{"red_slaver_1",99,"red_slaver_3"},{"red_slaver_3",0,"red_slaver_1"}}) do
  local s=battle();local e=s.enemies[1];e.redUsedEntangle=true;e.redLast=row[1];force(e,row[1])
  roll(row[2],function() assert(C.endTurn(s)) end);eq(move(s),row[3])
 end
end)
test("Scrape deals eight before applying Vulnerable one",function()
 local s=battle();force(s.enemies[1],"red_slaver_3");s.events={}
 roll(0,function() assert(C.endTurn(s)) end);eq(s.player.hp,72);eq(s.player.statuses.vulnerable,1)
 local damage,status
 for i,event in ipairs(s.events) do
  if event.kind=="damage" then damage=i;eq(event.detail.amount,8) end
  if event.kind=="status" and event.detail.status=="vulnerable" then status=i end
 end;assert(damage and status and damage<status)
end)
test("actual net survives monster round-end/player start and blocks only attacks",function()
 local s=battle();local e=s.enemies[1]
 roll(75,function() assert(C.endTurn(s)) end);eq(move(s),"red_slaver_2");eq(e.redUsedEntangle,false)
 roll(0,function() assert(C.endTurn(s)) end);eq(s.player.hp,67);eq(s.player.statuses.entangled,1);eq(e.redUsedEntangle,true)
 local before=C.copy(s);local ok,reason=C.play(s,uid(s,"strike"),1)
 eq(ok,false);eq(reason,"entangled");same(before,s)
 assert(C.play(s,uid(s,"defend")));eq(s.player.block,5)
 assert(C.play(s,uid(s,"inflame")));eq(s.player.statuses.strength,2)
end)
test("attack preflight rejects before unsupported payload target or energy checks",function()
 local s=battle();C.addStatus(s.player,"entangled",1);s.energy=0;s.catalog.cards.strike.effects={{op="not_enabled"}}
 local before=C.copy(s);local ok,reason=C.canPlay(s,uid(s,"strike"),999)
 eq(ok,false);eq(reason,"entangled");same(before,s)
end)
test("first player owner end removes the whole power without consuming Artifact",function()
 local s=battle();force(s.enemies[1],"red_slaver_2");roll(99,function() assert(C.endTurn(s)) end)
 C.addStatus(s.player,"entangled",1);C.addStatus(s.player,"artifact",1);s.events={}
 roll(0,function() assert(C.endTurn(s)) end);eq(s.player.statuses.entangled,0);eq(s.player.statuses.artifact,1)
 local removed,intent
 for i,event in ipairs(s.events) do
  if event.kind=="status" and event.detail.status=="entangled" then removed=i;eq(event.detail.amount,-2);eq(event.frame.player.statuses.artifact,1) end
  if event.kind=="intent" then intent=i end
 end
 assert(removed and intent and removed<intent);assert(C.canPlay(s,uid(s,"strike"),1))
end)
test("Entangle removal coexists with Flex debt while only the negative Strength spends Artifact",function()
 local s=battle();C.addStatus(s.player,"entangled",1);C.addTemporaryStrength(s.player,2);C.addStatus(s.player,"artifact",1);s.events={}
 A.endTurn(s,s.player);eq(s.player.statuses.entangled,0);eq(s.player.statuses.strength,2);eq(s.player.temporaryStrength,0);eq(s.player.statuses.artifact,0)
 local removals,blocked=0,0
 for _,event in ipairs(s.events) do
  if event.detail.status=="entangled" then removals=removals+1;eq(event.detail.amount,-1);eq(event.frame.player.statuses.artifact,1) end
  if event.detail.status=="artifact" then blocked=blocked+1;eq(event.detail.blockedStatus,"strength") end
 end
 eq(removals,1);eq(blocked,1)
end)
test("raw Entangle on enemy is not removed by that enemy's owner end",function()
 local s=battle();local e=s.enemies[1];C.addStatus(e,"entangled",2);A.endTurn(s,e);eq(e.statuses.entangled,2)
end)
test("real net application blocked by Artifact still permanently spends the net",function()
 local s=battle();local e=s.enemies[1];C.addStatus(s.player,"artifact",1);force(e,"red_slaver_2")
 roll(99,function() assert(C.endTurn(s)) end);eq(s.player.statuses.entangled or 0,0);eq(s.player.statuses.artifact,0);eq(e.redUsedEntangle,true);eq(move(s),"red_slaver_1")
 roll(99,function() assert(C.endTurn(s)) end);eq(move(s),"red_slaver_1")
 roll(99,function() assert(C.endTurn(s)) end);eq(move(s),"red_slaver_3")
end)
test("dead target and invalid entangle amount never spend Artifact",function()
 local s=battle();C.addStatus(s.player,"artifact",1);local n=#s.events
 eq(pcall(A.applyPower,s,s.player,"entangled",-1,s.enemies[1]),false);eq(s.player.statuses.artifact,1);eq(#s.events,n)
 s.player.hp=0;eq(A.applyPower(s,s.player,"entangled",1,s.enemies[1]),false);eq(s.player.statuses.artifact,1);eq(#s.events,n)
end)
test("zero Entangle is still an incoming DEBUFF and consumes one Artifact",function()
 local s=battle();C.addStatus(s.player,"artifact",1)
 eq(A.applyPower(s,s.player,"entangled",0,s.enemies[1]),false);eq(s.player.statuses.artifact,0);eq(s.player.statuses.entangled or 0,0)
end)
test("two real net actions spend one Artifact then apply one lock without sharing flags",function()
 local s=battle({"red_slaver","red_slaver"});for _,e in ipairs(s.enemies) do force(e,"red_slaver_2") end
 C.addStatus(s.player,"artifact",1);roll(0,function() assert(C.endTurn(s)) end,2)
 eq(s.player.statuses.artifact,0);eq(s.player.statuses.entangled,1)
 for _,e in ipairs(s.enemies) do eq(e.redUsedEntangle,true);eq(e.redLast,"red_slaver_2") end
end)
test("two Red actors keep once-only flags and histories separate",function()
 local s=battle({"red_slaver","red_slaver"});force(s.enemies[1],"red_slaver_2")
 roll(0,function() assert(C.endTurn(s)) end,2);eq(s.enemies[1].redUsedEntangle,true);eq(s.enemies[2].redUsedEntangle,false)
 eq(s.enemies[1].redLast,"red_slaver_2");eq(s.enemies[2].redLast,"red_slaver_1");eq(s.player.hp,67)
end)
test("real Run net restriction still permits a damage potion without card energy payment",function()
 local run=Run.new(Data,42);run.floor=4;assert(Run.startCombat(run,"red_slaver_solo"));force(run.combat.enemies[1],"red_slaver_2")
 roll(0,function() assert(Run.endTurn(run)) end);eq(run.combat.player.statuses.entangled,1)
 assert(Run.obtainPotion(run,"fire_potion"));local hp=run.combat.enemies[1].hp;local energy=run.combat.energy
 assert(Run.usePotion(run,1,1));eq(run.combat.enemies[1].hp,hp-20);eq(run.combat.energy,energy);eq(run.combat.player.statuses.entangled,1)
 eq(run.potions[1],nil)
end)
test("dead Red still rolls after Thorns while teammate lives and keeps queued Vulnerable",function()
 local s=battle({"red_slaver","cultist"});local e=s.enemies[1];force(e,"red_slaver_3");e.hp=1;C.addStatus(s.player,"thorns",1)
 roll(75,function() assert(C.endTurn(s)) end);eq(e.hp,0);eq(s.player.statuses.vulnerable,1);eq(e.redLast,"red_slaver_3");eq(C.intent(s,1),nil)
 roll(0,function() assert(C.endTurn(s)) end,0);eq(e.hp,0);eq(e.redLast,"red_slaver_3")
end)
test("last Red death clears queued roll and later Vulnerable",function()
 local s=battle();local e=s.enemies[1];force(e,"red_slaver_3");e.hp=1;C.addStatus(s.player,"thorns",1)
 roll(0,function() assert(C.endTurn(s)) end,0);eq(s.phase,"victory");eq(s.player.statuses.vulnerable or 0,0)
end)
test("poison death before acting never rolls or marks net used",function()
 local s=battle({"red_slaver","cultist"});local e=s.enemies[1];force(e,"red_slaver_2");e.hp=1;C.addStatus(e,"poison",1)
 roll(0,function() assert(C.endTurn(s)) end,0);eq(e.hp,0);eq(e.redUsedEntangle,false);eq(s.player.statuses.entangled or 0,0)
end)
test("failure after a real permitted skill preserves net flag lock histories and references",function()
 local s=battle();force(s.enemies[1],"red_slaver_2");roll(0,function() assert(C.endTurn(s)) end)
 local hand,statuses,enemy,events=s.hand,s.player.statuses,s.enemies[1],s.events;local before=C.copy(s)
 local original=C.block;C.block=function() error("RED_SKILL_FAILURE") end
 local ok,err=pcall(C.play,s,uid(s,"defend"));C.block=original;eq(ok,false);assert(tostring(err):find("RED_SKILL_FAILURE",1,true))
 same(before,s);eq(s.hand,hand);eq(s.player.statuses,statuses);eq(s.enemies[1],enemy);eq(s.events,events)
end)
print(count.." Red Slaver groups, "..failed.." failed");assert(failed==0)
