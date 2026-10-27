-- Expectations fixed to the Dazed/MakeTempCard/CardGroup source chain.
package.path="src/lua/?.lua;build/lua/?.lua;"..package.path
local C=require("abyss_combat")
local Run=require("abyss_run")
local Effects=require("abyss_effects")
local Nodes=require("abyss_nodes")
local Map=require("abyss_map")
local Data=require("abyss_data")
local count,failed=0,0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function same(a,b)
 if type(a)~="table" then eq(a,b);return end
 for k,v in pairs(a) do same(v,b[k]) end
 for k in pairs(b) do assert(a[k]~=nil,"extra key "..tostring(k)) end
end
local function test(name,fn)
 count=count+1;local ok,err=pcall(fn);if not ok then failed=failed+1 end
 print((ok and "ok " or "not ok ")..count.." - "..name..(ok and "" or ": "..tostring(err)))
end
local function battle() return C.new(Data,{enemies={"cultist"},deck={"defend"},seed=42}) end
local function generate(s,n,card)
 return C.applyEffects(s,{{op="makeTempCardInDiscard",card=card or "dazed",value=n}},s.enemies[1],s.player)
end
test("catalog retains original status common -2 ethereal and empty use",function()
 local s=battle();local d=assert(s.catalog.cards.dazed)
 eq(d.type,"status");eq(d.rarity,"common");eq(d.cost,-2);eq(d.ethereal,true);eq(#d.effects,0);eq(d.upgrade,nil)
end)
test("Dazed cannot play and leaves all combat state unchanged",function()
 local s=C.new(Data,{enemies={"cultist"},deck={"dazed"},seed=42})
 local before=C.copy(s);local uid=s.hand[1].uid
 local ok,reason=C.canPlay(s,uid,1);eq(ok,false);eq(reason,"unplayable_card")
 ok,reason=C.play(s,uid,1);eq(ok,false);eq(reason,"unplayable_card");same(before,s)
end)
test("generation makes two fresh discard instances without RNG or permanent data edits",function()
 local s=battle();local uid=s.nextUid;local seed=s.seed
 local catalog=C.copy(s.catalog);generate(s,2)
 eq(#s.discard,2);eq(s.discard[1].uid,uid);eq(s.discard[2].uid,uid+1)
 eq(s.discard[1].cardId,"dazed");eq(s.discard[2].upgraded,false);eq(s.nextUid,uid+2);eq(s.seed,seed)
 assert(s.discard[1]~=s.discard[2]);same(catalog,s.catalog)
 local event=s.events[#s.events];eq(event.kind,"cards_created");eq(#event.frame.discard,2)
end)
test("generation appends at discard top and repeated batches never share UIDs",function()
 local s=battle();s.discard={{uid=99,cardId="strike",upgraded=false}};generate(s,2);generate(s,2)
 eq(s.discard[1].cardId,"strike");local seen={}
 for _,card in ipairs(s.discard) do assert(not seen[card.uid]);seen[card.uid]=true end
 eq(#s.discard,5)
end)
test("real endTurn resolves generation before next enemy's queued damage",function()
 local data=C.copy(Data);local e=data.enemies.enemies[1]
 e.ai=nil;e.intents={{id="generation_fixture",kind="debuff",effects={{op="makeTempCardInDiscard",card="dazed",value=2}}}}
 local s=C.new(data,{enemies={e.id,"blue_slaver"},deck={"defend"},seed=42})
 s.enemies[2].intentIndex=1;s.events={};assert(C.endTurn(s))
 local created,attack
 for i,event in ipairs(s.events) do
  if event.kind=="cards_created" then created=i;eq(#event.frame.discard,3) end
  if event.kind=="damage" and event.detail.source==s.enemies[2].id then attack=i end
 end
 assert(created and attack and created<attack);eq(#s.hand,3)
 local n=0;for _,card in ipairs(s.hand) do if card.cardId=="dazed" then n=n+1 end end;eq(n,2)
end)
test("held Dazed exhausts at player turn end while discard Dazed is retained",function()
 local s=C.new(Data,{enemies={"cultist"},deck={"dazed"},seed=42});local held=s.hand[1]
 generate(s,1);s.player.noDraw=true;assert(C.endTurn(s));eq(s.exhaust[1],held)
 -- noDraw resets at turn start; the other Dazed can be drawn, but never exhausted early.
 eq(#s.exhaust,1);eq(#s.hand+#s.discard+#s.draw,1)
end)
test("dead source cannot generate from the public effect entry",function()
 local s=battle();s.enemies[1].hp=0;local uid=s.nextUid;generate(s,2);eq(#s.discard,0);eq(s.nextUid,uid)
end)
test("zero count has no UID pile or event mutation",function()
 local s=battle();local before=C.copy(s);generate(s,0);same(before,s)
end)
test("count five is supported as the bounded ABI upper endpoint",function()
 local s=battle();generate(s,5);eq(#s.discard,5)
end)
for _,n in ipairs({-1,1.5,6,math.huge,"2"}) do
 test("invalid generation count is atomic: "..tostring(n),function()
  local s=battle();local before=C.copy(s);eq(pcall(generate,s,n),false);same(before,s)
 end)
end
test("unknown card generation is atomic",function()
 local s=battle();local before=C.copy(s);eq(pcall(generate,s,2,"unknown"),false);same(before,s)
end)
test("UIDs cross int32 without wrap",function()
 local s=battle();s.nextUid=2147483647;generate(s,2);eq(s.discard[2].uid,2147483648.0);eq(s.nextUid,2147483649.0)
end)
test("nonadvancing UID batch is rejected before creating any instance",function()
 local s=battle();s.nextUid=9007199254740991.0;local before=C.copy(s)
 eq(pcall(generate,s,2),false);same(before,s)
end)
test("later effect failure rolls generated cards and UID back with the played card",function()
 local s=battle();local def=s.catalog.cards.defend
 def.effects={{op="makeTempCardInDiscard",card="dazed",value=2},{op="block",value=1}}
 local old=C.block;C.block=function() error("late generation failure") end
 local before=C.copy(s);local ok,err=pcall(C.play,s,s.hand[1].uid,1);C.block=old
 eq(ok,false);assert(tostring(err):find("late generation failure",1,true));same(before,s)
end)
test("status type stays outside reward and shop pools even with a supported fixture payload",function()
 local data=C.copy(Data)
 for _,card in ipairs(data.cards.cards) do
  if card.id=="dazed" then card.effects={{op="block",value=1}};card.rarity='rare' end
 end
 assert(not pcall(Run.new,data,42),'complete catalog must reject a forged Dazed lifecycle')
 local run=Run.new(Data,42);assert(Run.startCombat(run,"cultist_solo"))
 C.applyEffects(run.combat,{{op="damage",value=999}},run.combat.player,run.combat.enemies[1]);assert(Run.finishCombat(run))
 eq(#Run.rewardOptions(run),3)
 for _,id in ipairs(Run.rewardOptions(run)) do assert(id~='dazed') end
 assert(Run.claimCardReward(run,0)); dofile('tests/lua/support/finish_combat_rewards.lua')(run)
 local map=Map.generate(data,42)
 for _=1,17 do
  local available=Map.available(map);assert(#available>0)
  local shop
  for _,node in ipairs(available) do if node.type=="shop" then shop=node end end
  if shop then
   assert(Nodes.enter(run,map,shop.id));eq(#run.nodeFlow.cards,7)
   for _,o in ipairs(run.nodeFlow.cards) do assert(o.id~='dazed') end
   return
  end
  assert(Map.choose(map,available[1].id))
 end
 error("fixture route must reach a shop")
end)
test("temporary Dazed never enters permanent run deck or next combat",function()
 local run=Run.new(Data,42);assert(Run.startCombat(run,"cultist_solo"));local deck=C.copy(run.deck)
 generate(run.combat,2);same(deck,run.deck)
 C.applyEffects(run.combat,{{op="damage",value=999}},run.combat.player,run.combat.enemies[1]);assert(Run.finishCombat(run))
 for _,id in ipairs(Run.rewardOptions(run)) do assert(id~="dazed") end
 assert(Run.claimCardReward(run,0)); dofile('tests/lua/support/finish_combat_rewards.lua')(run);assert(Run.startCombat(run,"cultist_solo"));same(deck,run.deck)
 for _,pile in ipairs({run.combat.hand,run.combat.draw,run.combat.discard,run.combat.exhaust}) do
  for _,card in ipairs(pile) do assert(card.cardId~="dazed") end
 end
end)
test("empty effects remain unsupported for ordinary playable cards",function()
 eq(Effects.supported({}),false);local s=battle();s.catalog.cards.defend.effects={};eq(C.canPlay(s,s.hand[1].uid,1),false)
end)
print(count.." Dazed tests, "..failed.." failed");assert(failed==0)
