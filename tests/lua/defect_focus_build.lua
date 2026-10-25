package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local O=require('abyss_orbs')
local F=require('abyss_focus')
local A=require('abyss_actor')
local data=require('abyss_defect_cards').withFoundationCards(require('abyss_data'))
local n=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,f) f();n=n+1;print('ok '..n..' '..name) end
local function setup(id,up,slots,many)
 local deck={};for i=1,(many and 8 or 1) do deck[i]={cardId=id or 'defragment',upgraded=up} end
 local s=C.new(data,{seed=42,orbSlots=slots or 3,orbRandomSeed='17',deck=deck,enemies={'jaw_worm','jaw_worm'}})
 return s,s.hand[1].uid
end
local function focus(s,v) return F.apply(s,s.player,v,s.player) end
local function ch(s,k) return O.channel(s,k,C) end
for _,up in ipairs({false,true}) do
 local tag=up and '+' or ''
 test('Capacitor'..tag..' source slot growth and power leaves piles',function()
  local s,u=setup('capacitor',up);assert(C.play(s,u));eq(s.energy,2);eq(s.orbs.slots,up and 6 or 5);eq(#s.discard,0)
 end)
 test('Consume'..tag..' gains focus before removing last filled slot without evoking',function()
  local s,u=setup('consume',up);ch(s,'frost');ch(s,'plasma');ch(s,'lightning');local counter=s.cardRandomRng.counter
  assert(C.play(s,u));eq(s.energy,1);eq(s.player.statuses.focus,up and 3 or 2);eq(s.orbs.slots,2);eq(#s.orbs.balls,2);eq(s.orbs.balls[1].kind,'frost');eq(s.orbs.balls[2].kind,'plasma');eq(s.cardRandomRng.counter,counter);eq(s.player.block,0)
 end)
 test('Reprogram'..tag..' loses Focus then gains signed attack and defense stats',function()
  local s,u=setup('reprogram',up);local value=up and 2 or 1;assert(C.play(s,u));eq(s.energy,2)
  eq(s.player.statuses.focus,-value);eq(s.orbs.focus,-value);eq(s.player.statuses.strength,value);eq(s.player.statuses.dexterity,value)
 end)
 test('Biased Cognition'..tag..' starts loss next real turn',function()
  local s,u=setup('biased_cognition',up);assert(C.play(s,u));eq(s.energy,2);eq(s.player.statuses.focus,up and 5 or 4);eq(s.player.statuses.bias,1);eq(#s.discard,0)
  assert(C.endTurn(s));eq(s.player.statuses.focus,up and 4 or 3)
 end)
end

test('initial negative and zero Focus instances differ from no Power',function()
 local s=setup();eq(s.player.statuses.focus,nil);focus(s,-1000);eq(s.player.statuses.focus,-1000)
 F.remove(s);focus(s,0);eq(s.player.statuses.focus,0);focus(s,0);eq(s.player.statuses.focus,nil)
end)
test('initial Focus preserves value but later stacks clamp source limits',function()
 local s=setup();focus(s,1200);eq(s.player.statuses.focus,1200);focus(s,1);eq(s.player.statuses.focus,999)
 F.remove(s);focus(s,-1200);eq(s.player.statuses.focus,-1200);focus(s,-1);eq(s.player.statuses.focus,-999)
end)
test('Artifact blocks negative incoming Focus even against positive total',function()
 local s=setup();focus(s,5);s.player.statuses.artifact=1;eq(focus(s,-1),false);eq(s.player.statuses.focus,5);eq(s.player.statuses.artifact,0)
end)
test('Artifact blocks zero incoming Focus without creating Power',function()
 local s=setup();s.player.statuses.artifact=1;eq(focus(s,0),false);eq(s.player.statuses.focus,nil);eq(s.player.statuses.artifact,0)
end)
test('positive incoming Focus recovers negative total without Artifact cost',function()
 local s=setup();focus(s,-5);s.player.statuses.artifact=1;assert(focus(s,1));eq(s.player.statuses.focus,-4);eq(s.player.statuses.artifact,1)
end)
test('existing Focus exact-zero removes before next source application',function()
 local s=setup();focus(s,1);focus(s,-1);eq(s.player.statuses.focus,nil);eq(s.orbs.focus,0)
 focus(s,-1200);eq(s.player.statuses.focus,-1200)
end)
test('player truth repairs stale orb mirror and never changes Dark storage',function()
 local s=setup();ch(s,'dark');s.orbs.focus=999;s.player.statuses.focus=2
 O.endTurn(s,C);eq(s.orbs.balls[1].stored,14);eq(s.orbs.focus,2)
 F.remove(s);eq(s.orbs.balls[1].stored,14);eq(s.orbs.focus,0)
end)
test('Reprogram blocked Focus still grants Strength and Dexterity',function()
 local s,u=setup('reprogram',true);s.player.statuses.artifact=1;assert(C.play(s,u));eq(s.player.statuses.focus,nil);eq(s.player.statuses.strength,2);eq(s.player.statuses.dexterity,2);eq(s.player.statuses.artifact,0)
end)
test('Artifact prevents Bias while initial Focus gain remains',function()
 local s,u=setup('biased_cognition',false);s.player.statuses.artifact=1;assert(C.play(s,u));eq(s.player.statuses.focus,4);eq(s.player.statuses.bias or 0,0);eq(s.player.statuses.artifact,0)
 C.endTurn(s);eq(s.player.statuses.focus,4)
end)
test('Artifact blocks one complete multi-stack Bias tick',function()
 local s=setup();focus(s,5);A.applyPower(s,s.player,'bias',2,s.player);s.player.statuses.artifact=1
 F.startTurn(s,C);eq(s.player.statuses.focus,5);eq(s.player.statuses.artifact,0);eq(s.player.statuses.bias,2)
 F.startTurn(s,C);eq(s.player.statuses.focus,3)
end)
test('Bias crosses zero to negative on subsequent turns',function()
 local s=setup();focus(s,1);A.applyPower(s,s.player,'bias',1,s.player)
 F.startTurn(s,C);eq(s.player.statuses.focus,nil);eq(s.orbs.focus,0)
 F.startTurn(s,C);eq(s.player.statuses.focus,-1);eq(s.orbs.focus,-1)
end)
test('Capacitor caps at ten and Consume works at zero slots',function()
 local s,u=setup('capacitor',true,9);assert(C.play(s,u));eq(s.orbs.slots,10)
 local t,v=setup('consume',false,0);assert(C.play(t,v));eq(t.orbs.slots,0);eq(t.player.statuses.focus,2);eq(t.energy,1)
end)
test('removing an empty last slot preserves filled leading slots',function()
 local s=setup();ch(s,'dark');O.loseSlots(s,1);eq(s.orbs.slots,2);eq(#s.orbs.balls,1);eq(s.orbs.balls[1].kind,'dark')
end)
test('negative Focus immediately changes growth and frost but never Plasma',function()
 local s=setup();ch(s,'frost');ch(s,'dark');ch(s,'plasma');focus(s,-9);O.endTurn(s,C)
 eq(s.player.block,0);eq(s.orbs.balls[2].stored,6);O.startTurn(s,C);eq(s.energy,4)
end)
test('card later error restores Focus truth mirror slots and spent Artifact',function()
 local s,u=setup('reprogram',false);focus(s,1);s.player.statuses.artifact=1
 s.catalog.cards.reprogram.effects[4]={op='channelOrb',orb='bad',value=1}
 local orbs,statuses=s.orbs,s.player.statuses;local events=#s.events
 assert(not pcall(C.play,s,u));eq(s.orbs,orbs);eq(s.player.statuses,statuses);eq(statuses.focus,1);eq(statuses.artifact,1);eq(statuses.strength or 0,0);eq(orbs.focus,1);eq(s.energy,3);eq(#s.hand,1);eq(#s.events,events)
end)
test('orb initialization registers definitions without wiping existing truth',function()
 local s=C.new(data,{seed=42});s.player.statuses.focus=-2;s.player.statuses.bias=3
 O.init(s,3);eq(s.orbs.focus,-2);eq(s.player.statuses.bias,3);eq(s.player.statusDefinitions.focus.id,'focus');eq(s.player.statusDefinitions.bias.id,'bias')
end)
test('two real Biased Cognition plays stack one two-point loss next turn',function()
 local s=setup('biased_cognition',false,nil,true);local first,second=s.hand[1].uid,s.hand[2].uid
 assert(C.play(s,first));assert(C.play(s,second));eq(s.player.statuses.focus,8);eq(s.player.statuses.bias,2)
 assert(C.endTurn(s));eq(s.player.statuses.focus,6)
end)
test('Consume later error restores slot capacity last orb and exact status absence',function()
 local s,u=setup('consume',false);ch(s,'frost');ch(s,'dark');ch(s,'plasma')
 local old=s.orbs;local last=old.balls[3];local counter=s.cardRandomRng.counter;local events=#s.events
 s.catalog.cards.consume.effects[3]={op='channelOrb',orb='bad',value=1}
 assert(not pcall(C.play,s,u));eq(s.orbs,old);eq(old.slots,3);eq(old.balls[3],last);eq(#old.balls,3)
 eq(s.player.statuses.focus,nil);eq(old.focus,0);eq(s.energy,3);eq(#s.hand,1);eq(#s.discard,0);eq(s.cardRandomRng.counter,counter);eq(#s.events,events)
end)
test('Bias real-turn tick consumes one Artifact even with two layers',function()
 local s,u=setup('biased_cognition',false);assert(C.play(s,u));A.applyPower(s,s.player,'bias',1,s.player);s.player.statuses.artifact=1
 assert(C.endTurn(s));eq(s.player.statuses.focus,4);eq(s.player.statuses.artifact,0);eq(s.player.statuses.bias,2)
end)
test('Focus apply and Bias tick stop after player death',function()
 local s=setup();focus(s,4);A.applyPower(s,s.player,'bias',1,s.player);s.player.hp=0
 eq(focus(s,-1),false);eq(F.startTurn(s,C),false);eq(F.remove(s),false);eq(s.player.statuses.focus,4)
end)
test('Focus status view preserves zero presence and derives buff or debuff per actor',function()
 local function view(s)
  for _,entry in ipairs(A.statusView(s.player)) do if entry.id=='focus' then return entry end end
 end
 local s=setup();focus(s,1)
 local v=assert(view(s));eq(v.kind,'buff');assert(v.name and v.description)
 focus(s,-2);eq(assert(view(s)).kind,'debuff')
 eq(s.catalog.statuses.focus.kind,'buff')
 local zero=setup();focus(zero,0)
 v=assert(view(zero));eq(v.amount,0);eq(v.kind,'debuff')
 F.remove(zero);eq(view(zero),nil)
end)
print('DEFECT_FOCUS_BUILD_PASS '..n)
