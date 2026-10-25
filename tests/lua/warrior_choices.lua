package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local R=require('abyss_sts_random')
local H=require('abyss_hand_choice')
local W=require('abyss_warrior_cards')
local original=require('abyss_data')
local data=W.withFoundationCards(original)
local n=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn) fn();n=n+1;print('ok warrior choice '..n..' - '..name) end
local function setup(deck)
 local s=C.new(data,{seed=42,deck=deck or {},enemies={'jaw_worm'}})
 s.cardRandomRng=R.fromSeed('42');return s
end
local function uid(s,id)
 for _,c in ipairs(s.hand) do if c.cardId==id then return c.uid end end
 error('missing '..id)
end
test('empty hand has no choice or random draw',function()
 for _,mode in ipairs({'exhaust_random','exhaust_choose','put_on_deck'}) do
  local s=setup();eq(H.begin(s,mode,1),true);eq(s.pendingHandChoice,nil);eq(s.cardRandomRng.counter,0)
 end
end)
test('single-card random exhaust shortcut consumes no randomness',function()
 local s=setup({'strike'});local card=s.hand[1]
 eq(H.begin(s,'exhaust_random',1),true);eq(#s.hand,0);eq(s.exhaust[1],card)
 eq(s.cardRandomRng.counter,0);eq(s.pendingHandChoice,nil)
end)
test('single-card chosen exhaust auto-completes without opening choice',function()
 local s=setup({'strike'});local card=s.hand[1]
 eq(H.begin(s,'exhaust_choose',1),true);eq(s.exhaust[1],card);eq(s.cardRandomRng.counter,0)
end)
test('single-card put-on-deck consumes one independent random call',function()
 local s=setup({'strike'});local card=s.hand[1]
 eq(H.begin(s,'put_on_deck',1),true);eq(#s.hand,0);eq(s.draw[#s.draw],card)
 eq(s.cardRandomRng.counter,1);eq(s.pendingHandChoice,nil)
end)
test('multiple-card random exhaust selects from hand with one RNG call',function()
 local s=setup({'strike','defend','bash'});local expected=R.cloneState(s.cardRandomRng)
 local position=R.randomInt(expected,#s.hand-1)+1;local card=s.hand[position]
 eq(H.begin(s,'exhaust_random',1),true);eq(s.exhaust[1],card);eq(#s.hand,2)
 eq(s.cardRandomRng.counter,expected.counter);eq(s.pendingHandChoice,nil)
end)
test('manual exhaust preserves objects and does not consume RNG',function()
 local s=setup({'strike','defend'});local chosen=s.hand[1]
 eq(H.begin(s,'exhaust_choose',1),'pause');local token=s.pendingHandChoice.token
 eq(H.choose(s,{chosen.uid},token),true);eq(s.exhaust[1],chosen);eq(s.pendingHandChoice,nil)
 eq(#s.hand,1);eq(s.cardRandomRng.counter,0)
end)
test('manual put-on-deck appends at actual draw top',function()
 local s=setup({'strike','defend'});local chosen=s.hand[1]
 eq(H.begin(s,'put_on_deck',1),'pause');local token=s.pendingHandChoice.token
 eq(H.choose(s,{chosen.uid},token),true);eq(s.draw[#s.draw],chosen);eq(s.cardRandomRng.counter,0)
 C.draw(s,1);eq(s.hand[#s.hand],chosen)
end)
test('zero, duplicate, missing and stale selections do not mutate state',function()
 local s=setup({'strike','defend'});eq(H.begin(s,'exhaust_choose',1),'pause')
 local pending,hand,events=s.pendingHandChoice,s.hand,#s.events;local token=pending.token
 for _,bad in ipairs({{}, {hand[1].uid,hand[1].uid}, {999999}}) do
  eq(H.choose(s,bad,token),false);eq(s.hand,hand);eq(#hand,2);eq(#s.exhaust,0);eq(s.pendingHandChoice,pending);eq(#s.events,events)
 end
 eq(H.choose(s,{hand[1].uid},token+1),false)
 eq(H.choose(s,{hand[1].uid},token),true)
 eq(H.choose(s,{hand[1].uid},token),false)
end)
test('hand replacement, upgrade and turn changes invalidate the selection',function()
 for _,kind in ipairs({'uid','upgrade','turn'}) do
  local s=setup({'strike','defend'});eq(H.begin(s,'put_on_deck',1),'pause');local p=s.pendingHandChoice
  if kind=='uid' then s.hand[1].uid=999 elseif kind=='upgrade' then s.hand[1].upgraded=true else s.turn=s.turn+1 end
  eq(H.choose(s,{s.hand[1].uid},p.token),false);eq(s.pendingHandChoice,p);eq(#s.draw,0)
 end
end)
test('missing RNG is rejected before shortcut movement or serial mutation',function()
 local s=setup({'strike'});s.cardRandomRng=nil;local card=s.hand[1]
 eq(pcall(H.begin,s,'put_on_deck',1),false);eq(s.hand[1],card);eq(#s.draw,0);eq(s.choiceSerial,nil)
 local t=setup({'strike','defend'});t.cardRandomRng=nil
 eq(pcall(H.begin,t,'exhaust_random',1),false);eq(#t.hand,2);eq(#t.exhaust,0);eq(t.choiceSerial,nil)
end)
test('unsupported exhaust triggers fail before movement',function()
 for _,id in ipairs({'dark_embrace','feel_no_pain'}) do
  local s=setup({'strike'});s.player.statuses[id]=1
  eq(pcall(H.begin,s,'exhaust_random',1),false);eq(#s.hand,1);eq(#s.exhaust,0);eq(s.choiceSerial,nil)
 end
end)
test('using card UID cannot be selected or duplicated in a pile',function()
 local s=setup({'strike','defend'});s.cardInUse=s.hand[1]
 eq(pcall(H.begin,s,'exhaust_choose',1),false);eq(#s.hand,2);eq(s.pendingHandChoice,nil)
end)
test('serial overflow, invalid mode and count refuse before effects',function()
 local s=setup({'strike','defend'});s.choiceSerial=2147483647
 eq(pcall(H.begin,s,'exhaust_choose',1),false);eq(s.pendingHandChoice,nil);eq(#s.hand,2)
 eq(pcall(H.begin,s,'unknown',1),false);eq(pcall(H.begin,s,'put_on_deck',2),false)
end)
print('WARRIOR_CHOICES_PASS '..n)
