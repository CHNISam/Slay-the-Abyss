package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,A,D,P=require('abyss_combat'),require('abyss_card_actions'),require('abyss_data'),require('abyss_character_profiles')
local data=P.prepare(D,'defect')
local function setup()return C.new(data,{deck={},enemies={'cultist'},seed=42,cardRandomSeed='17',shuffleSeed='17',orbSlots=0})end
local function play(s,id,up,target)local c=A.fresh(C,s,id);c.upgraded=up;s.hand[#s.hand+1]=c;s.energy=20;assert(C.play(s,c.uid,target));return c end
for _,up in ipairs({false,true})do
 local s=setup();local field=A.fresh(C,s,'force_field');s.hand={field};play(s,'defragment')
 assert(C.cardDefinition(s,field).cost==3);local generated=A.fresh(C,s,'force_field');assert(C.cardDefinition(s,generated).cost==3)
 field.upgraded=up;s.energy=20;assert(C.play(s,field.uid));assert(s.player.block==(up and 16 or 12))
 s=setup();local rebound=play(s,'rebound',up,1);assert(s.discard[1]==rebound)
 local defend=play(s,'defend_blue');assert(s.draw[#s.draw]==defend and not s.player.statuses.rebound)
 s=setup();play(s,'amplify',up);play(s,'defragment');assert(s.player.statuses.focus==2)
 assert((s.player.statuses.amplify or 0)==(up and 1 or 0));assert(#s.cardsPlayedThisTurn==3)
 s=setup();play(s,'equilibrium',up);local held=A.fresh(C,s,'defend_blue');s.hand={held}
 assert(C.endTurn(s));assert(s.hand[1]==held and not s.player.statuses.equilibrium)
 s=setup();play(s,'machine_learning',up);s.draw={};for _=1,8 do s.draw[#s.draw+1]=A.fresh(C,s,'defend_blue')end
 assert(C.endTurn(s));assert(#s.hand==6)
 s=setup();play(s,'echo_form',up);assert(#s.cardsPlayedThisTurn==1);assert(C.endTurn(s));local hp=s.enemies[1].hp
 play(s,'strike_blue',false,1);assert(s.enemies[1].hp==hp-12);assert(#s.cardsPlayedThisTurn==2)
 play(s,'strike_blue',false,1);assert(s.enemies[1].hp==hp-18 and #s.cardsPlayedThisTurn==3)
end
local Run=require('abyss_run');local r=Run.new(D,42,{character='defect',experimental=true});r.deck={{uid=31,cardId='self_repair'}};r.relics={};r.hp=40
assert(Run.startCombat(r,'cultist_solo'));assert(Run.play(r,r.combat.hand[1].uid));assert(r.combat.player.hp==40)
-- One isolated final kill drives the real finish/victory hook and Run HP sync.
local s=r.combat;local c=A.fresh(C,s,'strike_blue');s.hand={c};s.enemies[1].hp=6
assert(Run.play(r,c.uid,1));assert(r.hp==47 and s.player.hp==47);C.startPlayerTurn(s);assert(s.player.hp==47)
print('DEFECT_FINAL_POWERS_PASS seven base/upgraded lifecycle cards, source copies, costs, turn retain/draw, victory healing')
