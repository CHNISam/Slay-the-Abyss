package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A,Data=require('abyss_run'),require('abyss_combat'),require('abyss_card_actions'),require('abyss_data')
assert(not require('abyss_effects').supported({{op='defectFinal',action='unknown',value=1}}))
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function setup(id,up)
 local r=Run.new(Data,42,{character='defect',experimental=true});r.deck={{uid=31,cardId=id,upgraded=up}};r.relics={}
 assert(Run.startCombat(r,'cultist_solo'));return r,r.combat,r.combat.hand[1]
end
for _,up in ipairs({false,true})do
 local r,s,c=setup('genetic_algorithm',up);local twin=A.sameInstance(C,s,c);local separate=A.fresh(C,s,c.cardId,c)
 s.draw={twin,separate};assert(Run.play(r,c.uid));eq(s.player.block,1);eq(r.deck[1].misc,up and 4 or 3)
 eq(twin.misc,up and 4 or 3);eq(separate.misc,nil);eq(s.exhaust[1],c)
 assert(Run.obtainPotion(r,'smoke_bomb'));assert(Run.usePotion(r,1));eq(r.deck[1].misc,up and 4 or 3)
 r,s,c=setup('recursion',up);s.orbs.balls={{kind='dark',stored=25},{kind='frost'}}
 local first=s.orbs.balls[1];local hp=s.enemies[1].hp;assert(Run.play(r,c.uid));eq(s.enemies[1].hp,hp-25)
 eq(s.orbs.balls[2],first);eq(first.stored,25);eq(s.energy,up and 3 or 2)
 r,s,c=setup('scrape',up);local kept=A.fresh(C,s,'defend_blue');s.hand[#s.hand+1]=kept
 local zero=A.fresh(C,s,'beam_cell');local paid=A.fresh(C,s,'defend_blue');s.draw={zero,paid}
 assert(Run.play(r,c.uid,1));eq(s.hand[1],kept);eq(s.hand[2],zero);eq(s.discard[1],paid)
 r,s,c=setup('all_for_one',up);local zero2=A.fresh(C,s,'beam_cell');local turnZero=A.fresh(C,s,'defend_blue');turnZero.costForTurn=0
 s.discard={zero2,turnZero};assert(Run.play(r,c.uid,1));eq(s.hand[1],zero2);eq(s.discard[1],turnZero)
 r,s,c=setup('fission',up);s.orbs.balls={{kind='frost'},{kind='plasma'}};s.draw={A.fresh(C,s,'defend_blue'),A.fresh(C,s,'defend_blue')}
 assert(Run.play(r,c.uid));eq(#s.orbs.balls,0);eq(#s.hand,2);eq(s.energy,up and 7 or 5);eq(s.player.block,up and 5 or 0)
 r,s,c=setup('reboot',up);s.hand[#s.hand+1]=A.fresh(C,s,'defend_blue');s.hand[#s.hand+1]=A.fresh(C,s,'zap')
 s.discard={A.fresh(C,s,'dualcast')};s.draw={A.fresh(C,s,'beam_cell')};local rng=require('abyss_sts_random');local expected=rng.cloneState(s.cardRandomRng)
 rng.randomInt(expected,1);rng.randomInt(expected,0);local shuffle=s.shuffleRng.counter
 assert(Run.play(r,c.uid));eq(s.cardRandomRng.counter,expected.counter);eq(s.shuffleRng.counter,shuffle+(up and 3 or 2));eq(#s.hand,4);eq(s.exhaust[1],c)
 r,s,c=setup('recycle',up);local one=A.fresh(C,s,'defend_blue');local x=A.fresh(C,s,'tempest');s.hand[#s.hand+1]=one;s.hand[#s.hand+1]=x
 assert(Run.play(r,c.uid));assert(s.pendingHandChoice);local p=s.pendingHandChoice;local before=s.energy
 assert(not Run.chooseHand(r,{x.uid},p.token+1,r.combatGeneration));eq(s.energy,before)
 assert(Run.chooseHand(r,{x.uid},p.token,r.combatGeneration));eq(s.energy,before*2);eq(s.exhaust[1],x);assert(not s.actionQueue)
end
print('DEFECT_FINAL_ACTIONS_PASS seven base/upgraded cards, UID/misc/choice/piles/orbs and source RNG')
