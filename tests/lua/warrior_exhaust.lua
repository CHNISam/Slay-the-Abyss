package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local Q=require('abyss_action_queue')
local E=require('abyss_exhaust')
local Snapshot=require('abyss_snapshot')
local W=require('abyss_warrior_cards')
local data=W.withFoundationCards(require('abyss_data'))
local n=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn) fn();n=n+1;print('ok warrior exhaust '..n..' - '..name) end
local function battle(deck)
 return C.new(data,{seed=42,deck=deck or {'strike','defend'},enemies={'jaw_worm'}})
end
local function power(s,id,value)
 s.player.statuses[id]=value;E.rememberPower(s,id)
end
local function using(s,index)
 local c=table.remove(s.hand,index or 1);s.cardInUse=c;return c
end
local function handlers(trace)
 return {effect=function(s,a)
  trace[#trace+1]=a.exhaustSource or a.effect.op
  C.applyEffects(s,{a.effect},s.player,s.player,s.cardInUse)
 end,useCard=function(s)
  local card=s.cardInUse;s.cardInUse=nil;s.discard[#s.discard+1]=card
  trace[#trace+1]='useCard'
 end}
end
test('power acquisition order is stable across stacking',function()
 local s=battle();power(s,'dark_embrace',1);power(s,'feel_no_pain',3);power(s,'dark_embrace',2)
 eq(#s.exhaustPowerOrder,2)
 local p=E.plan(s,s.hand[1]);eq(p.bottom[1].exhaustSource,'dark_embrace')
 eq(p.bottom[1].effect.value,2);eq(p.bottom[2].exhaustSource,'feel_no_pain')
end)
test('fixed FNP block ignores Dexterity and Frail in real Combat',function()
 local s=battle();power(s,'feel_no_pain',4);power(s,'dark_embrace',1)
 s.player.statuses.dexterity=10;s.player.statuses.frail=1
 Q.start(s,{});local card=s.hand[1];E.move(s,card,'hand',Q)
 eq(s.exhaust[1],card);eq(s.player.block,0)
 local trace={};Q.run(s,handlers(trace));eq(trace[1],'feel_no_pain');eq(trace[2],'dark_embrace')
 eq(s.player.block,4)
end)
for _,upgraded in ipairs({false,true}) do
 test('Sentinel energy executes first after the card really moved '..tostring(upgraded),function()
  local s=battle();power(s,'feel_no_pain',3);power(s,'dark_embrace',1)
  s.catalog.cards.sentinel={id='sentinel',type='skill',cost=1,effects={}}
  local card=s.hand[1];card.cardId='sentinel';card.upgraded=upgraded
  Q.start(s,{{kind='effect',effect={op='draw',value=0}}});E.move(s,card,'hand',Q)
  eq(s.energy,3);eq(s.exhaust[1],card)
  local trace={};Q.run(s,handlers(trace));eq(trace[1],'sentinel');eq(trace[2],'draw')
  eq(trace[3],'feel_no_pain');eq(trace[4],'dark_embrace');eq(s.energy,upgraded and 6 or 5)
 end)
end
test('native draw cannot draw the card in use, DE after disposal can redraw it',function()
 local s=battle({'true_grit','strike'});power(s,'dark_embrace',1)
 local pact
 for i,c in ipairs(s.hand) do if c.cardId=='true_grit' then pact=using(s,i);break end end
 local trace={}
 Q.start(s,{{kind='effect',effect={op='draw',value=2}},{kind='useCard'}})
 E.move(s,s.hand[1],'hand',Q)
 local h=handlers(trace);local apply=h.effect
 h.effect=function(state,a)
  if not a.exhaustSource then eq(state.cardInUse,pact);eq(#state.draw,0);eq(#state.discard,0) end
  return apply(state,a)
 end
 Q.run(s,h);eq(trace[1],'draw');eq(trace[2],'useCard');eq(trace[3],'dark_embrace')
 eq(s.hand[1],pact);eq(#s.exhaust,1)
end)
test('explicit exhaust then Corruption self-exhaust enqueue two ordered batches',function()
 local s=battle({'true_grit','strike'});power(s,'feel_no_pain',3);power(s,'dark_embrace',1)
 local skill=using(s);local selected=s.hand[1]
 Q.start(s,{{kind='useCard'}});E.move(s,selected,'hand',Q)
 local trace={};local h=handlers(trace)
 h.useCard=function(state,_,queue) E.move(state,skill,'using',queue);trace[#trace+1]='useCard' end
 Q.run(s,h);eq(#s.exhaust,2);eq(s.exhaust[1],selected);eq(s.exhaust[2],skill)
 eq(s.cardInUse,nil);eq(s.player.block,6)
 eq(table.concat(trace,','),'useCard,feel_no_pain,dark_embrace,feel_no_pain,dark_embrace')
end)
test('victory skips scheduling DE while FNP still schedules fixed block',function()
 local s=battle();power(s,'dark_embrace',1);power(s,'feel_no_pain',3)
 s.enemies[1].hp=0
 local p=E.plan(s,s.hand[1]);eq(#p.bottom,1);eq(p.bottom[1].exhaustSource,'feel_no_pain')
end)
test('turn end alone does not suppress DE planning',function()
 local s=battle();power(s,'dark_embrace',1);s.phase='enemy';s.turnHasEnded=true
 eq(E.plan(s,s.hand[1]).bottom[1].effect.op,'draw')
end)
test('Corruption only exhausts Skills and power/purge disposal has precedence',function()
 local s=battle();s.player.statuses.corruption=1
 eq(E.shouldExhaust(s,{type='skill'}),true);eq(E.shouldExhaust(s,{type='attack'}),false)
 eq(E.shouldExhaust(s,{type='power',exhaust=true}),false)
 eq(E.shouldExhaust(s,{type='skill',exhaust=true},{purge=true}),false)
 s.player.statuses.corruption=nil;eq(E.shouldExhaust(s,{type='skill'}),false)
 eq(E.shouldExhaust(s,{type='attack',exhaust=true}),true)
end)
test('unknown acquisition order and unsupported relic/card hooks fail before movement',function()
 local s=battle();Q.start(s,{});local card=s.hand[1];local hand=s.hand
 s.player.statuses.dark_embrace=1;eq(pcall(E.move,s,card,'hand',Q),false)
 eq(s.hand,hand);eq(s.hand[1],card);eq(#s.exhaust,0);eq(#s.actionQueue.actions,0)
 s.player.statuses.dark_embrace=nil
 eq(pcall(E.move,s,card,'hand',Q,{onExhaustRelics={'dead_branch'}}),false)
 s.catalog.cards[card.cardId].exhaustTrigger={op='unknown'}
 eq(pcall(E.move,s,card,'hand',Q),false);eq(#s.exhaust,0)
end)
test('duplicate UID and dead player are rejected before queue changes',function()
 local s=battle();Q.start(s,{});s.draw[1]=s.hand[1]
 eq(pcall(E.move,s,s.hand[1],'hand',Q),false);eq(#s.actionQueue.actions,0);eq(#s.exhaust,0)
 s.draw={};s.cardInUse=s.hand[2];eq(pcall(E.move,s,s.hand[1],'hand',Q),false)
 s.cardInUse=nil;s.player.hp=0;eq(pcall(E.move,s,s.hand[1],'hand',Q),false)
end)
test('outer snapshot restores exhausted card and the original queue graph',function()
 local s=battle();power(s,'feel_no_pain',3);local card=using(s)
 Q.start(s,{{kind='useCard'}})
 local q,actions,hand,exhaust=s.actionQueue,s.actionQueue.actions,s.hand,s.exhaust
 local restore=Snapshot.capture(s)
 E.move(s,card,'using',Q);eq(#s.exhaust,1);eq(s.cardInUse,nil)
 restore();eq(s.actionQueue,q);eq(s.actionQueue.actions,actions);eq(s.hand,hand);eq(s.exhaust,exhaust)
 eq(s.cardInUse,card);eq(#s.exhaust,0);eq(#actions,1)
end)
print('WARRIOR_EXHAUST_PASS'..n)
