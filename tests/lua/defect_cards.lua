package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local O=require('abyss_orbs')
local R=require('abyss_sts_random')
local F=require('abyss_defect_cards')
local original=require('abyss_data')
local data=F.withFoundationCards(original)
local n=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,f) f();n=n+1;print('ok '..n..' '..name) end
local function setup(id,up,slots,two,many)
 local deck={};for i=1,(many and 8 or 1) do deck[i]={cardId=id,upgraded=up} end
 local s=C.new(data,{seed=42,deck=deck,orbSlots=slots or 3,orbRandomSeed='17',enemies=two and {'jaw_worm','jaw_worm'} or {'jaw_worm'}})
 return s,s.hand[1].uid
end
local function channel(s,kind) assert(O.channel(s,kind,C)) end
for _,up in ipairs({false,true}) do
 local tag=up and '+' or ''
 test('Zap'..tag..' real play has source cost and channel',function()
  local s,uid=setup('zap',up);assert(C.play(s,uid));eq(s.energy,up and 3 or 2);eq(s.orbs.balls[1].kind,'lightning');eq(#s.discard,1)
 end)
 test('Dualcast'..tag..' releases same orb twice',function()
  local s,uid=setup('dualcast',up);channel(s,'frost');channel(s,'plasma');assert(C.play(s,uid));eq(s.player.block,10);eq(s.energy,up and 3 or 2);eq(#s.orbs.balls,1);eq(s.orbs.balls[1].kind,'plasma')
 end)
 for _,v in ipairs({{'cold_snap',6,9,'frost'},{'ball_lightning',7,10,'lightning'}}) do
  test(v[1]..tag..' attacks target then generates correct orb',function()
   local s,uid=setup(v[1],up);local hp=s.enemies[1].hp;assert(C.play(s,uid,1));eq(s.enemies[1].hp,hp-(up and v[3] or v[2]));eq(s.energy,2);eq(s.orbs.balls[1].kind,v[4])
  end)
 end
 test('Coolheaded'..tag..' channels before drawing correct count',function()
  local s,uid=setup('coolheaded',up,nil,nil,true);local before=#s.hand;assert(C.play(s,uid));eq(#s.hand,before-1+(up and 2 or 1));eq(s.energy,2);eq(s.orbs.balls[1].kind,'frost')
 end)
 test('Darkness'..tag..' source upgrade affects all current dark orbs',function()
  local s,uid=setup('darkness',up);channel(s,'dark');O.setFocus(s,2);assert(C.play(s,uid));eq(s.energy,2);eq(#s.orbs.balls,2)
  eq(s.orbs.balls[1].stored,up and 14 or 6);eq(s.orbs.balls[2].stored,up and 14 or 6)
 end)
end

test('attack missing or invalid target cannot spend energy or channel',function()
 local s,uid=setup('cold_snap',false);eq(C.play(s,uid),false);eq(C.play(s,uid,99),false);eq(s.energy,3);eq(#s.orbs.balls,0)
end)
test('zero orb slots still spends card cost but cannot channel',function()
 local s,uid=setup('zap',false,0);assert(C.play(s,uid));eq(s.energy,2);eq(#s.orbs.balls,0)
end)
test('full slots card evokes oldest before generating',function()
 local s,uid=setup('zap',false,1);channel(s,'frost');assert(C.play(s,uid));eq(s.player.block,5);eq(s.orbs.balls[1].kind,'lightning')
end)
test('attack killing final enemy clears queued channel',function()
 local s,uid=setup('cold_snap',false);s.enemies[1].hp=1;assert(C.play(s,uid,1));eq(s.enemies[1].hp,0);eq(#s.orbs.balls,0);eq(s.phase,'victory')
end)
test('dualcast first kill retargets second release to surviving enemy',function()
 local s,uid=setup('dualcast',false,3,true);channel(s,'dark');s.enemies[1].hp=5;s.enemies[2].hp=20
 assert(C.play(s,uid));eq(s.enemies[1].hp,0);eq(s.enemies[2].hp,14);eq(#s.orbs.balls,0)
end)
test('card after damaging effect failure restores original orb and RNG references',function()
 local s,uid=setup('ball_lightning',false,1);channel(s,'lightning');O.setFocus(s,2147483647.0)
 local orbs,rng=s.orbs,s.cardRandomRng;local hp=s.enemies[1].hp;local count=rng.counter
 assert(not pcall(C.play,s,uid,1));eq(s.enemies[1].hp,hp);eq(s.energy,3);eq(#s.hand,1);eq(#s.discard,0)
 eq(s.orbs,orbs);eq(s.cardRandomRng,rng);eq(s.orbs.focus,2147483647.0);eq(#s.orbs.balls,1);eq(rng.counter,count)
end)
test('later invalid channel restores earlier RNG draw and orb mutation after real play',function()
 local s,uid=setup('zap',false,1);channel(s,'lightning')
 -- Deliberately malformed later operation exercises the public play transaction.
 s.catalog.cards.zap.effects[2]={op='channelOrb',orb='unknown',value=1}
 local orbs,rng=s.orbs,s.cardRandomRng;local snap=R.snapshot(rng);local hp=s.enemies[1].hp;local events=#s.events
 assert(not pcall(C.play,s,uid));eq(s.orbs,orbs);eq(s.cardRandomRng,rng);eq(s.energy,3)
 eq(#s.hand,1);eq(#s.discard,0);eq(#s.events,events);eq(s.enemies[1].hp,hp)
 eq(orbs.balls[1].kind,'lightning');eq(rng.counter,snap.counter)
 local restored=R.snapshot(rng);for i,v in ipairs(snap.words) do eq(restored.words[i],v) end
end)
test('copied source data and default production pool remain unchanged',function()
 eq(#data.cards.cards,#original.cards.cards+15);assert(not pcall(F.withFoundationCards,data))
 data.cards.cards[#data.cards.cards].effects[1].value=999;eq(F.withFoundationCards(original).cards.cards[#data.cards.cards].effects[1].value,4)
end)
print('DEFECT_CARDS_PASS '..n)
