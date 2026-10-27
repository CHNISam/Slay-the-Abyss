package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,P,D,A,O=require('abyss_combat'),require('abyss_character_profiles'),require('abyss_data'),require('abyss_card_actions'),require('abyss_orbs')
local data=P.prepare(D,'watcher');local defect=P.prepare(D,'defect');local cards,statuses={},{}
for _,c in ipairs(data.cards.cards)do cards[c.id]=true end;for _,s in ipairs(data.statuses.statuses)do statuses[s.id]=true end
for _,c in ipairs(defect.cards.cards)do if not cards[c.id]then data.cards.cards[#data.cards.cards+1]=C.copy(c)end end
for _,s in ipairs(defect.statuses.statuses)do if not statuses[s.id]then data.statuses.statuses[#data.statuses.statuses+1]=C.copy(s)end end
for _,up in ipairs({false,true})do
 local s=C.new(data,{seed=1,cardRandomSeed='1',enableStances=true,orbSlots=1,orbRandomSeed='1',deck={{cardId='omniscience',upgraded=up}},enemies={'cultist'}})
 s.enemies[1].hp=1000;s.enemies[1].maxHp=1000;local original=A.fresh(C,s,'tempest');s.draw={original};O.channel(s,'plasma',C);s.energy=up and 5 or 6
 assert(C.play(s,s.hand[1].uid));local p=assert(s.pendingPileChoice);assert(C.choosePile(s,{original.uid},p.token,p.generation))
 assert(s.enemies[1].hp==976,'both NewQueue actions capture X2 before Plasma changes current energy')
 assert(s.energy==4 and #s.cardsPlayedThisCombat==3,'automatic X keeps real energy from both free activations')
 assert(C.cardDefinition(s,original).exhaust,'Omni changes the original combat object exhaust property')
end
print('WATCHER_OMNI_ENERGY_SNAPSHOT basic/upgraded capture both X snapshots before free Plasma activations passed')
