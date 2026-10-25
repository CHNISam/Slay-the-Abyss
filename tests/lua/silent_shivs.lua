package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local Combat,Silent,Shivs=require("abyss_combat"),require("abyss_silent"),require("abyss_shivs")
local Actors,Stances=require("abyss_actor"),require("abyss_stances")
local data=require("abyss_data")
local count=0
local function eq(a,b,label)assert(a==b,(label or "value")..": "..tostring(a).." ~= "..tostring(b))end
local function test(name,fn)fn();count=count+1;print("ok silent shivs "..count.." - "..name)end
local function fresh(deck)
 local prepared=Silent.withFoundationCards(data)
 local s=Combat.new(prepared,{deck=deck or {},enemies={"jaw_worm"},seed=42})
 s.enemies[1].hp,s.enemies[1].maxHp=300,300
 return s
end
local function find(s,id)
 for _,c in ipairs(s.hand)do if c.cardId==id then return c end end
 error("missing "..id)
end

local function suite()
for _,upgraded in ipairs({false,true})do
 test("real Accuracy card updates old Shiv base without double counting "..tostring(upgraded),function()
  local s=fresh({{cardId="accuracy",upgraded=upgraded},"shiv"})
  local card=find(s,"accuracy");local shiv=find(s,"shiv");local energy=s.energy
  assert(Combat.play(s,card.uid));eq(s.energy,energy-1)
  local amount=upgraded and 6 or 4
  eq(s.player.statuses.accuracy,amount);eq(shiv.shivAccuracyBonus,amount)
  for _,event in ipairs(s.events)do
   if event.kind=="status"and event.detail.status=="accuracy"then
    for _,c in ipairs(event.frame.hand)do if c.cardId=="shiv"then eq(c.shivAccuracyBonus,amount)end end
   end
  end
  for _=1,3 do
   eq(Combat.cardDefinition(s,shiv).effects[1].value,4+amount)
   Shivs.onDrawOrDiscard(s)
  end
  local hp=s.enemies[1].hp;assert(Combat.play(s,shiv.uid,1))
  eq(s.enemies[1].hp,hp-4-amount);eq(#s.exhaust,1)
 end)
end
test("Accuracy refreshes hand draw discard and exhaust independently",function()
 local s=fresh({"accuracy","shiv","shiv","shiv","shiv"})
 local cards={};for _,c in ipairs(s.hand)do if c.cardId=="shiv"then cards[#cards+1]=c end end
 for i=2,4 do
  for p,c in ipairs(s.hand)do if c==cards[i]then table.remove(s.hand,p);break end end
  local pile=({"draw","discard","exhaust"})[i-1];s[pile][#s[pile]+1]=cards[i]
 end
 assert(Combat.play(s,find(s,"accuracy").uid))
 for _,c in ipairs(cards)do eq(c.shivAccuracyBonus,4)end
 assert(Shivs.applyAccuracy(s,6));eq(s.player.statuses.accuracy,10)
 for _,c in ipairs(cards)do eq(c.shivAccuracyBonus,10);eq(Combat.cardDefinition(s,c).effects[1].value,14)end
end)
test("new Shiv captures current Accuracy and upgraded variant adds only two",function()
 local s=fresh({"accuracy"});assert(Combat.play(s,s.hand[1].uid))
 -- Explicit construction boundary fixtures, not the still-guarded generator.
 local base=Shivs.created(s,{uid=s.nextUid,cardId="shiv",upgraded=false});s.nextUid=s.nextUid+1
 local upgraded=Shivs.created(s,{uid=s.nextUid,cardId="shiv",upgraded=true});s.nextUid=s.nextUid+1
 s.hand[#s.hand+1]=base;s.hand[#s.hand+1]=upgraded
 eq(Combat.cardDefinition(s,base).effects[1].value,8)
 eq(Combat.cardDefinition(s,upgraded).effects[1].value,10)
 local hp=s.enemies[1].hp
 assert(Combat.play(s,base.uid,1));assert(Combat.play(s,upgraded.uid,1))
 eq(s.enemies[1].hp,hp-18);eq(#s.exhaust,2)
end)
test("upgrading an existing Accuracy-stamped Shiv retains its captured bonus",function()
 local s=fresh({"shiv"});assert(Shivs.applyAccuracy(s,4));local card=s.hand[1]
 eq(Combat.cardDefinition(s,card).effects[1].value,8)
 card.upgraded=true -- isolated upgrade boundary; not a claim of a gameplay upgrade action
 eq(Combat.cardDefinition(s,card).effects[1].value,10)
end)
test("removing Accuracy preserves existing bases but later constructors use zero",function()
 local s=fresh({"shiv"});local old=s.hand[1]
 assert(Shivs.applyAccuracy(s,6));assert(Shivs.removeAccuracy(s))
 eq(old.shivAccuracyBonus,6);Shivs.onDrawOrDiscard(s);eq(old.shivAccuracyBonus,6)
 eq(Combat.cardDefinition(s,old).effects[1].value,10)
 local new=Shivs.created(s,{uid=s.nextUid,cardId="shiv",upgraded=false});s.nextUid=s.nextUid+1
 s.hand[#s.hand+1]=new;eq(Combat.cardDefinition(s,new).effects[1].value,4)
 local hp=s.enemies[1].hp;assert(Combat.play(s,old.uid,1));assert(Combat.play(s,new.uid,1))
 eq(s.enemies[1].hp,hp-14)
end)
test("new application after removal overwrites old bonus rather than accumulating it",function()
 local s=fresh({"shiv"});local card=s.hand[1]
 assert(Shivs.applyAccuracy(s,6));assert(Shivs.removeAccuracy(s));assert(Shivs.applyAccuracy(s,4))
 eq(card.shivAccuracyBonus,4);eq(Combat.cardDefinition(s,card).effects[1].value,8)
end)
test("hand draw-discard hook refreshes hand only while Power exists",function()
 local s=fresh({"shiv","shiv"});local hand=s.hand[1];local other=table.remove(s.hand,2)
 s.draw[#s.draw+1]=other;assert(Shivs.applyAccuracy(s,6))
 s.player.statuses.accuracy=4 -- simulate ReducePower changing amount; no redraw yet
 Shivs.onDrawOrDiscard(s);eq(hand.shivAccuracyBonus,4);eq(other.shivAccuracyBonus,6)
end)
test("Strength Weak Vulnerable Wrath apply after stored base and general bonus",function()
 local s=fresh({"shiv"});local card=s.hand[1]
 assert(Shivs.applyAccuracy(s,4));card.damageBonus=1
 Actors.addStatus(s.player,"strength",3);Actors.addStatus(s.player,"weak",1)
 Actors.addStatus(s.enemies[1],"vulnerable",1)
 s.player.stance="Neutral";Stances.change(s,"Wrath")
 -- (base4 + Accuracy4 + generic1 + Strength3) * .75 * 1.5 * 2 = 27
 eq(Combat.cardDefinition(s,card).effects[1].value,9)
 eq(Combat.cardPreview(s,card,1)[1].low,27)
 local hp=s.enemies[1].hp;assert(Combat.play(s,card.uid,1));eq(s.enemies[1].hp,hp-27)
end)
test("catalog stays immutable and real generator stamps Accuracy",function()
 local s=fresh({"shiv"});assert(Shivs.applyAccuracy(s,4))
 eq(s.catalog.cards.shiv.effects[1].value,4);eq(s.catalog.cards.shiv.upgrade.effects[1].value,6)
 assert(not pcall(Combat.cardDefinition,s,{uid=999,cardId="shiv",upgraded=false}))
 local uids=Silent.generateShivs(s,1);local generated
 for _,c in ipairs(s.hand)do if c.uid==uids[1]then generated=c end end
 eq(generated.shivAccuracyBonus,4);eq(Combat.cardDefinition(s,generated).effects[1].value,8)
end)
test("invalid application and malformed card pile fail before changing status",function()
 local s=fresh({"shiv"});local card=s.hand[1]
 assert(not pcall(Shivs.applyAccuracy,s,5));eq(s.player.statuses.accuracy or 0,0)
 s.draw[1]=card
 assert(not pcall(Shivs.applyAccuracy,s,4));eq(s.player.statuses.accuracy or 0,0)
 eq(card.shivAccuracyBonus,nil)
end)
test("actual Accuracy then Blade Dance stamps and plays three independent boosted Shivs",function()
 local s=fresh({"accuracy","blade_dance"})
 assert(Combat.play(s,find(s,"accuracy").uid));assert(Combat.play(s,find(s,"blade_dance").uid))
 eq(#s.hand,3);local hp=s.enemies[1].hp;local uids={}
 for _,c in ipairs(s.hand)do eq(c.cardId,"shiv");eq(c.shivAccuracyBonus,4);uids[#uids+1]=c.uid end
 for _,uid in ipairs(uids)do assert(Combat.play(s,uid,1))end
 eq(s.enemies[1].hp,hp-24);eq(#s.exhaust,3)
end)
test("failure after actual Accuracy effects restores original Shiv instances in four piles",function()
 local s=fresh({"accuracy","shiv","shiv","shiv","shiv"});local power=find(s,"accuracy")
 local shivs={};for _,c in ipairs(s.hand)do if c.cardId=="shiv"then shivs[#shivs+1]=c end end
 for i=2,4 do
  for p,c in ipairs(s.hand)do if c==shivs[i]then table.remove(s.hand,p);break end end
  local pile=({"draw","discard","exhaust"})[i-1];s[pile][#s[pile]+1]=shivs[i]
 end
 local hand,draw,discard,exhaust,statuses,events=s.hand,s.draw,s.discard,s.exhaust,s.player.statuses,s.events
 local energy,eventCount=s.energy,#events;local original=Combat.applyEffects;local sentinel={}
 Combat.applyEffects=function(...)
  local result=original(...)
  for _,card in ipairs(shivs)do eq(card.shivAccuracyBonus,4)end
  error(sentinel)
 end
 local ok,err=pcall(Combat.play,s,power.uid);Combat.applyEffects=original
 eq(ok,false);eq(err,sentinel);eq(s.hand,hand);eq(s.draw,draw);eq(s.discard,discard);eq(s.exhaust,exhaust)
 eq(s.player.statuses,statuses);eq(s.events,events);eq(#events,eventCount);eq(s.energy,energy)
 eq(s.player.statuses.accuracy or 0,0)
 for _,card in ipairs(shivs)do eq(card.shivAccuracyBonus,nil)end
 eq(s.draw[1],shivs[2]);eq(s.discard[1],shivs[3]);eq(s.exhaust[1],shivs[4])
 assert(Combat.play(s,power.uid));for _,card in ipairs(shivs)do eq(card.shivAccuracyBonus,4)end
end)
local function infinite(deck)
 local prepared=Shivs.withInfiniteBladesDefinition(Silent.withFoundationCards(data))
 local s=Combat.new(prepared,{deck=deck or {},enemies={"jaw_worm"},seed=42})
 s.enemies[1].hp,s.enemies[1].maxHp=300,300
 return s
end
for _,upgraded in ipairs({false,true})do
 test("Infinite Blades real Power applies one layer without immediate Shiv "..tostring(upgraded),function()
  local s=infinite({{cardId="infinite_blades",upgraded=upgraded}});local card=s.hand[1]
  eq(Combat.cardDefinition(s,card).innate==true,upgraded)
  local energy=s.energy;assert(Combat.play(s,card.uid));eq(s.energy,energy-1)
  eq(s.player.statuses.infinite_blades,1);eq(#s.hand,0);eq(#s.discard,0);eq(#s.exhaust,0)
  local ok,uids=Shivs.startTurn(s,Silent.generateShivs);assert(ok);eq(#uids,1);eq(#s.hand,1)
  eq(s.hand[1].upgraded,false)
 end)
end
test("stacked Infinite Blades generates per layer and retains no callback in state",function()
 local s=infinite({"infinite_blades","infinite_blades"})
 while #s.hand>0 do assert(Combat.play(s,s.hand[1].uid))end
 eq(s.player.statuses.infinite_blades,2)
 local calls=0
 local ok,uids=Shivs.startTurn(s,function(state,n,upgraded)
  calls=calls+1;eq(n,2);eq(upgraded,false);return Silent.generateShivs(state,n,upgraded)
 end)
 assert(ok);eq(calls,1);eq(#uids,2)
 local seen={}
 local function scan(t)
  if seen[t]then return end;seen[t]=true
  for _,v in pairs(t)do assert(type(v)~="function","callback persisted");if type(v)=="table"then scan(v)end end
 end
 scan(s)
end)
test("explicit pre-draw hook fills final hand slot before ordinary draw",function()
 local deck={};for _=1,12 do deck[#deck+1]="defend"end
 local s=infinite(deck);Combat.draw(s,4);eq(#s.hand,9)
 assert(Shivs.applyInfiniteBlades(s,1));local drawCount=#s.draw
 assert(Shivs.startTurn(s,Silent.generateShivs));eq(#s.hand,10)
 Combat.draw(s,5);eq(#s.hand,10);eq(#s.draw,drawCount)
 -- This fixture calls the hook at its documented boundary; it is not a
 -- claim that shared Combat.startPlayerTurn already invokes Infinite Blades.
end)
test("Infinite Blades full-hand output goes to discard and carries Accuracy",function()
 local deck={"accuracy"};for _=1,12 do deck[#deck+1]="defend"end
 local s=infinite(deck)
 assert(Shivs.applyAccuracy(s,4));Combat.draw(s,5);eq(#s.hand,10)
 assert(Shivs.applyInfiniteBlades(s,1));local n=#s.discard
 local ok,uids=Shivs.startTurn(s,Silent.generateShivs);assert(ok)
 eq(#s.hand,10);eq(#s.discard,n+1);local card=s.discard[#s.discard]
 eq(card.uid,uids[1]);eq(card.cardId,"shiv");eq(card.shivAccuracyBonus,4)
 eq(Combat.cardDefinition(s,card).effects[1].value,8)
end)
test("Infinite Blades real generator and Accuracy produce a playable eight-damage Shiv",function()
 local s=infinite({"accuracy","infinite_blades"})
 assert(Combat.play(s,find(s,"accuracy").uid));assert(Combat.play(s,find(s,"infinite_blades").uid))
 local ok,uids=Shivs.startTurn(s,Silent.generateShivs);assert(ok)
 local hp=s.enemies[1].hp;assert(Combat.play(s,uids[1],1));eq(s.enemies[1].hp,hp-8)
end)
test("Infinite Blades empty absent and dead cases remain explicit",function()
 local s=infinite();eq(Shivs.startTurn(s,function()error("absent power ran")end),false)
 assert(Shivs.applyInfiniteBlades(s,1));s.player.hp=0
 eq(Shivs.startTurn(s,function()error("dead source ran")end),false)
 s=infinite();assert(Shivs.applyInfiniteBlades(s,1));s.enemies[1].hp=0
 eq(Shivs.startTurn(s,function()error("dead combat ran")end),false)
end)
test("eleven Infinite Blades layers legally generate ten in hand and one in discard with Accuracy",function()
 local s=infinite();assert(Shivs.applyAccuracy(s,4))
 for _=1,11 do assert(Shivs.applyInfiniteBlades(s,1))end
 local ok,uids=Shivs.startTurn(s,Silent.generateShivs);assert(ok);eq(#uids,11)
 eq(#s.hand,10);eq(#s.discard,1)
 local seen={}
 for _,pile in ipairs({s.hand,s.discard})do
  for _,card in ipairs(pile)do
   assert(not seen[card.uid]);seen[card.uid]=true;eq(card.upgraded,false);eq(card.shivAccuracyBonus,4)
   eq(Combat.cardDefinition(s,card).effects[1].value,8)
  end
 end
end)
for _,upgraded in ipairs({false,true})do
 test("Infinite Blades uses full shared endTurn then generates before draw "..tostring(upgraded),function()
  local deck={{cardId="infinite_blades",upgraded=upgraded}}
  for _=1,4 do deck[#deck+1]="defend"end
  local s=infinite(deck);local card=find(s,"infinite_blades")
  local Random=require("abyss_sts_random")
  s.cardRandomRng=Random.fromSeed("17")
  local randomBefore=Random.snapshot(s.cardRandomRng)
  local function unchangedCardRng()
   local after=Random.snapshot(s.cardRandomRng);eq(after.counter,randomBefore.counter)
   for key,word in pairs(randomBefore.words)do eq(after.words[key],word,"Shiv generation must not consume card RNG")end
   for key,word in pairs(after.words)do eq(randomBefore.words[key],word)end
  end
  local nextUid=s.nextUid
  assert(Combat.play(s,card.uid));eq(#s.hand,4);eq(s.player.statuses.infinite_blades,1)
  for _,c in ipairs(s.hand)do assert(c.cardId~="shiv","Power must not generate immediately")end
  local oldEvents=#s.events;assert(Combat.endTurn(s));eq(s.turn,2)
  local shivCount,first=0
  for _,c in ipairs(s.hand)do if c.cardId=="shiv"then shivCount=shivCount+1;first=c end end
  eq(shivCount,1);eq(#s.hand,5);eq(first.uid,nextUid);unchangedCardRng()
  local observed=0
  for i=oldEvents+1,#s.events do local e=s.events[i]
   if e.kind=="cards_created"and e.detail.cardId=="shiv"then
    observed=observed+1;eq(e.detail.source,s.player.id);eq(e.detail.amount,1);eq(e.detail.pile,"hand")
    eq(e.frame.turn,2);eq(#e.frame.hand,1)
    eq(e.frame.hand[1].cardId,"shiv");eq(e.frame.hand[1].uid,first.uid) -- ordinary draw has not run yet
   end
  end
  eq(observed,1);nextUid=s.nextUid
  assert(Combat.endTurn(s));eq(s.turn,3);unchangedCardRng()
  local nextGenerated,nextCount=nil,0
  for _,e in ipairs(s.events)do
   if e.kind=="cards_created"and e.detail.cardId=="shiv"and e.frame.turn==3 then
    nextCount=nextCount+1;eq(e.detail.source,s.player.id);eq(e.detail.amount,1);eq(e.detail.pile,"hand")
    eq(#e.frame.hand,1);eq(e.frame.hand[1].cardId,"shiv");nextGenerated=e.frame.hand[1].uid
   end
  end
  eq(nextCount,1);eq(nextGenerated,nextUid)
  assert(nextGenerated~=first.uid,"next turn needs a new instance")
 end)
end
test("upgraded Innate reaches opening hand after the same shuffle; basic is not forced",function()
 local prepared=Shivs.withInfiniteBladesDefinition(Silent.withFoundationCards(data))
 local states={}
 for i,upgraded in ipairs({false,true})do
  local deck={{cardId="infinite_blades",upgraded=upgraded}}
  for _=1,14 do deck[#deck+1]="defend"end
  states[i]=Combat.new(prepared,{deck=deck,enemies={"jaw_worm"},seed=1})
  eq(#states[i].hand,5);eq(states[i].player.statuses.infinite_blades or 0,0)
  for _,c in ipairs(states[i].hand)do assert(c.cardId~="shiv")end
 end
 for _,c in ipairs(states[1].hand)do assert(c.cardId~="infinite_blades","fixed basic card is outside first five")end
 eq(states[2].hand[1].cardId,"infinite_blades");eq(states[2].hand[1].upgraded,true)
 eq(states[1].seed,states[2].seed,"Innate placement must not skip or add shuffle entropy")
end)
test("actual Accuracy plus Infinite Blades generates an eight-damage Shiv next full turn",function()
 local s=infinite({"accuracy",{cardId="infinite_blades",upgraded=true}})
 assert(Combat.play(s,find(s,"accuracy").uid));assert(Combat.play(s,find(s,"infinite_blades").uid))
 eq(#s.hand,0);assert(Combat.endTurn(s));eq(s.turn,2);eq(#s.hand,1)
 local shiv=s.hand[1];eq(shiv.cardId,"shiv");eq(shiv.shivAccuracyBonus,4)
 local hp=s.enemies[1].hp;assert(Combat.play(s,shiv.uid,1));eq(s.enemies[1].hp,hp-8)
end)
end
suite()
print("SILENT_SHIVS_PASS "..count)
