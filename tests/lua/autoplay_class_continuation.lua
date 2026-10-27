package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat');local A=require('abyss_card_actions');local Profiles=require('abyss_character_profiles')
local Data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local d=Profiles.prepare(Data,'defect')
local s=C.new(d,{deck={},enemies={'jaw_worm','jaw_worm'},seed=42,cardRandomSeed='17',orbSlots=3})
s.energy=0;local chaos=A.fresh(C,s,'chaos');chaos.upgraded=true
s.queuedCards={{card=chaos,purge=false,exhaustCards=false,targetIndex=1}}
A.drain(C,s);eq(#s.orbs.balls,2);eq(s.energy,0);eq(s.discard[1],chaos);eq(#s.cardsPlayedThisTurn,1)
local red=Profiles.prepare(Data,'ironclad')
s=C.new(red,{deck={},enemies={'jaw_worm'},seed=42,cardRandomSeed='17'})
local warcry,defend=A.fresh(C,s,'warcry'),A.fresh(C,s,'defend')
s.hand={A.fresh(C,s,'defend'),A.fresh(C,s,'defend')};s.draw={A.fresh(C,s,'strike')};s.energy=0
s.queuedCards={{card=warcry,purge=false,exhaustCards=true,targetIndex=1},
 {card=defend,purge=true,exhaustCards=true,targetIndex=1}}
A.drain(C,s);assert(s.pendingHandChoice);eq(s.player.block,0);eq(#s.queuedCards,1)
local token=s.pendingHandChoice.token;local chosen=s.hand[1].uid
assert(not C.chooseHand(s,{chosen},token+1));eq(s.player.block,0)
assert(C.chooseHand(s,{chosen},token));eq(s.player.block,5);eq(s.energy,0);eq(#s.exhaust,1)
eq(s.exhaust[1],warcry);assert(not s.queuedCards and not s.cardInUse and not s.actionQueue)
s=C.new(d,{deck={},enemies={'jaw_worm','jaw_worm'},seed=42,cardRandomSeed='17',orbSlots=3})
s.energy=2;local tempest=A.fresh(C,s,'tempest')
C.queueCard(s,tempest,{append=true,purge=true,exhaustCards=false,randomTarget=true})
s.energy=4;A.drain(C,s);eq(s.orbChannelCounts.lightning,4);eq(s.energy,4)
C.queueCard(s,A.fresh(C,s,'reinforced_body'),{append=true,purge=true,exhaustCards=false})
A.drain(C,s);eq(s.player.block,28);eq(s.energy,4)
local mixed=C.copy(d)
for _,card in ipairs(Data.cards.cards)do if card.id=='havoc'then mixed.cards.cards[#mixed.cards.cards+1]=C.copy(card)end end
s=C.new(mixed,{deck={'havoc'},enemies={'jaw_worm','jaw_worm'},seed=42,cardRandomSeed='17',orbSlots=3})
local strike=A.fresh(C,s,'strike_blue');s.draw={strike}
local rng=require('abyss_sts_random');local expected=rng.cloneState(s.cardRandomRng)
local target=rng.randomInt(expected,1)+1;local hp=s.enemies[target].hp
assert(C.play(s,s.hand[1].uid));eq(s.enemies[target].hp,hp-6);eq(s.cardRandomRng.counter,expected.counter)
eq(s.exhaust[1],strike)
s=C.new(mixed,{deck={'havoc'},enemies={'jaw_worm'},seed=42,cardRandomSeed='17',orbSlots=3})
local havoc=s.hand[1];s.draw={A.fresh(C,s,'chaos')};s.orbs=nil
local hand,draw,energy,counter=s.hand,s.draw,s.energy,s.cardRandomRng.counter
assert(not pcall(C.play,s,havoc.uid,1));eq(s.hand,hand);eq(s.draw,draw);eq(s.hand[1],havoc)
eq(s.energy,energy);eq(s.cardRandomRng.counter,counter);assert(not s.pendingPlay and not s.actionQueue and not s.cardInUse)
print('AUTO_CLASS_CONTINUATION_PASS real flow auto-play, selection resume, free/purge disposal')
