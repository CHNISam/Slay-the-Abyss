package.path='src/lua/?.lua;build/lua/?.lua;tests/lua/helpers/?.lua;'..package.path
local H=require('run_catalog');local Run,C=H.Run,H.C
do
 local r,s=H.new({'rage','strike_blue','sword_boomerang'},'silent')
 H.play(r,'rage');assert(s.player.statuses.rage==3)
 H.play(r,'strike_blue',1);assert(s.player.block==3,'foreign blue attack must trigger acquired Rage once')
 local counter=s.cardRandomRng.counter
 H.play(r,'sword_boomerang');assert(s.player.block==6,'native ABI attack must trigger acquired Rage once')
 assert(s.cardRandomRng.counter==counter+3,'native Sword Boomerang retains three source target samples')
end
do
 local r,s=H.new({'evolve','fire_breathing','coolheaded','wound','strike_blue'})
 H.arrange(s,{hand={'evolve','fire_breathing','coolheaded'},draw={'strike_blue','wound'}})
 H.play(r,'evolve');H.play(r,'fire_breathing');local hp=s.enemies[1].hp
 H.play(r,'coolheaded')
 assert(s.enemies[1].hp==hp-6,'foreign draw must execute Fire Breathing')
 assert(H.held(s,'wound')and H.held(s,'strike_blue')and #s.draw==0,'foreign draw must execute acquired Evolve continuation')
 assert(s.orbs.slots==0 and #s.orbs.balls==0,'a channel at zero slots does not grant slots')
end
do
 local r,s=H.new({'feel_no_pain','dark_embrace','corruption','hologram','defend_green','defend_blue','strike_purple'},'watcher')
 H.arrange(s,{hand={'feel_no_pain','dark_embrace','corruption','hologram'},discard={'defend_green','defend_blue'},draw={'strike_purple'}})
 H.play(r,'feel_no_pain');H.play(r,'dark_embrace');H.play(r,'corruption')
 local hologram=H.held(s,'hologram');assert(C.cardDefinition(s,hologram).cost==0)
 local energy=s.energy;H.play(r,'hologram');assert(s.pendingPileChoice and s.cardInUse==hologram)
 local chosen=s.discard[1];assert(Run.choosePile(r,{chosen.uid},s.pendingPileChoice.token,s.combatGeneration))
 assert(s.energy==energy and s.player.block==6,'foreign skill uses Corruption and exhaust-trigger fixed block')
 assert(H.held(s,'defend_green')==chosen and H.held(s,'strike_purple'),'exhaust draw resumes after the actual pile choice')
 assert(s.exhaust[1]==hologram and not s.pendingPlay and not s.actionQueue)
 assert(C.cardDefinition(s,chosen).cost==0,'retrieved foreign skill remains corrupted')
end
print('RUN_CARD_CATALOG_ACQUISITION_PASS actual cross-color Rage/native9, Evolve/FireBreathing/zero slots, FNP/DarkEmbrace/Corruption and UID choice continuation')
