package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Combat,Silent,Discard=require("abyss_combat"),require("abyss_silent"),require("abyss_discard")
local Cards=require("abyss_silent_discard_cards")
local data=require("abyss_data")
local count=0
local function eq(a,b,label)assert(a==b,(label or "value")..": "..tostring(a).." ~= "..tostring(b))end
local function test(name,fn)fn();count=count+1;print("ok silent discard build "..count.." - "..name)end
local function fresh(deck)
 local d=Silent.withFoundationCards(data);local registered=false
 for _,c in ipairs(d.cards.cards)do if c.id=="sneaky_strike"then registered=true end end
 if not registered then d=Cards.withCardDefinitions(d)end
 local s=Combat.new(d,{deck=deck or {},enemies={"jaw_worm"},seed=42})
 s.enemies[1].hp,s.enemies[1].maxHp=300,300
 return s
end
local function find(s,id)
 for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust})do
  for _,c in ipairs(pile)do if c.cardId==id then return c end end
 end
 error("missing "..id)
end
local function held(s,id)
 for _,c in ipairs(s.hand)do if c.cardId==id then return c end end
 error("not held "..id)
end
test("fresh Eviscerate does not blindly inherit earlier discards until drawn",function()
 local s=fresh();s.discardedThisTurn=2
 local c=Cards.created({cardId="eviscerate",uid=999,upgraded=false})
 eq(Cards.costAdapter(s,c,{cost=3}).cost,3)
 Cards.onDraw(s,c);eq(Cards.costAdapter(s,c,{cost=3}).cost,1)
end)
test("didDiscard updates three ordinary piles including newly discarded card, not exhaust",function()
 local s=fresh({"eviscerate","eviscerate","eviscerate","eviscerate"})
 local cards={};for i,c in ipairs(s.hand)do cards[i]=c end
 s.hand={cards[1]};s.discard={cards[2]};s.draw={cards[3]};s.exhaust={cards[4]}
 Cards.rememberDiscard(s,false);eq(s.discardedThisTurn,1)
 for i=1,3 do eq(cards[i].storedDiscardCost,2)end
 eq(cards[4].storedDiscardCost,3) -- initialized by the real opening draw; exhaust is not discounted
end)
test("endTurn discards count without didDiscard; beginTurn resets three piles only",function()
 local s=fresh({"eviscerate","eviscerate"});local first,exhausted=s.hand[1],s.hand[2]
 s.hand={first};s.exhaust={exhausted};first.storedDiscardCost=1;exhausted.storedDiscardCost=1
 Cards.rememberDiscard(s,true);eq(s.discardedThisTurn,1);eq(first.storedDiscardCost,1)
 Cards.beginTurn(s);eq(s.discardedThisTurn,0);eq(first.storedDiscardCost,3);eq(exhausted.storedDiscardCost,1)
end)
test("Gamble count is captured at action expansion and zero hand emits no draw",function()
 local s=fresh({"defend","defend","defend"});local actions=Cards.gambleActions(s)
 eq(actions[1].effect.op,"requestDiscard");eq(actions[1].effect.value,3)
 eq(actions[2].effect.op,"draw");eq(actions[2].effect.value,3)
 table.remove(s.hand);eq(actions[1].effect.value,3)
 local current=Cards.gambleActions(s);eq(current[1].effect.value,2)
 s.hand={};eq(#Cards.gambleActions(s),0)
end)
test("refund reads history at execution and stops after final enemy death",function()
 local s=fresh();local energy=s.energy
 eq(Cards.gainEnergyIfDiscard(s,2),false);eq(s.energy,energy)
 Cards.rememberDiscard(s,false);assert(Cards.gainEnergyIfDiscard(s,2));eq(s.energy,energy+2)
 s.enemies[1].hp=0;eq(Cards.gainEnergyIfDiscard(s,2),false)
end)
test("counter and stored-cost overflow reject before changing state",function()
 local s=fresh({"eviscerate"});s.discardedThisTurn=2147483647
 assert(not pcall(Cards.rememberDiscard,s,false));eq(s.discardedThisTurn,2147483647)
 eq(s.hand[1].storedDiscardCost,3) -- real draw initialized it; rejected increment must retain it
 s.discardedThisTurn=0;s.hand[1].storedDiscardCost=-1
 assert(not pcall(Cards.rememberDiscard,s,false));eq(s.discardedThisTurn,0)
end)

-- Real-core regressions require shared queue/counter/cost hooks. No mock
-- supplies missing mechanics; the initial unintegrated run was explicitly red.
for _,upgraded in ipairs({false,true})do
 test("real Sneaky Strike without discard spends two, without refund "..tostring(upgraded),function()
  local s=fresh({{cardId="sneaky_strike",upgraded=upgraded}});local card=s.hand[1]
  assert(Combat.play(s,card.uid,1),"shared gainEnergyIfDiscard integration required")
  eq(s.energy,1);eq(s.enemies[1].hp,300-(upgraded and 16 or 12))
 end)
 test("real manual discard enables Sneaky Strike refund after damage "..tostring(upgraded),function()
  local s=fresh({{cardId="sneaky_strike",upgraded=upgraded},"defend"})
  assert(Discard.manualDiscard(s,held(s,"defend").uid,Combat));eq(s.discardedThisTurn,1)
  assert(Combat.play(s,held(s,"sneaky_strike").uid,1));eq(s.energy,3)
  eq(s.enemies[1].hp,300-(upgraded and 16 or 12))
 end)
 test("Eviscerate discount changes actual payment and retains three hits "..tostring(upgraded),function()
  local s=fresh({{cardId="eviscerate",upgraded=upgraded},"defend"})
  local card=held(s,"eviscerate");assert(Discard.manualDiscard(s,held(s,"defend").uid,Combat))
  eq(Combat.cardDefinition(s,card).cost,2)
  assert(Combat.play(s,card.uid,1));eq(s.energy,1)
  eq(s.enemies[1].hp,300-(upgraded and 27 or 21))
 end)
 test("Gamble uses real all-discard then draw with correct exhaustion "..tostring(upgraded),function()
  local s=fresh({{cardId="calculated_gamble",upgraded=upgraded},"defend","defend"})
  local card=held(s,"calculated_gamble");assert(Combat.play(s,card.uid))
  eq(s.discardedThisTurn,2);eq(#s.hand,2);eq(s.energy,3)
  eq(#s.exhaust,upgraded and 0 or 1);eq(#s.discard,upgraded and 1 or 0)
  for _,c in ipairs(s.hand)do assert(c~=card,"Gamble must not be in its own normal draw")end
 end)
 test("Gamble Tactician head and Reflex tail use source cleanup order "..tostring(upgraded),function()
  local s=fresh({{cardId="calculated_gamble",upgraded=upgraded},"tactician","reflex","defend"})
  local card=held(s,"calculated_gamble");assert(Combat.play(s,card.uid))
  eq(s.discardedThisTurn,3);eq(s.energy,4)
  eq(#s.hand,upgraded and 4 or 3);eq(#s.exhaust,upgraded and 0 or 1)
  local redrawn=false;for _,c in ipairs(s.hand)do if c==card then redrawn=true end end
  eq(redrawn,upgraded)
 end)
 test("zero-hand Gamble emits no fake extra draw "..tostring(upgraded),function()
  local s=fresh({{cardId="calculated_gamble",upgraded=upgraded}});local card=s.hand[1]
  assert(Combat.play(s,card.uid));eq(#s.hand,0);eq(s.discardedThisTurn or 0,0)
  eq(#s.exhaust,upgraded and 0 or 1);eq(#s.discard,upgraded and 1 or 0)
 end)
 test("full-hand Gamble discards nine then draws nine without random-discard RNG "..tostring(upgraded),function()
  local deck={{cardId="calculated_gamble",upgraded=upgraded}}
  for _=1,9 do deck[#deck+1]="defend"end
  local s=fresh(deck);Combat.draw(s,5);eq(#s.hand,10)
  local rng=require("abyss_sts_random").fromSeed("123");s.cardRandomRng=rng
  assert(Combat.play(s,held(s,"calculated_gamble").uid))
  eq(s.discardedThisTurn,9);eq(#s.hand,9);eq(rng.counter,0)
  eq(#s.exhaust,upgraded and 0 or 1);eq(#s.discard,upgraded and 1 or 0)
 end)
end
test("final killing Sneaky Strike does not refund energy",function()
 local s=fresh({"sneaky_strike","defend"});s.enemies[1].hp=12
 assert(Discard.manualDiscard(s,held(s,"defend").uid,Combat))
 assert(Combat.play(s,held(s,"sneaky_strike").uid,1));eq(s.phase,"victory");eq(s.energy,1)
end)
test("drawing Eviscerate applies earlier history and next real turn resets it",function()
 local deck={"eviscerate"};for _=1,8 do deck[#deck+1]="defend"end
 local s=fresh(deck);local evis=find(s,"eviscerate")
 for i,c in ipairs(s.hand)do if c==evis then s.hand[i],s.draw[#s.draw]=s.draw[#s.draw],c;break end end
 for i,c in ipairs(s.draw)do if c==evis then s.draw[i],s.draw[#s.draw]=s.draw[#s.draw],c;break end end
 assert(Discard.manualDiscard(s,held(s,"defend").uid,Combat))
 assert(Discard.manualDiscard(s,held(s,"defend").uid,Combat))
 Combat.draw(s,1);eq(held(s,"eviscerate"),evis);eq(Combat.cardDefinition(s,evis).cost,1)
 assert(Combat.endTurn(s));eq(s.discardedThisTurn,0);eq(Combat.cardDefinition(s,evis).cost,3)
end)
test("Gamble with NoDraw still discards and triggers Tactician but draws nothing",function()
 local s=fresh({{cardId="calculated_gamble",upgraded=true},"tactician","reflex","defend"})
 s.player.noDraw=true;assert(Combat.play(s,held(s,"calculated_gamble").uid))
 eq(s.discardedThisTurn,3);eq(s.energy,4);eq(#s.hand,0);eq(#s.discard,4)
end)
test("Gamble discards Eviscerate and real redraw resets its cost from total history",function()
 local s=fresh({"calculated_gamble","eviscerate","defend"})
 assert(Combat.play(s,held(s,"calculated_gamble").uid))
 eq(s.discardedThisTurn,2);local evis=held(s,"eviscerate")
 eq(Combat.cardDefinition(s,evis).cost,1);assert(Combat.play(s,evis.uid,1));eq(s.energy,2)
end)
test("Eviscerate discount clamps at zero without refunding extra energy",function()
 local deck={"eviscerate"};for _=1,5 do deck[#deck+1]="defend"end
 local s=fresh(deck);Combat.draw(s,1);local evis=held(s,"eviscerate")
 for _=1,5 do assert(Discard.manualDiscard(s,held(s,"defend").uid,Combat))end
 eq(s.discardedThisTurn,5);eq(Combat.cardDefinition(s,evis).cost,0)
 assert(Combat.play(s,evis.uid,1));eq(s.energy,3)
end)
print("SILENT_DISCARD_BUILD_PASS "..count)
