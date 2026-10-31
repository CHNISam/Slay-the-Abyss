-- Fixed STS319009d5 card/action contracts. Controlled combat, not natural/native.
local C,A,D=require('abyss_combat'),require('abyss_card_actions'),require('abyss_data')
local M={}
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function fresh(s,id)return A.fresh(C,s,id)end
local function battle(id,up)
 local s=C.new(D,{deck={},enemies={'jaw_worm'},seed=7,shuffleSeed='7'})
 s.enemies[1].hp=1000;s.enemies[1].maxHp=1000;s.energy=5
 local card=fresh(s,id);if up then assert(C.upgrade(s,card))end;s.hand={card}
 return s,card
end
local function drained(s)assert(not s.pendingChoice and not s.cardActions and not s.cardInUse,'undrained action')end
local function inventory(s)
 local ids={};for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust})do for _,c in ipairs(pile)do
  assert(not ids[c.uid],'duplicate UID');ids[c.uid]=c
 end end;return ids
end
local function sameObjects(s,expected)
 local actual=inventory(s);local n=0
 for uid,c in pairs(expected)do eq(actual[uid],c,'instance identity');n=n+1 end
 local count=0;for _ in pairs(actual)do count=count+1 end;eq(count,n,'object conservation')
end
function M.deep_breath()
 for _,up in ipairs({false,true})do for _,discarded in ipairs({false,true})do
  local s,card=battle('deep_breath',up);local expected={[card.uid]=card}
  for i=1,6 do local c=fresh(s,i%2==0 and 'strike'or 'defend');expected[c.uid]=c
   local pile=discarded and i<=3 and s.discard or s.draw;pile[#pile+1]=c
  end
  local counter=s.shuffleRng.counter
  assert(C.play(s,card.uid));eq(#s.hand,up and 2 or 1,'Deep Breath draw')
  eq(#s.draw,up and 4 or 5,'Deep Breath merged draw pile');eq(#s.discard,1);eq(s.discard[1],card)
  eq(s.shuffleRng.counter,counter+(discarded and 1 or 0),'conditional shuffle')
  sameObjects(s,expected);drained(s)
 end end
end
function M.impatience()
 for _,up in ipairs({false,true})do for _,attack in ipairs({false,true})do
  local s,card=battle('impatience',up);local kept=fresh(s,attack and 'strike'or 'defend');s.hand[#s.hand+1]=kept
  for _=1,5 do s.draw[#s.draw+1]=fresh(s,'defend')end
  local expected=inventory(s);local top=s.draw[#s.draw];local counter=s.shuffleRng.counter
  assert(C.play(s,card.uid));local count=attack and 0 or up and 3 or 2
  eq(#s.hand,1+count,'Impatience conditional draw');eq(s.hand[1],kept);eq(#s.draw,5-count)
  if count>0 then eq(s.hand[2],top,'draw actual top object')end
  eq(s.shuffleRng.counter,counter);sameObjects(s,expected);drained(s)
 end end
end
function M.metamorphosis()
 for _,up in ipairs({false,true})do
  local s,card=battle('metamorphosis',up);local original=fresh(s,'defend');s.draw={original}
  local nextUid=s.nextUid;local count=up and 5 or 3
  assert(C.play(s,card.uid));eq(#s.draw,1+count,'Metamorphosis count');eq(#s.hand,0);eq(s.exhaust[1],card);eq(s.energy,3)
  local unique,positive={},false
  for _,c in ipairs(s.draw)do if c~=original then
   eq(s.catalog.cards[c.cardId].type,'attack');assert(not s.catalog.cards[c.cardId].healing)
   eq(C.combatBaseCost(s,c),0,'permanent generated cost');eq(c.costForTurn,0)
   assert(c.uid>=nextUid and c.uid<nextUid+count and not unique[c.uid]);unique[c.uid]=true
   if s.catalog.cards[c.cardId].cost>0 then positive=true end
   c.costForTurn=nil;eq(C.cardDefinition(s,c).cost,0,'zero survives turn cost reset')
  end end
  assert(positive,'fixture exercises an originally positive-cost attack');eq(s.nextUid,nextUid+count)
  eq(inventory(s)[original.uid],original);drained(s)
 end
end
function M.secret_technique()
 for _,up in ipairs({false,true})do for _,skills in ipairs({0,1,2})do
  local s,card=battle('secret_technique',up)
  local attack=fresh(s,'strike');s.draw={attack}
  for i=1,skills do s.draw[#s.draw+1]=fresh(s,i==1 and 'defend'or 'shrug_it_off')end
  local expected=inventory(s);local nextUid=s.nextUid;local wanted=skills>0 and s.draw[#s.draw]or nil
  if skills==0 then
   local ok,why=C.play(s,card.uid);eq(ok,false);eq(why,'no_matching_draw_card')
   eq(s.hand[1],card);eq(s.draw[1],attack);eq(s.energy,5);eq(s.nextUid,nextUid)
   sameObjects(s,expected);drained(s)
  else
  assert(C.play(s,card.uid))
  if skills==2 then
   assert(s.pendingChoice);eq(#s.pendingChoice.uids,2)
   for _,uid in ipairs(s.pendingChoice.uids)do assert(uid~=attack.uid)end
   local token=s.pendingChoice.token;local snapshot=C.copy(s)
   assert(not C.chooseCard(s,token,attack.uid));eq(s.pendingChoice.token,token);eq(#s.draw,#snapshot.draw)
   assert(C.chooseCard(s,token,wanted.uid));assert(not C.chooseCard(s,token,wanted.uid))
  end
  eq(#s.hand,skills>0 and 1 or 0,'Secret Technique skill selection')
  if wanted then eq(s.hand[1],wanted,'move selected object without cloning')end
  eq(s.nextUid,nextUid);eq(s.draw[1],attack);eq(#s.draw,1+skills-(skills>0 and 1 or 0))
  eq((up and s.discard or s.exhaust)[1],card,'upgrade removes exhaust')
  sameObjects(s,expected);drained(s)
  end
 end end
end
function M.violence()
 for _,up in ipairs({false,true})do for _,available in ipairs({0,2,6})do for _,full in ipairs({false,true})do
  local s,card=battle('violence',up)
  if full then for _=1,9 do s.hand[#s.hand+1]=fresh(s,'defend')end end
  local skill=fresh(s,'defend');s.draw={skill}
  for _=1,available do s.draw[#s.draw+1]=fresh(s,'strike')end
  local expected=inventory(s);local moved=math.min(available,up and 4 or 3)
  assert(C.play(s,card.uid));eq(#s.hand,full and 9+math.min(1,moved)or moved,'Violence hand')
  eq(#s.draw,1+available-moved,'Violence removes only selected attacks');eq(s.draw[1],skill)
  eq(#s.discard,full and math.max(0,moved-1)or 0,'full hand moves attacks to discard');eq(s.exhaust[1],card)
  for _,c in ipairs(s.discard)do eq(c.cardId,'strike','Violence overflow filter')end
  for i=full and 10 or 1,#s.hand do eq(s.hand[i].cardId,'strike','Violence attack filter')end
  sameObjects(s,expected);drained(s)
 end end end
end
return M
