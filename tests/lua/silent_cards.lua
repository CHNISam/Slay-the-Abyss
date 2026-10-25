package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Combat=require('abyss_combat')
local Silent=require('abyss_silent')
local Discard=require('abyss_discard')
local Capability=require('abyss_card_capability')
local data=require('abyss_data')
local n=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn) fn(); n=n+1; print('ok silent cards '..n..' - '..name) end
local function fresh(deck)
 local s=assert(Combat.new(Silent.withFoundationCards(data),{deck=deck,enemies={'jaw_worm'},seed=42}))
 s.enemies[1].hp=1000;s.enemies[1].maxHp=1000
 return s
end
local function uid(s,id)
 for _,c in ipairs(s.hand) do if c.cardId==id then return c.uid end end
 error('missing '..id)
end
for _,up in ipairs({false,true}) do
 test('Survivor block then auto-all Tactician '..tostring(up),function()
  local s=fresh({{cardId='survivor',upgraded=up},{cardId='tactician',upgraded=up}})
  assert(Combat.play(s,uid(s,'survivor')))
  eq(s.player.block,up and 11 or 8);eq(s.energy,up and 4 or 3)
  eq(#s.hand,0);eq(#s.discard,2);eq(s.pendingDiscard,nil)
 end)
end
test('pending choice locks real play and end turn, then resumes',function()
 local s=fresh({'survivor','tactician','strike'})
 assert(Combat.play(s,uid(s,'survivor')))
 local token=s.pendingDiscard.token
 local a,r=Combat.play(s,uid(s,'strike'),1);eq(a,false);eq(r,'selection_pending')
 a,r=Combat.endTurn(s);eq(a,false);eq(r,'selection_pending')
 assert(Combat.chooseDiscard(s,{uid(s,'tactician')},token));eq(s.energy,3)
 assert(Combat.play(s,uid(s,'strike'),1))
 eq(Combat.chooseDiscard(s,{},token),false)
end)
test('invalid selection leaves the live choice and energy intact',function()
 local s=fresh({'survivor','tactician','strike'})
 assert(Combat.play(s,uid(s,'survivor')))
 local pending=s.pendingDiscard;local token=pending.token
 eq(Combat.chooseDiscard(s,{999999},token),false)
 eq(s.pendingDiscard,pending);eq(s.energy,2);eq(#s.hand,2)
 assert(Combat.chooseDiscard(s,{uid(s,'strike')},token));eq(s.energy,2)
end)
test('Acrobatics draws before selecting from the resulting real hand',function()
 local s=fresh({'acrobatics','strike','defend'})
 assert(Combat.play(s,uid(s,'acrobatics')))
 eq(#s.hand,2);eq(s.pendingDiscard.count,1);eq(s.energy,2)
 assert(Combat.chooseDiscard(s,{uid(s,'strike')},s.pendingDiscard.token))
 eq(#s.hand,1);eq(s.hand[1].cardId,'defend')
end)
test('Reflex and Tactician cannot be played from hand',function()
 local s=fresh({'reflex','tactician'})
 local a,r=Combat.play(s,uid(s,'reflex'));eq(a,false);eq(r,'unplayable_card')
 a,r=Combat.play(s,uid(s,'tactician'));eq(a,false);eq(r,'unplayable_card')
end)
test('ordinary turn-end discard does not trigger either special card',function()
 local s=fresh({'reflex','tactician'})
 assert(Combat.endTurn(s));eq(s.energy,3)
 for _,e in ipairs(s.events) do assert(e.kind~='discard_energy' and e.kind~='discard_draw') end
end)
test('a discard action followed by more effects stays unsupported',function()
 local s=fresh({'survivor'})
 local card=s.catalog.cards.survivor
 card.effects={{op='requestDiscard',value=1},{op='energy',value=1}}
 eq(Capability.isImplemented(card),false)
 local a,r=Combat.play(s,uid(s,'survivor'));eq(a,false)
 eq(r,'unsupported_effect:discard_must_end_card');eq(s.energy,3)
end)
test('refused discard selection rolls the entire played card back',function()
 local s=fresh({'survivor','strike','defend'})
 s.discardSerial=2147483647
 local hand,card,events=s.hand,s.hand[1],#s.events
 eq(pcall(Combat.play,s,uid(s,'survivor')),false)
 eq(s.hand,hand);eq(s.hand[1],card);eq(#s.hand,3)
 eq(s.energy,3);eq(s.player.block,0);eq(#s.discard,0);eq(#s.events,events)
 eq(s.pendingDiscard,nil);eq(s.discardSerial,2147483647)
end)
test('automatic Reflex tail can redraw both the played and discarded card',function()
 local s=fresh({'survivor','reflex'})
 assert(Combat.play(s,uid(s,'survivor')))
 eq(#s.hand,2);eq(#s.discard,0)
 assert(uid(s,'survivor'));assert(uid(s,'reflex'))
 eq(s.pendingDiscardDraws,nil);eq(s.pendingDiscard,nil)
end)
print('SILENT_CARDS_PASS '..n)
