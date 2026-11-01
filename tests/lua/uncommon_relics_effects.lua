package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local U,C,S=require('abyss_uncommon_relics'),require('abyss_combat'),require('abyss_sts_random')
local data=require('abyss_data')
local n=0
local function test(name,f)f();n=n+1;print('PASS '..name)end
local function battle(relics)
 local s=assert(C.new(data,{seed=42,deck={'strike','defend','defend','defend','defend','defend','defend'},enemies={'cultist','cultist'}}))
 s.relics=relics or {};s.relicCounters={};return s
end
local function apply(s,effects)assert(C.applyEffects(s,effects,s.player,s.enemies[1]))end
test('Sundial persists exact shuffle thirds',function()
 local s=battle({'Sundial'});U.onEquip(s,'Sundial');local before=s.energy
 apply(s,U.onShuffle(s));apply(s,U.onShuffle(s));assert(s.energy==before)
 apply(s,U.onShuffle(s));assert(s.energy==before+2 and s.relicCounters.sundial==0)
end)
test('attack triples give independent Strength Dexterity and fixed block',function()
 local s=battle({'kunai','shuriken','ornamental_fan'});U.atTurnStart(s)
 s.player.statuses.dexterity=5;s.player.statuses.frail=2
 for i=1,3 do apply(s,U.onUseCard(s,{type='attack'}))end
 assert(s.player.statuses.strength==1 and s.player.statuses.dexterity==6 and s.player.block==4)
 U.atTurnStart(s);apply(s,U.onUseCard(s,{type='attack'}));assert(s.relicCounters.kunai==1)
end)
test('Letter Opener uses fixed damage to every enemy',function()
 local s=battle({'letter_opener'});U.atTurnStart(s);s.player.statuses.strength=100
 local before={s.enemies[1].hp,s.enemies[2].hp}
 for i=1,3 do apply(s,U.onUseCard(s,{type='skill'}))end
 assert(s.enemies[1].hp==before[1]-5 and s.enemies[2].hp==before[2]-5)
end)
test('Ink Bottle counts all types and draws at tenth',function()
 local s=battle({'ink_bottle'});U.onEquip(s,'ink_bottle');local before=#s.hand
 for i=1,9 do apply(s,U.onUseCard(s,{type='skill'}))end
 assert(#s.hand==before);apply(s,U.onUseCard(s,{type='power'}));assert(#s.hand==before+1 and s.relicCounters.ink_bottle==0)
end)
test('Horn Cleat second turn and Mercury each turn',function()
 local s=battle({'horn_cleat','mercury_hourglass'});local hp=s.enemies[1].hp
 s.turn=1;apply(s,U.atTurnStart(s));assert(s.player.block==0 and s.enemies[1].hp==hp-3)
 s.turn=2;apply(s,U.atTurnStart(s));assert(s.player.block==14 and s.enemies[1].hp==hp-6)
end)
test('Gremlin Horn excludes final enemy and escape',function()
 local s=battle({'gremlin_horn'});local before=s.energy;s.enemies[1].hp=0
 apply(s,U.onMonsterDeath(s,s.enemies[1]));assert(s.energy==before+1)
 s.enemies[2].hp=0;assert(#U.onMonsterDeath(s,s.enemies[2])==0)
 s.enemies[1].hp=1;assert(#U.onMonsterDeath(s,s.enemies[1])==0)
end)
test('Clay queues next turn block for each actual HP loss',function()
 local s=battle({'self_forming_clay'});assert(#U.wasHpLost(s,s.player,0)==0)
 apply(s,U.wasHpLost(s,s.player,1));apply(s,U.wasHpLost(s,s.player,2));assert(s.player.statuses.next_turn_block==6)
end)
test('Blue Candle loses HP and exhausts the exact curse',function()
 local s=battle({'blue_candle'});local card={uid=99,cardId='injury'};local hp=s.player.hp
 assert(U.canPlayCurse(s,{type='curse'}));apply(s,U.onUseCard(s,{type='curse'},card));assert(card.exhaust and s.player.hp==hp-1)
end)
test('Mummified Hand selects eligible hand only and sets this turn cost',function()
 local s=battle({'mummified_hand'});local target=s.hand[1];s.cardRandomRng=S.fromSeed('42')
 for i=2,#s.hand do s.hand[i].costForTurn=0 end
 U.onUseCard(s,{type='power'},{uid=999},C);assert(target.costForTurn==0)
 target.costForTurn=1;s.queuedCards={{card=target}}
 local calls=s.cardRandomRng.counter
 U.onUseCard(s,{type='power'},{uid=999},C)
 assert(target.costForTurn==1 and s.cardRandomRng.counter==calls,'queued card selected by Mummified Hand')
end)
test('Eternal Feather floors deck groups and Meat has half HP gate',function()
 local r={relics={'eternal_feather','meat_on_the_bone'},deck={1,2,3,4,5,6,7,8,9},hp=20,maxHp=80}
 U.onEnterRoom(r,'camp','enter');assert(r.hp==23);U.onEnterRoom(r,'camp','entered');assert(r.hp==23)
 U.battleEnd(r);assert(r.hp==35);r.hp=41;U.battleEnd(r);assert(r.hp==41)
 r.relics[#r.relics+1]='mark_of_bloom';r.hp=20;U.onEnterRoom(r,'camp');U.battleEnd(r);assert(r.hp==20)
end)
test('Strike Dummy Paper Frog Question Card modifiers are ownership gated',function()
 local s=battle({'strike_dummy','paper_frog','question_card'})
 assert(U.strikeBonus(s,{strikeTag=true})==3 and U.strikeBonus(s,{})==0)
 assert(U.vulnerablePercent(s,s.enemies[1])==175 and U.vulnerablePercent(s,s.player)==nil)
 assert(U.rewardCardCount(s,3)==4)
end)
test('Matryoshka spends two nonboss chest charges with 75 percent common',function()
 local r={relics={'matryoshka'}};U.onEquip(r,'Matryoshka');local calls=0
 local function rng(p)assert(p==.75);calls=calls+1;return calls==1 end
 assert(U.onChestOpen(r,true,rng)==nil and calls==0)
 assert(U.onChestOpen(r,false,rng)=='common');assert(U.onChestOpen(r,false,rng)=='uncommon')
 assert(U.onChestOpen(r,false,rng)==nil and calls==2 and r.relicCounters.matryoshka==-2)
end)
test('three bottles choose exact permanent UID and Singing Bowl delegates health',function()
 local r={relics={'bottled_flame','bottled_lightning','bottled_tornado','singing_bowl'},data={cards={cards={{id='a',type='attack'},{id='s',type='skill'},{id='p',type='power'}}}},deck={{uid=1,cardId='a'},{uid=2,cardId='s'},{uid=3,cardId='p'}},maxHp=80,hp=40}
 for i,id in ipairs({'Bottled Flame','Bottled Lightning','Bottled Tornado'})do local candidates=U.bottleCandidates(r,id);assert(#candidates==1 and candidates[1]==i);assert(U.equipBottle(r,id,i));assert(U.isBottled(r.deck[i]))end
 assert(not U.equipBottle(r,'bottled_flame',2));assert(U.singingBowl(r,{increaseMaxHp=function(run,n)run.maxHp=run.maxHp+n;return true end}));assert(r.maxHp==82)
end)
print('LUA_UNCOMMON_RELICS_PASS '..n)
