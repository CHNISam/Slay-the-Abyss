package.path = "src/lua/?.lua;build/lua/?.lua;" .. package.path
local Combat, Run = require("abyss_combat"), require("abyss_run")
local data = require("abyss_data")
local count=0
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn) fn(); count=count+1; print("ok guardian "..count.." - "..name) end
local function battle(deck,hp,enemies) return Combat.new(data,{deck=deck or {"defend"},enemies=enemies or {"guardian"},seed=42,hp=hp}) end
local function intent(s) return Combat.intent(s,1).id end
local function play(s,id,target)
 for _,card in ipairs(s.hand) do if card.cardId==id then assert(Combat.play(s,card.uid,target or 1)); return end end
 error("missing card "..id)
end
local function defense(deck,hp,enemies)
 local s=battle(deck,hp,enemies); Combat.damage(s,s.player,s.enemies[1],30,true)
 assert(Combat.endTurn(s)); return s,s.enemies[1]
end
local function sharpEvents(s,first)
 local n=0
 for i=first or 1,#s.events do local e=s.events[i]; if e.kind=="status_damage" and e.detail.status=="sharp_hide" then n=n+1 end end
 return n
end

test("A0 Guardian starts offensive at 240 HP and 30 Mode Shift",function()
 local s=battle(); local e=s.enemies[1]
 eq(e.hp,240); eq(e.statuses.mode_shift,30); eq(intent(s),"guardian_1"); eq(e.block,0)
end)
test("uninterrupted offense follows Charge Bash Vent Whirlwind with exact debuff order",function()
 local s=battle(); local expected={"guardian_1","guardian_2","guardian_4","guardian_3","guardian_1"}
 for i,id in ipairs(expected) do
  eq(intent(s),id); s.player.block=100 -- isolated survival fixture, no winning-run claim
  local first=#s.events+1
  assert(Combat.endTurn(s))
  local hits={}; for n=first,#s.events do local ev=s.events[n]; if ev.kind=="damage" and ev.detail.source==s.enemies[1].id then hits[#hits+1]=ev.detail end end
  if i==2 then eq(#hits,1); eq(hits[1].blocked,32)
  elseif i==4 then eq(#hits,4); for _,hit in ipairs(hits) do eq(hit.blocked,7,"5 base x1.5 vulnerable floors to 7") end
  else eq(#hits,0) end
  if i==1 then eq(s.enemies[1].block,9) end
  if i==3 then
   local applied={}; for _,e in ipairs(s.events) do if e.kind=="status" and e.detail.target=="player" then applied[#applied+1]=e.detail.status end end
   eq(applied[#applied-1],"weak"); eq(applied[#applied],"vulnerable")
   eq(s.player.statuses.weak,2); eq(s.player.statuses.vulnerable,2)
  end
 end
 eq(s.player.hp,80)
end)
test("normal thorns HP loss during Guardian's own attack does not reduce Mode Shift",function()
 local s=battle(); local e=s.enemies[1]; s.player.statuses.thorns=3
 assert(Combat.endTurn(s)); s.player.block=32; assert(Combat.endTurn(s))
 eq(e.hp,237); eq(e.statuses.mode_shift,30); eq(intent(s),"guardian_4")
end)
test("only actual unblocked HP loss lowers Mode Shift, exact boundary shifts immediately",function()
 local s=battle(); local e=s.enemies[1]; assert(Combat.endTurn(s)); eq(e.block,9)
 Combat.damage(s,s.player,e,9,true); eq(e.statuses.mode_shift,30)
 Combat.damage(s,s.player,e,29,true); eq(e.statuses.mode_shift,1); eq(intent(s),"guardian_2")
 Combat.damage(s,s.player,e,1,true); eq(e.statuses.mode_shift,0); eq(e.block,20); eq(intent(s),"guardian_5")
 eq(e.statuses.sharp_hide or 0,0,"hide begins at the close-up action, not the shift")
 assert(Combat.endTurn(s)); eq(s.player.hp,80); eq(e.block,0); eq(e.statuses.sharp_hide,3); eq(intent(s),"guardian_6")
end)
test("defense rolls then twin slams, removes hide and returns directly to Whirlwind",function()
 local s,e=defense(); eq(intent(s),"guardian_6")
 assert(Combat.endTurn(s)); eq(s.player.hp,71); eq(intent(s),"guardian_7")
 assert(Combat.endTurn(s)); eq(s.player.hp,55); eq(intent(s),"guardian_3")
 eq(e.statuses.sharp_hide,0); eq(e.statuses.mode_shift,40)
 assert(Combat.endTurn(s)); eq(s.player.hp,35); eq(intent(s),"guardian_1")
end)
test("defensive damage and excess shift damage never carry into next 40 threshold",function()
 local s=battle(); local e=s.enemies[1]
 Combat.damage(s,s.player,e,35,true); eq(e.block,20)
 Combat.damage(s,s.player,e,25,true); eq(e.hp,200); eq(e.statuses.mode_shift,0)
 for _=1,3 do assert(Combat.endTurn(s)) end
 eq(e.statuses.mode_shift,40)
 Combat.damage(s,s.player,e,39,true); eq(e.statuses.mode_shift,1); eq(intent(s),"guardian_3")
 Combat.damage(s,s.player,e,1,true); eq(e.statuses.mode_shift,0); eq(e.block,20)
 for _=1,3 do assert(Combat.endTurn(s)) end
 eq(e.statuses.mode_shift,50)
end)
test("crossing Mode Shift in hit one grants block before hit two and does not cancel the card",function()
 local s=battle({"twin_strike"}); local e=s.enemies[1]
 Combat.damage(s,s.player,e,25,true); play(s,"twin_strike")
 eq(e.hp,210); eq(e.block,15); eq(intent(s),"guardian_5"); eq(s.player.hp,80)
end)
test("poison at enemy turn start shifts and performs Close Up instead of old attack",function()
 local s=battle(); local e=s.enemies[1]; assert(Combat.endTurn(s))
 Combat.addStatus(e,"poison",30); assert(Combat.endTurn(s))
 eq(e.hp,210); eq(e.block,20); eq(e.statuses.sharp_hide,3); eq(intent(s),"guardian_6"); eq(s.player.hp,80)
end)
test("actual multihit Attack produces one Sharp Hide reaction",function()
 local s,e=defense({"twin_strike"}); local first=#s.events+1
 play(s,"twin_strike"); eq(e.hp,200); eq(s.player.hp,77); eq(sharpEvents(s,first),1)
end)
test("zero-damage Body Slam still triggers one Sharp Hide reaction",function()
 local s,e=defense({"body_slam"}); play(s,"body_slam")
 eq(e.hp,210); eq(s.player.hp,77); eq(sharpEvents(s),1)
end)
test("Iron Wave grants its own block before the queued Sharp Hide damage",function()
 local s,e=defense({"iron_wave"}); play(s,"iron_wave")
 eq(e.hp,205); eq(s.player.hp,80); eq(s.player.block,2); eq(sharpEvents(s),1)
end)
test("Skills Powers and real fire potion do not count as an Attack card",function()
 local run=Run.new(data,42); run.floor=data.rules.map.bossFloor; run.potions={"fire_potion"}
 assert(Run.startCombat(run,"boss_guardian")); local s=run.combat; local e=s.enemies[1]
 Combat.damage(s,s.player,e,30,true); assert(Run.endTurn(run))
 s.hand={{cardId="defend",uid=100},{cardId="inflame",uid=101}} -- exact legal card action fixtures
 play(s,"defend"); play(s,"inflame"); assert(Run.usePotion(run,1,1))
 eq(s.player.hp,80); eq(s.player.block,5); eq(sharpEvents(s),0)
end)
test("Sharp Hide reacts even when a different enemy is targeted",function()
 local s,e=defense({"strike"},80,{"guardian","cultist"}); local hp=s.player.hp
 play(s,"strike",2); eq(s.player.hp,hp-3); eq(e.hp,210); eq(sharpEvents(s),1)
end)
test("Sharp Hide ignores attack modifiers and cannot recursively trigger player thorns",function()
 local s,e=defense({"twin_strike"}); e.statuses.strength=100; e.statuses.weak=1
 s.player.statuses.vulnerable=1; s.player.statuses.thorns=100
 play(s,"twin_strike"); eq(s.player.hp,77); eq(e.hp,200); eq(sharpEvents(s),1)
end)
test("partial block absorbs Sharp Hide before HP",function()
 local s,e=defense({"body_slam"}); s.player.block=2; play(s,"body_slam")
 eq(s.player.hp,79); eq(s.player.block,0)
end)
test("lethal Attack still takes scheduled Sharp Hide, simultaneous death loses once",function()
 local s,e=defense({"strike"},3); e.hp=5 -- explicit lethal edge fixture
 play(s,"strike"); eq(e.hp,0); eq(s.player.hp,0); eq(s.phase,"defeat"); eq(sharpEvents(s),1)
 local losses,wins=0,0; for _,ev in ipairs(s.events) do if ev.kind=="defeat" then losses=losses+1 elseif ev.kind=="victory" then wins=wins+1 end end
 eq(losses,1); eq(wins,0); eq(Combat.endTurn(s),false)
end)
test("lethal Iron Wave still gains block and survives the dead owner's Sharp Hide",function()
 local s,e=defense({"iron_wave"},1); e.hp=5
 play(s,"iron_wave"); eq(e.hp,0); eq(s.player.hp,1); eq(s.player.block,2); eq(s.phase,"victory")
end)
test("lethal threshold hit never grants new defensive block or reschedules a dead boss",function()
 local s=battle({"bludgeon"}); local e=s.enemies[1]; e.hp=30
 play(s,"bludgeon"); eq(e.hp,0); eq(e.block,0); eq(Combat.intent(s,1),nil); eq(s.phase,"victory")
end)
test("failed card restores interrupted intention, threshold, Block and original references",function()
 local s=battle({"strike"}); local e=s.enemies[1]
 Combat.damage(s,s.player,e,25,true); local before=Combat.copy(s); local statuses=e.statuses
 s.catalog.cards.strike.effects={{op="damage",value=6},{op="gainStatus",status="strength",value=2147483647}}
 s.player.statuses.strength=1
 eq(pcall(Combat.play,s,s.hand[1].uid,1),false)
 eq(s.enemies[1],e); eq(e.statuses,statuses); eq(e.hp,215); eq(e.block,0); eq(e.statuses.mode_shift,5)
 eq(intent(s),"guardian_1"); eq(s.energy,before.energy); eq(#s.events,#before.events)
end)
print("guardian AI: "..count.." groups passed")
