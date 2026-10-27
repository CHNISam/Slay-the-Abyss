package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,P,C,D=require('abyss_run'),require('abyss_original_v4_profiles'),require('abyss_combat'),require('abyss_data')
for _,case in ipairs({{'hutao','HT'},{'arlecchino','AR'},{'furina','FR'},{'raiden','RD'}})do
 local source=P.prepare(D,case[1]);local n=#source.cards.cards
 assert(source.originalV4Role==case[2]and source.experimentalCharacter==nil)
 local r=Run.new(source,42)
 assert(r.data~=source and r.data.rules~=source.rules and r.data.cards.cards~=source.cards.cards)
 assert(r.character==nil and r.characterProfile==nil and r.originalCommands==nil and r.data.originalV4Role==case[2])
 assert(r.hp==source.rules.player.maxHp and #r.deck==#source.cards.starter_deck.cards)
 assert(not r.data.runCardCatalog and not r.data.runCardCharacter and #source.cards.cards==n and source.colorlessCards==nil)
 assert(Run.startCombat(r,'cultist_solo'))
 assert(r.combat.originalV4.role==case[2]and not r.combat.orbs and not r.combat.player.stance)
 local marked=C.copy(source);marked.runCardCatalog=true;marked.runCardCharacter='defect'
 local rr=Run.new(marked,43);assert(marked.runCardCatalog and #marked.cards.cards==n and marked.colorlessCards==nil)
 assert(not rr.data.runCardCatalog and not rr.data.runCardCharacter and rr.characterProfile==nil)
 assert(Run.startCombat(rr,'cultist_solo'));assert(rr.combat.originalV4.role==case[2]and not rr.combat.orbs and not rr.combat.player.stance)
end
print('RUN_PREPARED_V4_COMPATIBILITY_PASS actual HT/AR/FR/RD legacy tags, resources, successful starts and isolated V4 lifecycle without inferred profile')
