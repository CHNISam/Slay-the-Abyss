package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,Actions,Data=require('abyss_run'),require('abyss_combat'),require('abyss_card_actions'),require('abyss_data')
local failed=0
local function test(name,fn)local ok,why=pcall(fn);if not ok then failed=failed+1 end;print((ok and 'PASS 'or 'FAIL ')..name..(ok and ''or ': '..tostring(why)))end
local function setup(card,relics,character)
 local r=Run.new(Data,42,{character=character or 'defect',experimental=true});r.deck={{uid=31,cardId=card}}
 r.relics=relics or {};r.relicCounters={nunchaku=9}
 assert(Run.startCombat(r,'cultist_solo'));return r,r.combat,r.combat.hand[1]
end
test('Chaos auto attack updates Nunchaku once through both use and after-card hooks',function()
 local r,s,card=setup('strike_blue',{'nunchaku'});s.hand={};s.draw={card}
 assert(Run.obtainPotion(r,'distilled_chaos'));assert(Run.usePotion(r,1))
 assert(s.relicCounters.nunchaku==0);assert(s.energy==4);assert(#s.cardsPlayedThisTurn==1)
end)
test('Native attack keeps exactly one relic callback per physical or purged use',function()
 local r,s,card=setup('strike',{'nunchaku'},'ironclad');local hp=s.enemies[1].hp
 assert(Run.obtainPotion(r,'duplication_potion'));assert(Run.usePotion(r,1))
 assert(Run.play(r,card.uid,1));assert(#s.cardsPlayedThisTurn==2)
 assert(s.relicCounters.nunchaku==1 and s.energy==3);assert(s.enemies[1].hp==hp-12)
 assert((s.player.statuses.duplication or 0)==0 and #s.discard==1)
end)
test('Duplication on a non-purge auto card consumes one and queues a purged replay',function()
 local r,s,card=setup('strike_blue');local hp=s.enemies[1].hp
 assert(Run.obtainPotion(r,'duplication_potion'));assert(Run.usePotion(r,1))
 s.hand={};s.draw={card}
 assert(Run.obtainPotion(r,'distilled_chaos'));assert(Run.usePotion(r,1))
 assert((s.player.statuses.duplication or 0)==0);assert(#s.cardsPlayedThisTurn==2)
 assert(s.enemies[1].hp==hp-12);assert(#s.discard==1 and s.discard[1].uid==card.uid)
end)
test('Forethought free-once flag clears after a physical class card is automatically used',function()
 local _,s,card=setup('defend_blue');card.freeToPlayOnce=true;s.hand={}
 assert(C.cardDefinition(s,card).cost==0)
 C.queueCard(s,card,{append=true,purge=false,exhaustCards=false});Actions.drain(C,s)
 assert(not card.freeToPlayOnce);assert(C.cardDefinition(s,card).cost==1)
end)
assert(failed==0,tostring(failed)..' automatic lifecycle checks failed')
print('AUTO_LIFECYCLE_PASS relic use/after, duplication, one-shot cost cleanup')
