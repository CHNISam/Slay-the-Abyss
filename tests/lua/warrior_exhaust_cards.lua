package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local R=require('abyss_sts_random')
local W=require('abyss_warrior_cards')
local E=require('abyss_warrior_exhaust_cards')
local Data=require('abyss_data')
local function freeze(value)
 local saved,queue={}, {value}
 while #queue>0 do
  local t=table.remove(queue)
  if not saved[t] then
   local entries={};saved[t]=entries
   for k,v in pairs(t) do entries[k]=v;if type(v)=='table' then queue[#queue+1]=v end end
  end
 end
 return function()
  for t,entries in pairs(saved) do
   for k,v in pairs(entries) do assert(t[k]==v,'source field changed: '..tostring(k)) end
   for k,v in pairs(t) do assert(entries[k]==v,'source field added: '..tostring(k)) end
  end
 end
end
local originalUntouched=freeze(Data)
local base=W.withFoundationCards(Data)
local baseUntouched=freeze(base)
local data=E.withCards(base)
local n=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn) fn();n=n+1;print('ok warrior exhaust card '..n..' - '..name) end
local function inst(id,up) return {cardId=id,upgraded=up} end
local function uid(s,id)
 for _,c in ipairs(s.hand) do if c.cardId==id then return c.uid end end
 error('missing hand card '..id)
end
local function held(s,id)
 for _,c in ipairs(s.hand) do if c.cardId==id then return c end end
 error('missing hand card '..id)
end
local function battle(deck)
 local s=C.new(data,{seed=42,deck=deck,enemies={'cultist'}})
 s.cardRandomRng=R.fromSeed('42');return s
end
local function play(s,id,target)
 local ok,reason=C.play(s,uid(s,id),target);assert(ok,reason)
end
local function definition(d,id)
 for _,c in ipairs(d.cards.cards) do if c.id==id then return c end end
end
-- Arrange known instances into source pile positions, retaining their actual
-- Combat-created UIDs. No rule handlers or production modules are replaced.
local function arrange(s,handIds)
 local all={}
 for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust}) do
  for _,card in ipairs(pile) do all[#all+1]=card end
 end
 s.hand={};s.draw={};s.discard={};s.exhaust={}
 for _,id in ipairs(handIds) do
  local found
  for i,card in ipairs(all) do if card.cardId==id then found=table.remove(all,i);break end end
  s.hand[#s.hand+1]=assert(found,'fixture card missing: '..id)
 end
 for _,card in ipairs(all) do s.draw[#s.draw+1]=card end
end
test('withCards prepares five card definitions and three powers in detached data',function()
 local cardIds={'corruption','feel_no_pain','dark_embrace','sentinel','burning_pact'}
 local powerIds={'corruption','feel_no_pain','dark_embrace'}
 local function missing(entries,ids)
  local seen={};for _,entry in ipairs(entries) do assert(not seen[entry.id],'duplicate source id');seen[entry.id]=true end
  local count=0;for _,id in ipairs(ids) do if not seen[id] then count=count+1 end end;return count
 end
 eq(#data.cards.cards,#base.cards.cards+missing(base.cards.cards,cardIds))
 eq(#data.statuses.statuses,#base.statuses.statuses+missing(base.statuses.statuses,powerIds))
 eq(missing(data.cards.cards,cardIds),0);eq(missing(data.statuses.statuses,powerIds),0)
 eq(base.experimentalWarriorExhaust,nil);eq(Data.experimentalWarriorExhaust,nil)
 for _,id in ipairs(cardIds) do
  local d=assert(definition(data,id));eq(d.color,'red');eq(d.experimental,true)
  local native=definition(base,id)
  if native then assert(native.target~=nil);eq(native.experimental,nil);assert(d~=native) end
 end
 data.cards.cards[1].effects[1].value=12345
 eq(base.cards.cards[1].effects[1].value,6);data.cards.cards[1].effects[1].value=6
 eq(pcall(E.withCards,data),false)
 originalUntouched();baseUntouched()
end)
test('standalone helper does not activate the seven foundation cards',function()
 local d=E.withCards(Data)
 eq(d.experimentalWarrior,nil);eq(definition(d,'clash').experimental,nil)
 eq(definition(d,'true_grit').effects[2].op,'exhaustRandom')
 eq(pcall(E.withCards,{cards={cards={{id='sentinel'}}},statuses={statuses={}}}),false)
end)
for _,up in ipairs({false,true}) do
 test('Sentinel blocks and discards normally without an exhaust refund '..tostring(up),function()
  local s=battle({inst('sentinel',up)});play(s,'sentinel')
  eq(s.player.block,up and 8 or 5);eq(s.energy,2)
  eq(#s.discard,1);eq(s.discard[1].cardId,'sentinel');eq(#s.exhaust,0)
 end)
 test('Burning Pact with no remaining hand skips selection and does not exhaust itself '..tostring(up),function()
  local s=battle({inst('burning_pact',up)});play(s,'burning_pact')
  eq(s.pendingHandChoice,nil);eq(s.cardInUse,nil);eq(s.energy,2)
  eq(#s.hand,0);eq(#s.exhaust,0);eq(#s.discard,1);eq(s.discard[1].cardId,'burning_pact')
 end)
 test('Burning Pact requires one choice before its source draw '..tostring(up),function()
  local s=battle({inst('burning_pact',up),'strike','defend','bash','anger','body_slam'})
  arrange(s,{'burning_pact','strike','defend'})
  local p,chosen=held(s,'burning_pact'),held(s,'strike')
  play(s,'burning_pact');assert(s.pendingHandChoice)
  eq(s.cardInUse,p);eq(#s.hand,2);eq(#s.draw,3);eq(#s.discard,0);eq(#s.exhaust,0)
  eq(s.pendingHandChoice.mode,'exhaust_choose');eq(s.pendingHandChoice.count,1)
  eq(C.chooseHand(s,{},s.pendingHandChoice.token),false)
  assert(C.chooseHand(s,{chosen.uid},s.pendingHandChoice.token))
  eq(s.exhaust[1],chosen);eq(s.discard[1],p)
  eq(#s.hand,up and 4 or 3);eq(#s.draw,up and 0 or 1);eq(s.cardRandomRng.counter,0)
 end)
 test('Corruption pays its source cost, makes Skills free, and never exhausts a Power '..tostring(up),function()
  local s=battle({inst('corruption',up),'defend','strike'})
  local defend=held(s,'defend');play(s,'corruption')
  eq(s.energy,up and 1 or 0);eq(s.player.statuses.corruption,1)
  eq(#s.discard,0);eq(#s.exhaust,0);eq(C.cardDefinition(s,defend).cost,0)
  local energy=s.energy;play(s,'defend')
  eq(s.energy,energy);eq(s.player.block,5);eq(s.exhaust[1],defend);eq(#s.discard,0)
  if up then play(s,'strike',1);eq(s.energy,0);eq(s.discard[1].cardId,'strike')
  else eq(C.canPlay(s,uid(s,'strike'),1),false) end
 end)
 test('Feel No Pain uses fixed source block for an explicit exhaust '..tostring(up),function()
  local s=battle({inst('feel_no_pain',up),'true_grit','sentinel'})
  play(s,'feel_no_pain');eq(s.player.statuses.feel_no_pain,up and 4 or 3)
  s.player.statuses.dexterity=10;s.player.statuses.frail=1
  play(s,'true_grit')
  eq(s.player.block,up and 16 or 15) -- True Grit floor((7+10)*.75), then fixed FNP.
  eq(s.energy,3);eq(s.exhaust[1].cardId,'sentinel');eq(s.cardRandomRng.counter,0)
 end)
 test('Dark Embrace pays 2 or 1 and draws after a real hand exhaust '..tostring(up),function()
  local s=battle({inst('dark_embrace',up),'true_grit','strike','defend','bash'})
  arrange(s,{'dark_embrace','true_grit','strike'})
  play(s,'dark_embrace');eq(s.energy,up and 2 or 1)
  play(s,'true_grit');eq(s.player.statuses.dark_embrace,1)
  eq(#s.exhaust,1);eq(s.exhaust[1].cardId,'strike');eq(#s.hand,1);eq(#s.draw,1)
  eq(s.energy,up and 1 or 0);eq(s.discard[1].cardId,'true_grit')
 end)
 test('Corruption Sentinel gives energy only after its real self-exhaust '..tostring(up),function()
  local s=battle({'corruption','feel_no_pain',inst('sentinel',up)});s.energy=10
  play(s,'corruption');play(s,'feel_no_pain');local before=s.energy
  local sentinel=held(s,'sentinel');play(s,'sentinel')
  eq(s.energy,before+(up and 3 or 2));eq(s.player.block,up and 11 or 8)
  eq(s.exhaust[1],sentinel);eq(#s.discard,0);eq(s.cardInUse,nil)
 end)
end
test('Corruption changes existing Skills in all four piles',function()
 local s=battle({'corruption','defend','sentinel','true_grit','warcry'})
 arrange(s,{'corruption','defend'})
 local moved={}
 for _,card in ipairs(s.draw) do moved[card.cardId]=card end
 s.draw={moved.sentinel};s.discard={moved.true_grit};s.exhaust={moved.warcry}
 play(s,'corruption')
 for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust}) do
  for _,card in ipairs(pile) do eq(C.cardDefinition(s,card).cost,0) end
 end
end)
test('Corruption cost reduction survives the following player turn',function()
 local s=battle({'corruption','sentinel','defend'});play(s,'corruption')
 assert(C.endTurn(s));eq(s.phase,'player')
 for _,card in ipairs(s.hand) do eq(C.cardDefinition(s,card).cost,0) end
 eq(#s.hand,2);eq(s.player.statuses.corruption,1)
end)
test('repeated Corruption consumes its own energy without stacking the Power',function()
 local s=battle({'corruption','corruption','defend'});s.energy=10
 play(s,'corruption');play(s,'corruption');eq(s.energy,4);eq(s.player.statuses.corruption,1)
 local gains=0
 for _,e in ipairs(s.events) do
  if e.kind=='status' and e.detail.status=='corruption' then gains=gains+1 end
 end
 eq(gains,1);eq(#s.discard,0);eq(#s.exhaust,0)
end)
test('Dark Embrace can redraw Burning Pact after its normal disposal',function()
 local s=battle({'dark_embrace','burning_pact','strike'})
 play(s,'dark_embrace');local p=held(s,'burning_pact');play(s,'burning_pact')
 eq(#s.hand,1);eq(s.hand[1],p);eq(#s.exhaust,1);eq(s.exhaust[1].cardId,'strike')
 eq(#s.discard,0);eq(s.cardInUse,nil)
end)
test('Corruption Pact exhausts the chosen card and itself before either DE tail',function()
 local s=battle({'corruption','feel_no_pain','dark_embrace','burning_pact','strike'});s.energy=10
 play(s,'corruption');play(s,'feel_no_pain');play(s,'dark_embrace')
 local p,chosen=held(s,'burning_pact'),held(s,'strike');local before=s.energy
 play(s,'burning_pact');eq(s.energy,before);eq(s.player.block,6)
 eq(s.exhaust[1],chosen);eq(s.exhaust[2],p);eq(#s.exhaust,2);eq(#s.discard,0);eq(#s.hand,0)
end)
for _,first in ipairs({'feel_no_pain','dark_embrace'}) do
 test('real Power acquisition order is preserved when '..first..' comes first',function()
  local s=battle({'feel_no_pain','dark_embrace','warcry','strike','defend'});s.energy=10
  local second=first=='feel_no_pain' and 'dark_embrace' or 'feel_no_pain'
  play(s,first);play(s,second);play(s,'warcry')
  local p=assert(s.pendingHandChoice);local chosen=uid(s,'strike')
  assert(C.chooseHand(s,{chosen},p.token))
  eq(s.exhaustPowerOrder[1],first);eq(s.exhaustPowerOrder[2],second)
  local block
  for _,e in ipairs(s.events) do if e.kind=='block' then block=e end end
  assert(block);eq(block.detail.amount,3)
  eq(#block.frame.hand,first=='feel_no_pain' and 1 or 2)
  eq(#s.hand,2);eq(s.player.block,3)
 end)
end
test('NoDraw never cancels Burning Pact exhausting its selected hand card',function()
 local s=battle({'burning_pact','strike','defend','bash','anger'})
 arrange(s,{'burning_pact','strike','defend'});s.player.noDraw=true
 play(s,'burning_pact');local pending=assert(s.pendingHandChoice)
 local chosen=uid(s,'strike');assert(C.chooseHand(s,{chosen},pending.token))
 eq(s.exhaust[1].uid,chosen);eq(#s.hand,1);eq(#s.draw,2);eq(#s.discard,1)
end)
test('stacking exhaust powers updates amounts without duplicating acquisition entries',function()
 local s=battle({'feel_no_pain',inst('feel_no_pain',true),'dark_embrace',inst('dark_embrace',true),'warcry'})
 s.energy=10;play(s,'feel_no_pain');play(s,'dark_embrace');play(s,'feel_no_pain');play(s,'dark_embrace')
 eq(s.player.statuses.feel_no_pain,7);eq(s.player.statuses.dark_embrace,2)
 eq(#s.exhaustPowerOrder,2);play(s,'warcry');eq(s.player.block,7);eq(#s.exhaust,1)
end)
print('WARRIOR_EXHAUST_CARDS_PASS'..n)
