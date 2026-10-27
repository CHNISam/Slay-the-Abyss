package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A,D=require('abyss_run'),require('abyss_combat'),require('abyss_card_actions'),require('abyss_data')
for _,permanent in ipairs({false,true})do
 local r=Run.new(D,42,{character='defect',experimental=true});r.relics={};r.deck=permanent and {{uid=31,cardId='genetic_algorithm'}}or {}
 assert(Run.startCombat(r,'cultist_solo'));local s=r.combat
 local card=permanent and s.hand[1]or A.fresh(C,s,'genetic_algorithm');s.hand={card}
 local separate=A.fresh(C,s,card.cardId,card);s.draw={separate}
 assert(Run.obtainPotion(r,'duplication_potion'));assert(Run.usePotion(r,1));card=s.hand[1];separate=s.draw[1];assert(Run.play(r,card.uid))
 assert(s.player.block==4 and card.misc==5 and not separate.misc,'same-instance growth must reach queued replay before use: '..tostring(s.player.block)..'/'..tostring(card.misc)..'/'..tostring(separate.misc))
 assert(#s.exhaust==1 and s.exhaust[1]==card and #s.cardsPlayedThisTurn==2)
 if permanent then assert(r.deck[1].misc==5)else assert(#r.deck==0)end
end
print('DEFECT_GENETIC_COPIES_PASS permanent/temporary real Duplication growth, stat-equivalent isolation, purge')
